"Macro definition to copy & modify root config files"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_to_bin")
load("@aspect_bazel_lib//lib:jq.bzl", "jq")

# JQ expressions to update Angular project output paths from dist/* to projects/*/dist
# We do this to avoid mutating the files in the source tree, so that the native tooling without Bazel continues to work.
JQ_DIST_REPLACE_TSCONFIG = """
    .compilerOptions.paths |= map_values(
      map(
        gsub("^dist/(?<p>.+)$"; "projects/"+.p+"/dist")
      )
    )
"""
# Similarly update paths in angular.json
JQ_DIST_REPLACE_ANGULAR = """
(
  .projects | to_entries | map(
    if .value.projectType == "application" then
      .value.architect.build.options.outputPath = "projects/" + .key + "/dist"
    else
      .
    end
  ) | from_entries
) as $updated |
. * {projects: $updated}
"""

# buildifier: disable=function-docstring
def ng_config(name, **kwargs):
    jq(
        name = "angular",
        srcs = ["angular.json"],
        filter = JQ_DIST_REPLACE_ANGULAR,
    )

    # NOTE: project dist directories are under the project dir unlike the Angular CLI default of the root dist folder
    jq(
        name = "tsconfig",
        srcs = ["tsconfig.json"],
        filter = JQ_DIST_REPLACE_TSCONFIG,
    )

    native.filegroup(
        name = name,
        srcs = [":angular", ":tsconfig"],
        **kwargs
    )
