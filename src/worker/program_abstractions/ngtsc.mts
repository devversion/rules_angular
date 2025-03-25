import * as ts from 'typescript';
import {ProgramDescriptor} from './program_descriptor.mjs';
import * as ngtsc from '@angular/compiler-cli';
import assert from 'assert';
import {TsStructureIsReused} from './struture_reused.mjs';

export class AngularProgram extends ProgramDescriptor {
  private _ngtscProgram: ngtsc.NgtscProgram | null = null;

  async init(): Promise<void> {
    this._ngtscProgram = new ngtsc.NgtscProgram(
      this.rootNames,
      this.options,
      this.host,
      this.oldProgram instanceof AngularProgram
        ? (this.oldProgram._ngtscProgram ?? undefined)
        : undefined,
    );
    // Ensure analyzing before collecting diagnostics.
    await this._ngtscProgram.loadNgStructureAsync();
  }

  getPreEmitDiagnostics(cancellationToken: ts.CancellationToken | undefined): ts.Diagnostic[] {
    assert(this._ngtscProgram, 'Expected ngtsc program to be initialized.');

    return [
      ...this._ngtscProgram.getTsSyntacticDiagnostics(undefined, cancellationToken),
      ...this._ngtscProgram.getTsSemanticDiagnostics(undefined, cancellationToken),
      ...this._ngtscProgram.getTsProgram().getGlobalDiagnostics(cancellationToken),
      ...this._ngtscProgram.getNgStructuralDiagnostics(cancellationToken),
      ...this._ngtscProgram.getNgSemanticDiagnostics(undefined, cancellationToken),
    ];
  }

  emit(cancellationToken: ts.CancellationToken | undefined): ts.EmitResult {
    assert(this._ngtscProgram, 'Expected ngtsc program to be initialized.');
    return this._ngtscProgram.emit({cancellationToken, forceEmit: true});
  }

  isStructureReused(): TsStructureIsReused {
    assert(this._ngtscProgram, 'Expected ngtsc program to be initialized.');
    return (this._ngtscProgram?.getTsProgram() as any)['structureIsReused'];
  }
}
