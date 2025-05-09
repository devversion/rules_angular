load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@aspect_rules_js//npm:providers.bzl", "NpmPackageInfo")

DOC = """
Rule that symlinks a `//:node_modules/<pkg>` into another `node_modules` folder.

This is useful for cases where node modules cross Bazel repository boundaries, e.g.
when allowing for a configurable TS version, as otherwise those modules will not be
resolvable at runtime in hermetic environments (like RBE).

The test environments will not have the execroot `node_modules`, or user workspace
`node_modules` reachable by traversal up from e.g. `@rules_angular//src/worker/loop.mts`.

(Note: In build actions lookups work as we build in `bin/external/rules_angular`; but not in runfiles!)
"""

def _symlink_impl(ctx):
    src = ctx.attr.src

    has_js_info = JsInfo in src
    if has_js_info:
        src_dir = src[JsInfo].npm_sources.to_list()[-1]
    else:
        src_dir = src[NpmPackageInfo].src

    destination = ctx.actions.declare_file(ctx.attr.name)

    ctx.actions.symlink(
        output = destination,
        # TODO(devversion): Revisit this with Bazel 7/8 and their new output layout!
        # This currently generates compatible relative paths for `runfiles`, but in build
        # tree this is unresolvable (but not a problem; but conceptually weird).
        target_file = src_dir,
    )

    runfiles = ctx.runfiles(files = [destination])

    return [
        DefaultInfo(
            files = depset([destination], transitive = [ctx.attr.src[DefaultInfo].files]),
            runfiles = runfiles.merge(ctx.attr.src[DefaultInfo].default_runfiles),
        ),
        js_info(
            target = ctx.label,
            sources = src[JsInfo].sources if has_js_info else None,
            types = src[JsInfo].types if has_js_info else None,
            transitive_sources = src[JsInfo].transitive_sources if has_js_info else None,
            transitive_types = src[JsInfo].transitive_types if has_js_info else None,
            npm_package_store_infos = src[JsInfo].npm_package_store_infos if has_js_info else None,
            npm_sources = depset(
                [destination],
                transitive = [src[JsInfo].npm_sources] if has_js_info else [depset([src_dir])],
            ),
        ),
    ]

symlink_package = rule(
    implementation = _symlink_impl,
    attrs = {
        "src": attr.label(mandatory = True, providers = []),
    },
)
