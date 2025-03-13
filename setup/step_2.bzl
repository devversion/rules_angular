load("@aspect_rules_rollup//rollup:dependencies.bzl", "rules_rollup_dependencies")
load("@rules_angular_npm//:repositories.bzl", "npm_repositories")

def step_2():
    npm_repositories()
    rules_rollup_dependencies()
