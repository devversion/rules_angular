load("@aspect_bazel_lib//lib:paths.bzl", "relative_file")
load("@aspect_rules_ts//ts:defs.bzl", "TsConfigInfo")
load("//src/ng_project/config:compilation_mode.bzl", "NgCompilationMode")

def determineCompilationMode(ctx):
    if ctx.attr._partial_compilation_flag[NgCompilationMode].enabled:
        return "partial"
    return "full"

def _ng_project_config_impl(ctx):
    # Create a json file to write output to for merging with other tsconfig files.
    out = ctx.actions.declare_file("%s.json" % ctx.label.name)

    # Obtain the last tsconfig to be added to the TsConfigInfo deps to extend from.
    tsconfigs = ctx.attr.tsconfig[TsConfigInfo].deps.to_list()
    if len(tsconfigs) == 0:
        fail("No valid tsconfigs were provided to extend from")
    tsconfig = tsconfigs[-1]

    # Extends path discovery logic taken from: https://github.com/aspect-build/rules_ts/blob/1d21d227ce6c078ce7f78e45945e79ae45edefb4/ts/private/ts_config.bzl#L121-L127
    extends_path = relative_file(tsconfig.short_path, out.short_path)
    if not extends_path.startswith("../"):
        extends_path = "./" + extends_path

    # The angular compiler configuration is provided as a json string, we convert it to a
    # dictionary for manipulation.
    config = json.decode(ctx.attr.angular_compiler_options)

    config["compilationMode"] = determineCompilationMode(ctx)

    ctx.actions.write(
        output = out,
        content = json.encode({
            "extends": extends_path,
            "angularCompilerOptions": config,
        }),
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

ng_project_config = rule(
    implementation = _ng_project_config_impl,
    attrs = {
        "_partial_compilation_flag": attr.label(
            default = "@rules_angular//src/ng_project/config:partial_compilation",
            providers = [NgCompilationMode],
            doc = "Internal attribute which points to the partial compilation build setting.",
        ),
        "angular_compiler_options": attr.string(
            default = "{}",
            doc = "A string representation of the angularCompilerOptions dictionary for configuring ngc.",
        ),
        "tsconfig": attr.label(
            providers = [TsConfigInfo],
            mandatory = True,
        ),
    },
)
