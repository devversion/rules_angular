#!/usr/bin/env bash

set -e -o pipefail

function suppress_on_success {
   TMP=$(mktemp)
   if ! (${1+"$@"} &> "$TMP"); then
      cat $TMP
      rm $TMP
      exit 1
   fi
   rm $TMP
}

# find path to the Angular CLI executable.
RUNFILES="$(realpath $0.runfiles)"
NG_CLI_TOOL="$RUNFILES/rules_angular/src/optimization/ng_cli_tool_/ng_cli_tool"

# Copy Angular CLI boilerplate.
cp -Rf $BOILERPLATE_DIR/* $OUT_DIR

# Copy user files.
cp -Rf $INPUT_PACKAGE/* $OUT_DIR/src/

# Run the build. Only print output on failure.
cd $OUT_DIR
suppress_on_success $NG_CLI_TOOL build --preserve-symlinks --output-hashing=none --no-progress --no-index --configuration=production

