"Support code used by macros in this package"
load("@aspect_bazel_lib//lib:directory_path.bzl", "directory_path")
load("@aspect_rules_js//js:defs.bzl", "js_binary")

TEST_PATTERNS = [
    "src/**/*.spec.ts",
    "src/test.ts",
    "dist/",
]

# Syntax sugar:
# Reproduce the behavior of the logic a user would get from 
# load("@npm//angular:@angular/cli/package_json.bzl", angular_cli = "bin")
def ng_entry_point(name, node_modules):
    entry_point_target = "_{}.ng_entry_point".format(name)
    directory_path(
        name = entry_point_target,
        directory = "{}/@angular/cli/dir".format(node_modules),
        path = "bin/ng.js",
    )
    return entry_point_target

# buildifier: disable=function-docstring
def ng_bin(name, node_modules):
    bin_target = "_{}.ng_binary".format(name)
    js_binary(
        name = bin_target,
        data = ["{}/@angular/cli".format(node_modules)],
        entry_point = ng_entry_point(name, node_modules),
    )

    return bin_target
