workspace(name = "rules_angular")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "aspect_rules_ts",
    sha256 = "9acd128abe77397505148eaa6895faed57839560dbf2177dd6285e51235e2724",
    strip_prefix = "rules_ts-3.3.1",
    url = "https://github.com/aspect-build/rules_ts/releases/download/v3.3.1/rules_ts-v3.3.1.tar.gz",
)

load("@aspect_rules_ts//ts:repositories.bzl", "rules_ts_dependencies")

rules_ts_dependencies(
    #ts_version_from = "//:package.json",
    # TODO: Support in https://github.com/aspect-build/rules_ts/blob/main/ts/private/npm_repositories.bzl
    ts_version = "5.6.2",
)

http_archive(
    name = "aspect_rules_js",
    sha256 = "3388abe9b9728ef68ea8d8301f932b11b2c9a271d74741ddd5f3b34d1db843ac",
    strip_prefix = "rules_js-2.1.1",
    url = "https://github.com/aspect-build/rules_js/releases/download/v2.1.1/rules_js-v2.1.1.tar.gz",
)

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@aspect_rules_js//js:toolchains.bzl", "DEFAULT_NODE_VERSION", "rules_js_register_toolchains")

rules_js_register_toolchains(node_version = DEFAULT_NODE_VERSION)

load("//setup:step_1.bzl", "step_1")

step_1()

load("//setup:step_2.bzl", "step_2")

step_2()

http_archive(
    name = "devinfra",
    sha256 = "d05b113375bf2aab5b6ab5ab1cd02a554b1b5ab34caeb32c3100f5288640caaa",
    strip_prefix = "dev-infra-9ad44d7add69b53cec32d6486e9e8a83e7ec6622",
    url = "https://github.com/angular/dev-infra/archive/9ad44d7add69b53cec32d6486e9e8a83e7ec6622.zip",
)
