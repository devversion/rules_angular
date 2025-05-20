load("@aspect_bazel_lib//lib:run_binary.bzl", "run_binary")
load("@aspect_rules_js//npm:defs.bzl", "npm_package")
load("//src/architect:ng_application.bzl", CLI_DEFAULT_DEPS = "NPM_DEPS")

def optimize_angular_app(name, srcs = [], deps = []):
    npm_package(
        name = "_%s_package" % name,
        srcs = srcs,
    )

    run_binary(
        name = "_%s_build" % name,
        tool = "@rules_angular//src/optimization:optimize",
        srcs = [
            ":_%s_package" % name,
            "@rules_angular//src/optimization/boilerplate",
        ] + CLI_DEFAULT_DEPS("//:node_modules") + deps,
        out_dirs = ["%s_cli_execution" % name],
        use_default_shell_env = True,
        progress_message = "Optimizing Angular app: %{label}",
        mnemonic = "OptimizeAngular",
        env = {
            "BAZEL_BINDIR": ".",
            "OUT_DIR": "$(@)",
            "BOILERPLATE_DIR": "$(execpath @rules_angular//src/optimization/boilerplate)",
            "INPUT_PACKAGE": "$(execpath :_%s_package)" % name,
        },
    )

    npm_package(
        name = name,
        srcs = [":_%s_build" % name],
        include_srcs_packages = ["."],
        include_srcs_patterns = ["%s_cli_execution/dist/boilerplate/browser/**" % name],
        replace_prefixes = {
            "%s_cli_execution/dist/boilerplate/browser" % name: "",
        },
    )
