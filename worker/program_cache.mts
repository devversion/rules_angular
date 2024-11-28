import * as ngtsc from "@angular/compiler-cli";

export class WorkerProgramCacheEntry {
  constructor(
    public program: ngtsc.NgtscProgram,
    public lastInputs: Map<string, Uint8Array>,
  ) {}
}

export type ProgramCache = Map<string, WorkerProgramCacheEntry>;
