def _step3_impl(rctx):
    rctx.file(
        "BUILD.bazel",
        content = """
alias(
    name = "bin",
    actual = "%s",
    visibility = ["//visibility:public"],
)
""" % rctx.attr.angular_compiler_cli,
    )

_step3 = repository_rule(
    implementation = _step3_impl,
    attrs = {
        "angular_compiler_cli": attr.label(
            mandatory = True,
            doc = "Label pointing to the `@angular/compiler-cli` package.",
        ),
    },
)

def rules_angular_step3(angular_compiler_cli):
    _step3(
        name = "rules_angular_compiler",
        angular_compiler_cli = angular_compiler_cli,
    )
