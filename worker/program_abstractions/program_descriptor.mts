import * as ngtsc from "@angular/compiler-cli";
import ts from "typescript";

export abstract class ProgramDescriptor {
  constructor(
    protected rootNames: string[],
    protected options: ngtsc.CompilerOptions,
    protected host: ngtsc.CompilerHost,
    protected oldProgram: ProgramDescriptor | undefined,
  ) {}

  abstract init(): Promise<void>;
  abstract getPreEmitDiagnostics(
    cancellationToken: ts.CancellationToken | undefined,
  ): ts.Diagnostic[];
  abstract emit(
    cancellationToken: ts.CancellationToken | undefined,
  ): ts.EmitResult;
}