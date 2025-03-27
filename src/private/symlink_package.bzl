load("@aspect_bazel_lib//lib:paths.bzl", "relative_file")
load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@bazel_skylib//lib:paths.bzl", "paths")

def _symlink_impl(ctx):
    destination = ctx.actions.declare_symlink(ctx.attr.name)

    src = ctx.attr.src

    if not src.label.name.startswith("node_modules/"):
        fail("%s is not a linked npm package" % src.label)

    src_dir = src[JsInfo].npm_sources.to_list()[-1]
    src_workspace_name = ctx.workspace_name if src.label.workspace_name == "" else src.label.workspace_name
    src_path = paths.join(src_workspace_name, src_dir.short_path)

    ctx.actions.symlink(
        output = destination,
        # TODO(devversion): Revisit this with Bazel 7/8 and their new output layout!
        # This currently generates compatible relative paths for `runfiles`, but in build
        # tree this is unresolvable (but not a problem; but conceptually weird).
        target_path = relative_file(src_path, destination.short_path),
    )

    runfiles = ctx.runfiles(files = [destination])

    return [
        DefaultInfo(
            files = depset([destination], transitive = [ctx.attr.src[DefaultInfo].files]),
            runfiles = runfiles.merge(ctx.attr.src[DefaultInfo].default_runfiles),
        ),
        js_info(
            target = ctx.label,
            sources = src[JsInfo].sources,
            types = src[JsInfo].types,
            transitive_sources = src[JsInfo].transitive_sources,
            transitive_types = src[JsInfo].transitive_types,
            npm_package_store_infos = src[JsInfo].npm_package_store_infos,
            npm_sources = depset([destination], transitive = [src[JsInfo].npm_sources]),
        ),
    ]

symlink_package = rule(
    implementation = _symlink_impl,
    attrs = {
        "src": attr.label(mandatory = True, providers = []),
    },
)
