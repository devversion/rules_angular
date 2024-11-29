import nodeResolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import terser from '@rollup/plugin-terser';

export default {
  external: ['typescript', '@angular/compiler-cli'],
  plugins: [commonjs(), nodeResolve(), terser()],
};
