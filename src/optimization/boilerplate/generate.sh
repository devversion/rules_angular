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

# cd into the bazel bin dir
cd ${OUT_DIR}/..

# generate boilerplate
suppress_on_success $NG_CLI_TOOL new boilerplate --skip-install --skip-git --skip-tests

# disable caching as this runs in the sandbox..
(cd boilerplate && $NG_CLI_TOOL cache off && $NG_CLI_TOOL analytics off) &> /dev/null

# remove boilerplate app component code
rm -Rf boilerplate/src/app/*
rm boilerplate/src/main.ts
