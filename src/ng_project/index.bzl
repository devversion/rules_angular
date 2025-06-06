load("@aspect_bazel_lib//lib:utils.bzl", "to_label")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("//src/ng_project/config:index.bzl", "ng_project_config")

def ng_project(
        name,
        srcs,
        angular_compiler_options = {},
        assets = [],
        tsconfig = None,
        **kwargs):
    """Angular compiler specific version of ts_project, running ngc on the provided files.

    Args:
        name: The target's name
        srcs: TypeScript sources included for compilation.
        angular_compiler_options: Dictionary of angular compiler options to provide to the compilation.
        assets: Assets needed for the Angular compilation
        tsconfig: The tsconfig to be used as a base configuration for the compilation.
        **kwargs: Additional arguments passed along to the underlying ts_project.
    """

    if tsconfig == None:
        fail("No tsconfig was provided. You must set the tsconfig attribute on {}.".format(to_label(name)))

    if type(tsconfig) == type(dict()):
        fail("A dictionary representation of tsconfig is not a valid parameter for tsconfig in this rule.")

    ng_project_config(
        name = "%s_ng_project_tsconfig" % name,
        angular_compiler_options = json.encode(angular_compiler_options),
        tsconfig = tsconfig,
    )

    ts_project(
        name = name,
        srcs = srcs + assets,
        # We provide the extra tsconfig dictionary information provided to the tsconfig attr
        # as this handles the parsing of the dictionary and merge into the final tsconfig
        tsconfig = "%s_ng_project_tsconfig" % name,
        # Use the worker from our own Angular rules, as the default worker
        # from `rules_ts` is incompatible with TS5+ and abandoned. We need
        # worker for efficient, fast DX and avoiding Windows no-sandbox issues.
        supports_workers = 1,
        tsc_worker = "@rules_angular//src/worker/angular:bin",
        build_progress_message = select({
            "@rules_angular//src/ng_project/config:partial_compilation_enabled": "Compiling Angular TS (partial compilation): {label}",
            "//conditions:default": "Compiling Angular TS: {label}",
        }),
        **kwargs
    )
