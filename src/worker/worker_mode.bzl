"""Bazel logic for conditionally compiling with the configured compiler in the worker implementation."""

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@aspect_rules_ts//ts:defs.bzl", "TsConfigInfo")

# -- Build setting that we use for conditionally using `select()`.
def _is_angular_worker_setting_impl(ctx):
    return None

is_angular_worker_setting = rule(
    implementation = _is_angular_worker_setting_impl,
    build_setting = config.bool(flag = True),
)

# -- Transition that configures the build setting from above.
def _angular_worker_transition_impl(_settings, _attr):
    return {"@rules_angular//src/worker:is_angular_worker_flag": True}

_angular_worker_transition = transition(
    implementation = _angular_worker_transition_impl,
    inputs = [],
    outputs = ["@rules_angular//src/worker:is_angular_worker_flag"],
)

# -- Rule to apply the transition on the `ts_project` and its dependencies.
def _transition_worker_lib_impl(ctx):
    return [
        ctx.attr.lib[0][DefaultInfo],
        ctx.attr.lib[0][JsInfo],
        ctx.attr.lib[0][TsConfigInfo],
    ]

transition_worker_lib = rule(
    implementation = _transition_worker_lib_impl,
    attrs = {
        "lib": attr.label(
            mandatory = True,
            cfg = _angular_worker_transition,
        ),
        # Needed in order to allow for the outgoing transition on the `deps` attribute.
        # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
