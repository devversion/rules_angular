load("@rules_angular_npm//:repositories.bzl", "npm_repositories")

def rules_angular_deps_init():
    npm_repositories()
