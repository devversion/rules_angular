"Support code used by macros in this package"
load("@aspect_bazel_lib//lib:directory_path.bzl", "directory_path")
load("@aspect_rules_js//js:defs.bzl", "js_binary")

TEST_PATTERNS = [
    "src/**/*.spec.ts",
    "src/test.ts",
    "dist/",
]

TOOLS = lambda node_modules: ["/".join([node_modules, s]) for s in [
    "@angular-devkit/build-angular",
]]

# Syntax sugar:
# Reproduce the behavior of the logic a user would get from 
# load("@npm//angular:@angular-devkit/architect-cli/package_json.bzl", architect_cli = "bin")
# buildifier: disable=function-docstring
def ng_bin(name, node_modules):
    entry_point = "_{}_architect_entry_point".format(name)
    directory_path(
        name = entry_point,
        directory = "{}/@angular-devkit/architect-cli/dir".format(node_modules),
        path = "bin/architect.js",
    )

    bin = "_{}_architect_binary".format(name)
    js_binary(
        name = bin,
        data = ["{}/@angular-devkit/architect-cli".format(node_modules)],
        entry_point = entry_point,
    )

    return bin
