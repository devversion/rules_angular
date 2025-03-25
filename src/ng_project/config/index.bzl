load("@aspect_rules_ts//ts:defs.bzl", "ts_config")
load("//src/ng_project/config:config.bzl", _ng_project_config = "ng_project_config")

def ng_project_config(name, tsconfig, angular_compiler_options):
    # Create the angularCompilerOptions specific tsconfig file.
    _ng_project_config(
        name = "%s_ng_compiler_options" % name,
        angular_compiler_options = angular_compiler_options,
        tsconfig = tsconfig,
    )

    # Create the new tsconfig target using the newly created config to extend the provided
    # tsconfig file.
    ts_config(
        name = name,
        src = "%s_ng_compiler_options" % name,
        deps = [tsconfig],
    )
