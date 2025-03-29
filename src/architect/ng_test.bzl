"Macro definition to execute a test"

load("@aspect_bazel_lib//lib:directory_path.bzl", "directory_path")
load("@aspect_rules_js//js:defs.bzl", "js_test")
load(":utils.bzl", "TOOLS")

# Idiomatic configuration files created by `ng generate`
TEST_CONFIG = [
    ":tsconfig.spec.json",
]

NPM_DEPS = lambda node_modules: ["/".join([node_modules, s]) for s in [
    "@angular/core",
    "@angular/compiler",
    "@angular/platform-browser",
    "@angular/platform-browser-dynamic",
    "@types/jasmine",
    "jasmine-core",
    "karma-chrome-launcher",
    "karma-coverage",
    "karma-jasmine",
    "karma-jasmine-html-reporter",
    "tslib",
    "zone.js",
]]

def ng_test(name, node_modules, ng_config, project_name = None, deps = [], **kwargs):
    """
    Bazel macro for compiling an NG library project.

    Args:
      name: the rule name
      node_modules: users installed and linked angular dependencies
      project_name: the Angular CLI project name, defaults to current directory name
      deps: additional dependencies for tests
      ng_config: root configurations (angular.json, tsconfig.json)
      **kwargs: extra args passed to main Angular CLI rules
    """
    srcs = native.glob(["src/**/*"], exclude = ["dist/"])
    deps = deps + NPM_DEPS(node_modules)

    project_name = project_name if project_name else native.package_name().split("/").pop()
    entry_point = "_{}_architect_entry_point".format(name)
    directory_path(
        name = entry_point,
        directory = "{}/@angular-devkit/architect-cli/dir".format(node_modules),
        path = "bin/architect.js",
    )
    js_test(
        name = name,
        chdir = native.package_name(),
        args = ["%s:test" % project_name, "--no-watch"],
        entry_point = entry_point,
        data = srcs + deps + TEST_CONFIG + TOOLS(node_modules) + [
            ng_config,
            ":ng-package",
            "{}/@angular-devkit/architect-cli".format(node_modules),
        ],
        log_level = "debug",
        **kwargs
    )
