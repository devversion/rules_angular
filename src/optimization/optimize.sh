#!/usr/bin/env bash

set -e

# find path to the Angular CLI executable.
RUNFILES="$(realpath $0.runfiles)"
NG_CLI_TOOL="$RUNFILES/rules_angular/src/optimization/ng_cli_tool_/ng_cli_tool"

# Copy Angular CLI boilerplate.
cp -Rf $BOILERPLATE_DIR/* $OUT_DIR

# Copy user files.
cp -Rf $INPUT_PACKAGE/* $OUT_DIR/src/

# Start the prod build.
cd $OUT_DIR
$NG_CLI_TOOL build --preserve-symlinks=true --output-hashing=none --configuration=production

