import {StrictDepsManifest} from './manifest.mjs';
import fs from 'fs/promises';
import ts from 'typescript';
import {getImportsInSourceFile} from './visitor.mjs';
import {createDiagnostic} from './diagnostic.mjs';
import path from 'path';

const [manifestExecPath, expectedFailureRaw] = process.argv.slice(2);
const expectedFailure = expectedFailureRaw === 'true';

const manifest: StrictDepsManifest = JSON.parse(await fs.readFile(manifestExecPath, 'utf8'));

const extensionRemoveRegex = /\.[mc]?(js|ts)$/;
const allowedModuleNames = new Set<string>(manifest.allowedModuleNames);
const allowedSources = new Set<string>(
  manifest.allowedSources.map(s => s.replace(extensionRemoveRegex, '')),
);

const diagnostics: ts.Diagnostic[] = [];

for (const fileExecPath of manifest.testFiles) {
  const content = await fs.readFile(fileExecPath, 'utf8');
  const sf = ts.createSourceFile(fileExecPath, content, ts.ScriptTarget.ESNext, true);
  const imports = getImportsInSourceFile(sf);

  for (const i of imports) {
    if (!i.moduleSpecifier.startsWith('.')) {
      if (!allowedModuleNames.has(i.moduleSpecifier)) {
        diagnostics.push(
          createDiagnostic(`No explicit Bazel dependency for this module.`, i.diagnosticNode),
        );
      }
      continue;
    }

    const targetFilePath = path.posix.join(
      path.dirname(i.diagnosticNode.getSourceFile().fileName),
      i.moduleSpecifier,
    );

    if (!allowedSources.has(targetFilePath)) {
      diagnostics.push(
        createDiagnostic(`No explicit Bazel dependency for this module.`, i.diagnosticNode),
      );
    }
  }
}

if (diagnostics.length > 0) {
  const formattedDiagnostics = ts.formatDiagnosticsWithColorAndContext(diagnostics, {
    getCanonicalFileName: f => f,
    getCurrentDirectory: () => '',
    getNewLine: () => '\n',
  });
  console.error(formattedDiagnostics);
  process.exitCode = 1
}

if (expectedFailure && process.exitCode !== 0) {
  console.log('Strict deps testing was marked as expected to fail, marking test as passing.');
  // Force the exit code back to 0 as the process was expected to fail.
  process.exitCode = 0;
}
