workspace(name = "rules_angular")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "aspect_rules_ts",
    sha256 = "6b15ac1c69f2c0f1282e41ab469fd63cd40eb2e2d83075e19b68a6a76669773f",
    strip_prefix = "rules_ts-3.6.0",
    url = "https://github.com/aspect-build/rules_ts/releases/download/v3.6.0/rules_ts-v3.6.0.tar.gz",
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

load("@aspect_rules_js//js:toolchains.bzl", "rules_js_register_toolchains")

rules_js_register_toolchains(
    node_repositories = {
        "24.0.0-darwin_arm64": ("node-v24.0.0-darwin-arm64.tar.gz", "node-v24.0.0-darwin-arm64", "194e2f3dd3ec8c2adcaa713ed40f44c5ca38467880e160974ceac1659be60121"),
        "24.0.0-darwin_amd64": ("node-v24.0.0-darwin-x64.tar.gz", "node-v24.0.0-darwin-x64", "f716b3ce14a7e37a6cbf97c9de10d444d7da07ef833cd8da81dd944d111e6a4a"),
        "24.0.0-linux_arm64": ("node-v24.0.0-linux-arm64.tar.xz", "node-v24.0.0-linux-arm64", "d40ec7ffe0b82b02dce94208c84351424099bd70fa3a42b65c46d95322305040"),
        "24.0.0-linux_ppc64le": ("node-v24.0.0-linux-ppc64le.tar.xz", "node-v24.0.0-linux-ppc64le", "cfa0e8d51a2f9a446f1bfb81cdf4c7e95336ad622e2aa230e3fa1d093c63d77d"),
        "24.0.0-linux_s390x": ("node-v24.0.0-linux-s390x.tar.xz", "node-v24.0.0-linux-s390x", "e37a04c7ee05416ec1234fd3255e05b6b81287eb0424a57441c8b69f0a155021"),
        "24.0.0-linux_amd64": ("node-v24.0.0-linux-x64.tar.xz", "node-v24.0.0-linux-x64", "59b8af617dccd7f9f68cc8451b2aee1e86d6bd5cb92cd51dd6216a31b707efd7"),
        "24.0.0-windows_amd64": ("node-v24.0.0-win-x64.zip", "node-v24.0.0-win-x64", "3d0fff80c87bb9a8d7f49f2f27832aa34a1477d137af46f5b14df5498be81304"),
    },
    node_version = "24.0.0",
)

load("//setup:step_1.bzl", "rules_angular_step1")

rules_angular_step1()

load("//setup:step_2.bzl", "rules_angular_step2")

rules_angular_step2()

load("//setup:step_3.bzl", "rules_angular_step3")

rules_angular_step3(
    angular_compiler_cli = "//:node_modules/@angular/compiler-cli",
    typescript = "//:node_modules/typescript",
)

http_archive(
    name = "devinfra",
    sha256 = "d05b113375bf2aab5b6ab5ab1cd02a554b1b5ab34caeb32c3100f5288640caaa",
    strip_prefix = "dev-infra-9ad44d7add69b53cec32d6486e9e8a83e7ec6622",
    url = "https://github.com/angular/dev-infra/archive/9ad44d7add69b53cec32d6486e9e8a83e7ec6622.zip",
)
