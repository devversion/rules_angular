load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def step_1():
    npm_translate_lock(
        name = "rules_angular_npm",
        data = [
            "@rules_angular//:package.json",
        ],
        npmrc = "@rules_angular//:.npmrc",
        pnpm_lock = "@rules_angular//:pnpm-lock.yaml",
    )

    maybe(
        http_archive,
        name = "aspect_rules_rollup",
        sha256 = "c4062681968f5dcd3ce01e09e4ba73670c064744a7046211763e17c98ab8396e",
        strip_prefix = "rules_rollup-2.0.0",
        url = "https://github.com/aspect-build/rules_rollup/releases/download/v2.0.0/rules_rollup-v2.0.0.tar.gz",
    )
