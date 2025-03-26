def _step3_impl(rctx):
    rctx.file(
        "BUILD.bazel",
        content = """
alias(
    name = "angular_compiler_cli",
    actual = "{angular_compiler_cli}",
    visibility = ["//visibility:public"],
)

alias(
    name = "typescript",
    actual = "{typescript}",
    visibility = ["//visibility:public"],
)
""".format(
            angular_compiler_cli = rctx.attr.angular_compiler_cli,
            typescript = rctx.attr.typescript,
        ),
    )

_step3 = repository_rule(
    implementation = _step3_impl,
    attrs = {
        "angular_compiler_cli": attr.label(
            mandatory = True,
            doc = "Label pointing to the `@angular/compiler-cli` package.",
        ),
        "typescript": attr.label(
            mandatory = True,
            doc = "Label pointing to the `typescript` package.",
        ),
    },
)

def rules_angular_step3(angular_compiler_cli, typescript):
    _step3(
        name = "rules_angular_configurable_deps",
        angular_compiler_cli = angular_compiler_cli,
        typescript = typescript,
    )
