load("//ng_project/config:compilation_mode.bzl", "partial_compilation_transition")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")

def _angular_package_format_impl(ctx):
    entry_points = js_lib_helpers.gather_files_from_js_infos(
      ctx.attr.srcs,
      True, # include_sources
      False, # include_types
      False, # include_transitive_sources
      False, # include_transitive_types
      False, # include_npm_sources
    )
    js_files = js_lib_helpers.gather_files_from_js_infos(
      ctx.attr.srcs,
      True, # include_sources
      False, # include_types
      True, # include_transitive_sources
      False, # include_transitive_types
      False, # include_npm_sources
    )

    type_files = js_lib_helpers.gather_files_from_js_infos(
      ctx.attr.srcs,
      False, # include_sources
      True, # include_types
      False, # include_transitive_sources
      True, # include_transitive_types
      False, # include_npm_sources
    )

    return [
      DefaultInfo(files = depset(
        entry_points.to_list() +
        js_files.to_list() +
        type_files.to_list()
      )),
    ]



angular_package_format = rule(
  implementation = _angular_package_format_impl,
  attrs = {
    "srcs": attr.label_list(
      doc = "TODO",
      allow_files = True,
      cfg = partial_compilation_transition
    ),
    # Needed in order to allow for the outgoing transition on the `deps` attribute.
    # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
  }
)