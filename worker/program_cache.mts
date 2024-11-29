import { ProgramDescriptor } from "./program_abstractions/program_descriptor.mjs";

export class WorkerProgramCacheEntry {
  constructor(
    public program: ProgramDescriptor,
    public lastInputs: Map<string, Uint8Array>,
  ) {}
}

export type ProgramCache = Map<string, WorkerProgramCacheEntry>;
