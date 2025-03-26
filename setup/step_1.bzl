load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

def rules_angular_step1():
    npm_translate_lock(
        name = "rules_angular_npm",
        npmrc = "//:.npmrc",
        data = [
            "@rules_angular//:package.json",
            "@rules_angular//:patches/@angular__compiler-cli.patch",
        ],
        pnpm_lock = "@rules_angular//:pnpm-lock.yaml",
    )
