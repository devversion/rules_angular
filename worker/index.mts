import worker from './worker.cjs';
import * as ngtsc from '@angular/compiler-cli';
import ts from 'typescript';
import {FileSystem} from './file_system.mjs';
import {createCacheCompilerHost} from './cache_compiler_host.mjs';
import {FileCache} from './cache/file_cache.mjs';
import {createCancellationToken} from './cancellation_token.mjs';

class WorkerEntry {
  constructor(public program: ngtsc.Program, public host: ts.CompilerHost) {}
}

const cacheProgram = new Map<string, WorkerEntry>();
const fileCache = new FileCache();

if (worker.isPersistentWorker(process.argv)) {
  worker.enterWorkerLoop(async (r) => {
    if (r.inputs === undefined) {
      throw new Error('No inputs specified in `WorkRequest`.');
    }

    const args = r.arguments;
    const project = args[args.indexOf('--project') + 1];
    const outDir = args[args.lastIndexOf('--outDir') + 1];
    const declarationDir = args[args.lastIndexOf('--declarationDir') + 1];
    const rootDir = args[args.lastIndexOf('--rootDir') + 1];
    const workerKey = `${project} @ ${outDir} @ ${declarationDir} @ ${rootDir}`;

    // Make debugging easier. Forward console error output to the worker response.
    console.error = (...args) => {
      r.output.write(`\n${args.join(' ')}\n`);
    };

    const execroot = process.cwd();
    const command = ts.parseCommandLine(args);
    const fs = FileSystem.initialize(r.inputs);
    const tsSystem = fs.toTypeScriptSystem();

    // Update cache, evicting changed files and their AST.
    fileCache.updateCache(r.inputs);

    // Ngtsc virtual FS does not properly wire up `ts.readDirectory`, so we manually patch it globally via `ts.sys`.
    // https://source.corp.google.com/piper///depot/google3/third_party/javascript/angular2/rc/packages/compiler-cli/src/perform_compile.ts;l=147?q=readCon%20f:angular&ss=piper%2FGoogle%2FPiper
    ts.sys = {readDirectory: tsSystem.readDirectory} as ts.System;

    // Populate options from command line arguments.
    const parsedConfig = ngtsc.readConfiguration(command.options.project!, command.options, fs);
    const options = parsedConfig.options;

    // Invalidate the system to ensure we always use the virtual FS/host.
    // TODO: Update Angular compiler CLI to properly use FS..
    ts.sys = undefined as unknown as ts.System;

    r.output.write('Rootnames:' + parsedConfig.rootNames.join(', '));
    r.output.write('\n\n');

    const formatHost: ts.FormatDiagnosticsHost = {
      getCanonicalFileName: (f) => f,
      getCurrentDirectory: () => `/`,
      getNewLine: () => '\n',
    };

    if (parsedConfig.errors.length) {
      r.output.write(ts.formatDiagnosticsWithColorAndContext(parsedConfig.errors, formatHost));
      return 1;
    }

    const existing = cacheProgram.get(workerKey);
    const host = createCacheCompilerHost(options, fileCache, tsSystem);

    r.output.write(`Re-using program & host: ${!!existing}\n`);

    const program = ngtsc.createProgram({
      rootNames: parsedConfig.rootNames,
      oldProgram: existing?.program,
      host,
      options,
    });

    if (existing !== undefined) {
      existing.program = program;
      existing.host = host;
    } else {
      cacheProgram.set(workerKey, new WorkerEntry(program, host));
    }

    const cancellationToken = createCancellationToken(r.signal);

    const tsPreEmitDiagnostics = ts.getPreEmitDiagnostics(
      program.getTsProgram(),
      undefined,
      cancellationToken,
    );
    if (tsPreEmitDiagnostics.length !== 0) {
      r.output.write(ts.formatDiagnosticsWithColorAndContext(tsPreEmitDiagnostics, formatHost));
      return 1;
    }

    const ngPreEmitDiagnostics = [
      ...program.getNgStructuralDiagnostics(cancellationToken),
      ...program.getNgSemanticDiagnostics(undefined, cancellationToken),
    ];
    if (ngPreEmitDiagnostics.length !== 0) {
      r.output.write(ts.formatDiagnosticsWithColorAndContext(tsPreEmitDiagnostics, formatHost));
      return 1;
    }

    // Emit.
    const emitRes = program.emit({});

    if (emitRes.diagnostics.length !== 0) {
      r.output.write(ts.formatDiagnosticsWithColorAndContext(tsPreEmitDiagnostics, formatHost));
      return 1;
    }

    return emitRes.emitSkipped ? 1 : 0;
  });
} else {
}
