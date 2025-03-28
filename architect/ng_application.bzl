"Macro definition to build and serve an application"

load("@aspect_rules_js//js:defs.bzl", "js_run_binary", "js_run_devserver")
load(":utils.bzl", "TEST_PATTERNS", "TOOLS", "ng_bin")

# Idiomatic configuration files created by `ng generate`
APPLICATION_CONFIG = [
    ":tsconfig.app.json",
]

# # Typical dependencies of angular apps
NPM_DEPS = lambda node_modules: ["/".join([node_modules, s]) for s in [
    "@angular/common",
    "@angular/core",
    "@angular/router",
    "@angular/platform-browser",
    "@angular/platform-browser-dynamic",
    "rxjs",
    "tslib",
    "zone.js",
]]

def ng_application(name, node_modules, ng_config, project_name = None, srcs = [], deps = [], **kwargs):
    """
    Bazel macro for compiling an NG application project. Creates {name}, {name}.serve targets.

    Args:
      name: the rule name
      node_modules: users installed and linked angular dependencies
      project_name: the Angular CLI project name, to the rule name
      srcs: application source files: typescript, HTML, and styles
      ng_config: angular workspace root configs
      deps: dependencies of the application, typically ng_library rules
      **kwargs: extra args passed to main Angular CLI rules
    """
    srcs = srcs or native.glob(["src/**/*"], exclude = TEST_PATTERNS)
    deps = deps + NPM_DEPS(node_modules)
    project_name = project_name if project_name else name
    tool = ng_bin(name, node_modules)

    js_run_binary(
        name = name,
        chdir = native.package_name(),
        args = ["%s:build" % project_name],
        out_dirs = ["dist"],
        tool = tool,
        srcs = srcs + deps + APPLICATION_CONFIG + TOOLS(node_modules) + [
            ng_config,
        ],
        **kwargs
    )

    js_run_devserver(
        name = name + ".serve",
        tool = tool,
        chdir = native.package_name(),
        args = ["%s:serve" % project_name],
        data = srcs + deps + APPLICATION_CONFIG + TOOLS(node_modules) + [
            ng_config,
        ],
    )
