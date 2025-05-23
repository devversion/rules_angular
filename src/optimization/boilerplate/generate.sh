#!/usr/bin/env bash

set -e

# find path to the Angular CLI executable.
RUNFILES="$(realpath $0.runfiles)"
NG_CLI_TOOL="$RUNFILES/rules_angular/src/optimization/ng_cli_tool_/ng_cli_tool"

# cd into the bazel bin dir
cd ${BAZEL_BINDIR}/src/optimization/boilerplate

# generate boilerplate
$NG_CLI_TOOL new boilerplate --skip-install --skip-git --skip-tests

# disable caching as this runs in the sandbox..
(cd boilerplate && $NG_CLI_TOOL cache off && $NG_CLI_TOOL analytics off)

# remove boilerplate app component code
rm boilerplate/src/app/* -Rf
