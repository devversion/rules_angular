"Workaround for https://github.com/bazelbuild/bazel-skylib/pull/571"
load("@bazel_skylib//:bzl_library.bzl", _bzl_library = "bzl_library")

def bzl_library(name, srcs, deps = [], visibility = None):
    _bzl_library(
        name = name,
        srcs = srcs,
        deps = deps,
        visibility = visibility,
    )
    if hasattr(native, "starlark_doc_extract"):
        for i, src in enumerate(srcs):
            native.starlark_doc_extract(
                name = "{}.doc_extract{}".format(name, i if i > 0 else ""),
                src = src,
            deps = deps,
        )
