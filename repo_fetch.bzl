load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

def rules_angular_deps_fetch():
    npm_translate_lock(
        name = "rules_angular_npm",
        npmrc = "@rules_angular//:.npmrc",
        pnpm_lock = "@rules_angular//:pnpm-lock.yaml",
        verify_node_modules_ignored = "@rules_angular//:.bazelignore",
    )
