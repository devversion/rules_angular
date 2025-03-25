import * as ngtsc from '@angular/compiler-cli';
import ts from 'typescript';

export function createBaseCompilerHost(
  options: ts.CompilerOptions,
  fs: ngtsc.FileSystem,
): ngtsc.CompilerHost {
  const base: ngtsc.CompilerHost = new ngtsc.NgtscCompilerHost(fs, options);

  // Support `--traceResolution`.
  base.trace = output => console.error(output);

  return base;
}
