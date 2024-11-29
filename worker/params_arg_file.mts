import * as fs from 'fs';
import {execrootDiskPath} from './constants.mjs';
import path from 'path';

// Note: For actions supporting workers, the args are put in a params file,
// where the path to this file is passed with an `@` prefix.
export function getArgsFromParamsFile() {
  const args = process.argv.slice(2);

  // If Bazel uses a parameter file, we've specified that it passes the file in the following
  // format: "arg0 arg1 --param-file={path_to_param_file}"
  if (args[0].startsWith('@')) {
    // Params file is always specified as an exec-path, but we are executing from
    // the `bazel-bin` directory, so we need to resolve an absolute path.
    const paramsFileExecPath = args[0].split('@')[1];
    const paramsFileDiskPath = path.join(execrootDiskPath, paramsFileExecPath);

    return fs.readFileSync(paramsFileDiskPath, 'utf8').trim().split('\n');
  }

  throw new Error('Could not find params flag file.');
}
