import ts from 'typescript';
import {FileCache} from './file_cache/file_cache.mjs';
import * as ngtsc from '@angular/compiler-cli';
import * as nodeFs from 'node:fs';
import module from 'module';
import path from 'node:path';


export function createCacheCompilerHost(
  options: ts.CompilerOptions,
  cache: FileCache,
  fs: ngtsc.FileSystem,
  modifiedResourceFilePaths: Set<string> | null,
): ngtsc.CompilerHost {
  const base: ngtsc.CompilerHost = new ngtsc.NgtscCompilerHost(fs, options);
  const originalGetSourceFile = base.getSourceFile;
  const defaultLibLocation = base.getDefaultLibLocation?.();

  // This should never happen as `ts.createCompilerHost` always sets it.
  if (defaultLibLocation === undefined) {
    throw new Error('Could not determine default TypeScript lib location.');
  }

  // For the worker, we will re-use the same program. TypeScript and the Angular Compiler
  // are able to detect physically changed TS files, but not resource files. This is why
  // we need to tell ngtsc about e.g. modified template files for re-used build requests.
  if (modifiedResourceFilePaths !== null) {
    base.getModifiedResourceFiles = () => modifiedResourceFilePaths;
  }

  base.readResource = fileName => {
    // Used cached source file if it's still valid.
    const cachedFile = cache.getCache(fileName);
    if (cachedFile !== undefined && typeof cachedFile === 'string') {
      return cachedFile;
    }
    const diskContent = fs.readFile(fs.resolve(fileName));
    if (diskContent === undefined) {
      throw new Error(`Could not read resource file: ${fileName}`);
    }
    const digest = cache.getLastDigest(fileName);
    if (digest === undefined) {
      throw new Error(`No digest found for resource file: ${fileName}`);
    }
    cache.putCache(fileName, {digest, value: diskContent});
    return diskContent;
  };

  base.getSourceFile = function (
    fileName: string,
    languageVersionOrOptions: ts.ScriptTarget | ts.CreateSourceFileOptions,
    onError?: (message: string) => void,
    shouldCreateNewSourceFile?: boolean,
  ): ts.SourceFile | undefined {
    // Used cached source file if it's still valid.
    const cachedFile = cache.getCache(fileName);
    if (cachedFile !== undefined && typeof cachedFile !== 'string') {
      return cachedFile;
    }

    const isLibFile = defaultLibLocation !== undefined && fileName.startsWith(defaultLibLocation);
    let createdFile: ts.SourceFile | undefined;

    // Lib files need to be resolved from real disk as they aren't
    // part of action inputs therefore not part of the virtual FS/host.
    if (isLibFile) {
      let filePath = path.relative(defaultLibLocation, fileName);
      // If the file does not exist at the expected path, we assume it needs to be found using require.resolve
      // to load it from the typescript lib folder.
      if (!nodeFs.existsSync(filePath)) {
        try {
          // TODO: Handle this in a more general way than assuming any requested file that isn't found must be
          // from typescript/lib
          const req = module.createRequire(import.meta.url);
          filePath = req.resolve(`typescript/lib/${path.basename(fileName)}`);
        } catch {
          throw Error(`Cannot find ${fileName} directly or within typescript/lib`);
        }
      }

      createdFile = ts.createSourceFile(
        fileName,
        nodeFs.readFileSync(filePath, 'utf8'),
        languageVersionOrOptions,
        false,
      );
    } else {
      createdFile = originalGetSourceFile.call(
        this,
        fileName,
        languageVersionOrOptions,
        onError,
        shouldCreateNewSourceFile,
      );
    }

    if (createdFile !== undefined) {
      // Note: For library files, we will never have a digest. This is because the library is not
      // part of the `WorkRequest` inputs, but rather is part of the worker `js_binary`. To make
      // sure lib files can be cached, we assign an arbitrary digest. The entry would never be evicted
      // by `cache.updateCache` anyway. Bazel will invalidate the worker when the TS package changes.
      const digest = isLibFile ? new Uint8Array() : cache.getLastDigest(fileName);

      if (digest === undefined) {
        throw new Error(`No digest found for source file: ${fileName}`);
      }

      cache.putCache(fileName, {digest, value: createdFile});
    }

    return createdFile;
  };

  return base;
}
