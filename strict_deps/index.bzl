load("@aspect_rules_js//js:providers.bzl", "JsInfo")

def _strict_deps_impl(ctx):
    package_infos = []
    sources = []

    allowed_sources = []
    allowed_module_names = []
    test_files = []

    # Whether or not the strict_deps check is expected to fail.
    expect_failure = "true" if ctx.attr.will_fail else "false"

    for dep in ctx.attr.deps:
        if not JsInfo in dep:
            continue

        # Dependencies directly on a node module will not include sources, allowing us to use this as a marker for whether or not
        # we can include the npm package information from this dependency.
        if not len(dep[JsInfo].sources.to_list()):
            package_infos.append(dep[JsInfo].npm_package_store_infos)
        
        sources.append(dep[JsInfo].sources)

    # Iterate through Npm package infos and pull the package names.
    # https://github.com/aspect-build/rules_js/blob/c980ee9b31dd3b27ea6cac5801a8c22a91833400/npm/private/npm_package_store_info.bzl#L3.
    for info in depset(transitive = package_infos).to_list():
        allowed_module_names.append(info.package)

    for source in depset(transitive = sources).to_list():
        allowed_sources.append(source.short_path)

    for file in ctx.files.srcs:
        allowed_sources.append(file.path)
        test_files.append(file.path)

    manifest = ctx.actions.declare_file("%s_strict_deps_manifest.json" % ctx.attr.name)
    ctx.actions.write(
        output = manifest,
        content = json.encode({
            # Note: Ensure this matches `StrictDepsManifest` from `manifest.mts`
            "testFiles": test_files,
            "allowedModuleNames": allowed_module_names,
            "allowedSources": allowed_sources,
        }),
    )

    launcher = ctx.actions.declare_file("%s_launcher.sh" % ctx.attr.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        # Bash runfile library taken from:
        # https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash.
        content = """
            #!/usr/bin/env bash

            # --- begin runfiles.bash initialization v3 ---
            # Copy-pasted from the Bazel Bash runfiles library v3.
            set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
            # shellcheck disable=SC1090
            source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
            source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
            source "$0.runfiles/$f" 2>/dev/null || \
            source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
            source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
            { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
            # --- end runfiles.bash initialization v3 ---

            exec $(rlocation %s) $(rlocation %s) %s
        """ % (
            "%s/%s" % (ctx.workspace_name, ctx.files._bin[0].short_path),
            "%s/%s" % (ctx.workspace_name, manifest.short_path),
            expect_failure
        ),
    )

    bin_runfiles = ctx.attr._bin[DefaultInfo].default_runfiles

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = ctx.runfiles(
                files = ctx.files._runfiles_lib + ctx.files.srcs + [manifest],
            ).merge(bin_runfiles),
        ),
    ]

_strict_deps_test = rule(
    implementation = _strict_deps_impl,
    test = True,
    doc = "Rule to verify that specified TS files only import from explicitly listed deps.",
    attrs = {
        "deps": attr.label_list(
            doc = "Direct dependencies that are allowed",
            default = [],
        ),
        "srcs": attr.label_list(
            doc = "TS files to be checked",
            allow_files = True,
            mandatory = True,
        ),
        "will_fail": attr.bool(
            doc = "Whether the test is expected to fail",
            default = False,
        ),
        "_runfiles_lib": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
        "_bin": attr.label(
            default = "//strict_deps:bin",
            executable = True,
            cfg = "exec",
        ),
    },
)

def strict_deps_test(**kwargs):
    kwargs['will_fail'] = False
    _strict_deps_test(**kwargs)

def invalid_strict_deps_test(**kwargs):
    kwargs['will_fail'] = True
    _strict_deps_test(**kwargs)
