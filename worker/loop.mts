import {WorkRequest} from './protocol/worker.cjs';
import * as ngtsc from '@angular/compiler-cli';
import ts from 'typescript';
import {WorkerSandboxFileSystem} from './file_system.mjs';
import {createCacheCompilerHost} from './cache_compiler_host.mjs';
import {FileCache} from './file_cache/file_cache.mjs';
import {createCancellationToken} from './cancellation_token.mjs';
import {diffWorkerInputsForModifiedResources} from './modified_resources.mjs';
import assert from 'assert';
import {ProgramCache, WorkerProgramCacheEntry} from './program_cache.mjs';
import {debugMode, isVanillaTsCompilation} from './constants.mjs';
import {AngularProgram} from './program_abstractions/ngtsc.mjs';
import {VanillaTsProgram} from './program_abstractions/vanilla_ts.mjs';
import {TsStructureIsReused} from './program_abstractions/struture_reused.mjs';

// Used for debug counting.
let buildCount = 0;

export async function executeBuild(
  args: string[],
  worker: {
    req: WorkRequest;
    fileCache: FileCache;
    programCache: ProgramCache;
  } | null,
) {
  const project = args[args.indexOf('--project') + 1];
  const outDir = args[args.lastIndexOf('--outDir') + 1];
  const declarationDir = args[args.lastIndexOf('--declarationDir') + 1];
  const rootDir = args[args.lastIndexOf('--rootDir') + 1];
  const workerKey = `${project} @ ${outDir} @ ${declarationDir} @ ${rootDir}`;
  const existing = worker?.programCache.get(workerKey);

  let inputs: Map<ngtsc.AbsoluteFsPath, Uint8Array> | null = null;

  // In worker mode, we know the inputs and can compute them. This allows
  // us to construct a virtual file system to emulate sandboxing.
  if (worker !== null) {
    inputs = new Map(
      worker.req.inputs
        // Worker input paths are rooted in our virtual FS at execroot.
        .map(i => [`/${i.path}` as ngtsc.AbsoluteFsPath, i.digest]),
    );
  }

  const command = ts.parseCommandLine(args);

  // In worker mode, use a sandbox-emulating virtual file system, while in
  // RBE/standalone execution we simply use the native file system.
  const fs =
    inputs !== null
      ? new WorkerSandboxFileSystem(Array.from(inputs.keys()))
      : new ngtsc.NodeJSFileSystem();

  // Note: This is needed because functions like `readConfiguration` do not properly
  // re-use the passed `fs`, but call `getFileSystem`.
  ngtsc.setFileSystem(fs);

  const modifiedResourceFilePaths =
    existing !== undefined && inputs !== null
      ? diffWorkerInputsForModifiedResources(inputs, existing.lastInputs)
      : null;

  // Update cache, if present, evicting changed files and their AST.
  if (worker !== null) {
    assert(inputs, 'Expected inputs when using persistent file cache.');
    worker.fileCache.updateCache(inputs);
  }

  // Populate options from command line arguments.
  const parsedConfig = ngtsc.readConfiguration(command.options.project!, command.options, fs);
  const options = parsedConfig.options;

  // Invalidate the system to ensure we always use the virtual FS/host.
  // Object.defineProperty(ts, 'sys', {value: undefined, configurable: true});

  const formatHost: ts.FormatDiagnosticsHost = {
    getCanonicalFileName: f => f,
    getCurrentDirectory: () => fs.pwd(),
    getNewLine: () => '\n',
  };

  if (parsedConfig.errors.length) {
    console.error('Config parsing errors:\n');
    console.error(ts.formatDiagnosticsWithColorAndContext(parsedConfig.errors, formatHost));
    return 1;
  }

  let host: ngtsc.CompilerHost;

  // In workers, use a compiler host that leverages the persistent
  // file cache. Otherwise, fall back to an uncached host.
  if (worker !== null) {
    host = createCacheCompilerHost(options, worker.fileCache, fs, modifiedResourceFilePaths);
  } else {
    host = new ngtsc.NgtscCompilerHost(fs, options);
  }

  const programDescriptor = isVanillaTsCompilation ? VanillaTsProgram : AngularProgram;
  const program = new programDescriptor(parsedConfig.rootNames, options, host, existing?.program);

  if (inputs !== null) {
    if (existing !== undefined) {
      existing.program = program;
      existing.lastInputs = inputs;
    } else {
      worker?.programCache.set(workerKey, new WorkerProgramCacheEntry(program, inputs));
    }
  }

  const cancellationToken =
    worker !== null ? createCancellationToken(worker.req.signal) : undefined;

  // Init program
  await program.init();

  // Debug information.
  if (debugMode) {
    console.error(`Worker re-use, number of previous runs: ${buildCount++}`);
    console.error(`Re-using program & host: ${!!existing}`);
    console.error(`Vanilla TS: ${isVanillaTsCompilation}`);
    console.error(`Modified resources: ${modifiedResourceFilePaths?.size}`);
    console.error('Structure reused', TsStructureIsReused[program.isStructureReused()]);
  }

  const tsPreEmitDiagnostics = program.getPreEmitDiagnostics(cancellationToken);
  if (tsPreEmitDiagnostics.length !== 0) {
    console.error('Pre-emit diagnostics:\n');
    console.error(ts.formatDiagnosticsWithColorAndContext(tsPreEmitDiagnostics, formatHost));
    return 1;
  }

  // Emit.
  const emitRes = program.emit(cancellationToken);
  if (emitRes.diagnostics.length !== 0) {
    console.error('Emit diagnostics:\n');
    console.error(ts.formatDiagnosticsWithColorAndContext(emitRes.diagnostics, formatHost));
    return 1;
  }

  return emitRes.emitSkipped ? 1 : 0;
}
