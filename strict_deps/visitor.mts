import ts from 'typescript';

export interface Import {
  diagnosticNode: ts.Node;
  moduleSpecifier: string;
}

export function getImportsInSourceFile(sf: ts.SourceFile): Import[] {
  const result: Import[] = [];

  const visitor = (node: ts.Node) => {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) {
      result.push({
        diagnosticNode: node.moduleSpecifier!,
        moduleSpecifier: (node.moduleSpecifier as ts.StringLiteral).text,
      });
    }
    if (
      ts.isCallExpression(node) &&
      node.expression.kind === ts.SyntaxKind.ImportKeyword &&
      node.arguments.length >= 1 &&
      ts.isStringLiteralLike(node.arguments[0])
    ) {
      result.push({
        diagnosticNode: node,
        moduleSpecifier: node.arguments[0].text,
      });
    }
    ts.forEachChild(node, visitor);
  };

  ts.forEachChild(sf, visitor);

  return result;
}
