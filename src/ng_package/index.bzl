load("@aspect_rules_js//npm:defs.bzl", _npm_package = "npm_package")
load("//src/ng_package:angular_package_format.bzl", "angular_package_format")

def ng_package(name, **kwargs):
    angular_package_format(
        name = "%s_apf" % name,
        **kwargs
    )

    _npm_package(
        name = name,
        srcs = [
            "%s_apf" % name,
        ],
        replace_prefixes = {
            "%s_apf.apf" % name: "/",
        },
        package = kwargs.get("package", None),
    )
