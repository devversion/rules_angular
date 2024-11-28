import ts from 'typescript';
import {Volume} from 'memfs';
import fs, {Dirent} from 'fs';
import path from 'path';
import * as ngtsc from '@angular/compiler-cli';
import {AbsoluteFsPath} from '@angular/compiler-cli';
import {BazelSafeFilesystem} from './bazel_safe_filesystem.mjs';

// Original TS file system options. Can be read on file load.
const useCaseSensitiveFileNames = ts.sys.useCaseSensitiveFileNames;

let fsId = 0;

export class FileSystem extends BazelSafeFilesystem {
  id = fsId++;

  private _vol = new Volume();

  // Walk up blaze-out/<mode>/bin.
  private _execroot = path.join(process.cwd(), '../../../');

  // `js_binary` always runs with working directory in `bazel-out/<..>/bin`.
  private _diskCwd = process.cwd();
  private _virtualCwd = `/${path.relative(this._execroot, this._diskCwd)}`;

  // Never resolve using the real `process.cwd()`. We are in a virtual FS where
  // the `bazel` bin directory serves as our root via `/`.
  resolve(...segments: string[]): ngtsc.AbsoluteFsPath {
    return path.resolve(this._virtualCwd, ...segments) as ngtsc.AbsoluteFsPath;
  }

  pwd(): ngtsc.AbsoluteFsPath {
    // The `ts_project` rules passes options like `--project` relative to the bazel-bin,
    // so we will mimic the execution running with this as working directory.
    return this._virtualCwd as ngtsc.AbsoluteFsPath;
  }

  readdir(path: ngtsc.AbsoluteFsPath): ngtsc.PathSegment[] {
    return this._vol.readdirSync(path) as ngtsc.PathSegment[];
  }

  stat(path: ngtsc.AbsoluteFsPath): ngtsc.FileStats {
    return this._vol.statSync(path);
  }

  lstat(path: ngtsc.AbsoluteFsPath): ngtsc.FileStats {
    return this._vol.lstatSync(path);
  }

  addFile(filePath: AbsoluteFsPath): void {
    if (this.exists(filePath)) {
      return;
    }

    // Ensure the base directory exists in the virtual volume.
    const parentDir = path.dirname(filePath);
    this._vol.mkdirSync(parentDir, {recursive: true});

    const stat = this.diskLstat(filePath);
    if (stat?.isSymbolicLink()) {
      const symlink = this.diskReadlink(filePath);
      this.addFile(symlink);
      this._vol.symlinkSync(symlink, filePath);
    } else if (stat?.isDirectory()) {
      this._vol.mkdirSync(filePath);
    } else {
      this._vol.writeFileSync(filePath, '<>', {encoding: 'utf8'});
    }
  }

  readFile(filePath: ngtsc.AbsoluteFsPath): string {
    // TODO: guard bazel inputs
    return fs.readFileSync(this.toDiskPath(filePath), {encoding: 'utf8'}) as string;
  }

  writeFile(
    path: ngtsc.AbsoluteFsPath,
    data: string | Uint8Array,
    exclusive?: boolean | undefined,
  ): void {
    // TODO: guard
    fs.writeFileSync(this.toDiskPath(path), data, exclusive ? {flag: 'wx'} : undefined);
  }

  exists(filePath: ngtsc.AbsoluteFsPath): boolean {
    return this._vol.existsSync(filePath);
  }

  existsDirectory(filePath: string): boolean {
    try {
      const stat = this._vol.statSync(this.resolve(filePath));
      return stat.isDirectory();
    } catch {
      return false;
    }
  }

  realpath(filePath: AbsoluteFsPath): AbsoluteFsPath {
    return this._vol.realpathSync(this.resolve(filePath), {
      encoding: 'utf8',
    }) as AbsoluteFsPath;
  }

  readDirectory(
    path: string,
    extensions?: readonly string[],
    exclude?: readonly string[],
    include?: readonly string[],
    depth?: number,
  ): string[] {
    if (ts.matchFiles === undefined) {
      throw Error(
        'Unable to read directory in virtual file system host. This means that ' +
          'TypeScript changed its file matching internals.\n\nPlease consider downgrading your ' +
          'TypeScript version, and report an issue in the Angular Components repository.',
      );
    }

    return ts.matchFiles!(
      this.resolve(path),
      extensions,
      exclude,
      include,
      useCaseSensitiveFileNames,
      '/',
      depth,
      (p) => this.getDirectoryEntries(p),
      (p) => this.realpath(p as AbsoluteFsPath),
      (p) => this.existsDirectory(p),
    );
  }

  private getDirectoryEntries(filePath: string): ts.FileSystemEntries {
    const entries = this._vol.readdirSync(this.resolve(filePath), {
      withFileTypes: true,
    }) as Dirent[];
    const directories: string[] = [];
    const files: string[] = [];

    for (const e of entries) {
      if (e.isDirectory()) {
        directories.push(e.name);
      } else if (e.isFile() || e.isSymbolicLink()) {
        files.push(e.name);
      }
    }

    return {directories, files};
  }

  private diskLstat(filePath: string): fs.Stats | null {
    try {
      return fs.lstatSync(this.toDiskPath(filePath));
    } catch {
      return null;
    }
  }

  private diskReadlink(filePath: AbsoluteFsPath): AbsoluteFsPath {
    return this.fromDiskPath(fs.readlinkSync(this.toDiskPath(filePath)));
  }

  private toDiskPath(filePath: string): string {
    return path.join(this._execroot, this.resolve(filePath));
  }

  private fromDiskPath(diskPath: string): AbsoluteFsPath {
    const relative = path.relative(this._execroot, diskPath);
    if (relative.startsWith('..')) {
      throw new Error(`Unexpected disk path that cannot be part of execroot: ${diskPath}`);
    }
    return `/${relative}` as AbsoluteFsPath;
  }

  static initialize(inputs: Iterable<string>): FileSystem {
    const fs = new FileSystem();
    for (const f of inputs) {
      console.error('Adding file', f);
      // worker file inputs are paths rooted at the execroot.
      fs.addFile(f as AbsoluteFsPath);
    }
    return fs;
  }
}
