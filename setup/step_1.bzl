load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

def step_1():
    npm_translate_lock(
        name = "rules_angular_npm",
        data = [
            "@rules_angular//:package.json",
        ],
        pnpm_lock = "@rules_angular//:pnpm-lock.yaml",
    )
