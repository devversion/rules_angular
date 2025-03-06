load("//ng_project/config:compilation_mode.bzl", "partial_compilation_transition")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")
load("@aspect_rules_js//js:providers.bzl", "JsInfo")

def _angular_package_format_impl(ctx):
  """################################## Helper methods ############################################
   We have defined these helper methods as nested function to allow it these functions to access
   the `ctx` argument to prevent needlessly passing a ton of values around.
  """

  def determine_entry_points():
    """Determine all of the entry points to be available within the angular package.
    We investigate each provided target as each target can only provide one entry point. This
    prevents us accidently creating an entry point at an unintended/unexpected level.

    Args:
      srcs: A list of targets to extract entry points from.

    Returns:
      A list of files which represent the list of all entrypoints for the angular package.
    """
    entry_points = []
    for target in ctx.attr.srcs:
      entry_point = None
      if target[JsInfo]:
        for file in target[JsInfo].sources.to_list():
          if _is_part_of_package(file) and file.basename == 'index.js':
            entry_point = file
            break
      if entry_point == None:
        fail("No entry point (index.js) file provided in %s" % target)
      
      entry_points.append(entry_point)

    return entry_points

  def _is_part_of_package(file):
    """Determine whether the provided file is part of the package being built.

    Args:
      file: String of the file path
    
    Returns:
      A boolean of whether the file is part of the package.
    """
    return file.short_path.startswith(ctx.label.package)

  ##################################### END OF HELPERS ############################################

  entry_points = determine_entry_points()

  return [
    DefaultInfo(files = depset(entry_points)),
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

