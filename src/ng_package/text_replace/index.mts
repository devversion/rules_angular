import fs from 'node:fs/promises';
import path from 'node:path';
import {globSync} from 'tinyglobby';

/** Apply the provided substitutions to the content of the file at the origin, writing it to the provided destination. */
async function applySubstitutions(
  origin: string,
  destination: string,
  substitutions: [RegExp, string][],
) {
  // Ensure that a directory exists for the destination file to be written into. We don't guarantee order of substitutions,
  // so we need to make sure manually for the provided file paths.
  await fs.mkdir(path.dirname(destination), {recursive: true});

  /** The content of the file to the run the substitutions against. */
  let content = await fs.readFile(origin, {encoding: 'utf-8'});

  substitutions.forEach(([regexp, replacement]) => {
    content = content.replace(regexp, replacement);
  });

  return fs.writeFile(destination, content);
}

async function main(args: string[]) {
  const [substitutionsArg, originsRaw, destinationRaw] = (
    await fs.readFile(args[0], {encoding: 'utf-8'})
  )
    .split('\n')
    .map(line => line.replace(/^'(.*)'$/, '$1'));
  /** List of files to propcess for substitution */
  const origins = JSON.parse(originsRaw) as string[];
  /** The destination directory for the copied files with substitutions applied. */
  const destinationDir = destinationRaw as string;
  /** Map of substitutions to make whenever the regex key is matched in a file's content. */
  const substitutions = Object.entries(JSON.parse(substitutionsArg) as Record<string, string>).map<
    [RegExp, string]
  >(([key, val]) => [new RegExp(key, 'g'), val]);

  /** Discovered file paths to apply substitutions to, split into the origin path and the file path based on that origin. */
  let files: [string, string][] = [];

  for (let origin of origins) {
    files.push(
      // Find all of the files in the origin directory and add them to the list.
      ...globSync('**', {cwd: origin}).map<[string, string]>(file => [origin, file]),
    );
  }

  // Wait for substitutions to asynchronously occur on all files.
  await Promise.all(
    files.map(([origin, file]) =>
      applySubstitutions(path.join(origin, file), path.join(destinationDir, file), substitutions),
    ),
  );
}

main(process.argv.slice(2)).catch(e => {
  console.error(e);
  process.exit(1);
});
