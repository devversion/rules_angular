import { Volume } from "memfs";
import fs from "fs";
import path from "path";
import * as ngtsc from "@angular/compiler-cli";
import { AbsoluteFsPath } from "@angular/compiler-cli";
import { BazelSafeFilesystem } from "./bazel_safe_filesystem.mjs";

const READ_FROM_DISK_PLACEHOLDER = "@@READ--FROM-DISK@@";

let fsId = 0;

export class FileSystem extends BazelSafeFilesystem {
  id = fsId++;

  private _vol = new Volume();

  // Walk up blaze-out/<mode>/bin.
  private _execroot = path.join(process.cwd(), "../../../");

  // `js_binary` always runs with working directory in `bazel-out/<..>/bin`.
  private _diskCwd = process.cwd();
  private _virtualCwd = `/${path.relative(this._execroot, this._diskCwd)}`;

  constructor(inputs: AbsoluteFsPath[]) {
    super();

    for (const f of inputs) {
      this.addFile(f);
    }
  }

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
    this._vol.mkdirSync(parentDir, { recursive: true });

    const stat = this.diskLstat(filePath);
    if (stat?.isSymbolicLink()) {
      const symlink = this.diskReadlink(filePath);
      this.addFile(symlink);
      this._vol.symlinkSync(symlink, filePath);
    } else if (stat?.isDirectory()) {
      this._vol.mkdirSync(filePath);
    } else {
      // Note: We never pre-read files and store them in the virtual FS as this
      // would be overly expensive. We just use the virtual FS for fast lookups,
      // directory scans etc.
      this._vol.writeFileSync(filePath, READ_FROM_DISK_PLACEHOLDER, {
        encoding: "utf8",
      });
    }
  }

  readFile(filePath: ngtsc.AbsoluteFsPath): string {
    // TODO: guard bazel inputs
    return fs.readFileSync(this.toDiskPath(filePath), {
      encoding: "utf8",
    }) as string;
  }

  writeFile(
    path: ngtsc.AbsoluteFsPath,
    data: string | Uint8Array,
    exclusive?: boolean | undefined,
  ): void {
    // TODO: guard
    fs.writeFileSync(
      this.toDiskPath(path),
      data,
      exclusive ? { flag: "wx" } : undefined,
    );
  }

  ensureDir(path: AbsoluteFsPath): void {
    fs.mkdirSync(this.toDiskPath(path), { recursive: true });
  }

  exists(filePath: ngtsc.AbsoluteFsPath): boolean {
    return this._vol.existsSync(filePath);
  }

  realpath(filePath: AbsoluteFsPath): AbsoluteFsPath {
    return this._vol.realpathSync(this.resolve(filePath), {
      encoding: "utf8",
    }) as AbsoluteFsPath;
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
    if (relative.startsWith("..")) {
      throw new Error(
        `Unexpected disk path that cannot be part of execroot: ${diskPath}`,
      );
    }
    return `/${relative}` as AbsoluteFsPath;
  }
}
