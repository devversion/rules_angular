function readPackage(pkg, context) {
  if (pkg.name === '@angular/compiler-cli') {
    // Remove typescript from peer dependencies to allow it to be provided
    // via the symlinked version.
    delete pkg.peerDependencies['typescript'];
    delete pkg.peerDependenciesMeta['typescript'];
  }
  return pkg;
}

module.exports = {
  hooks: {
    readPackage,
  },
};
