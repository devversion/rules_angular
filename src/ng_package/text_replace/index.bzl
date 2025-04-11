
def _text_replace_impl(ctx):
    # Directory where replaced files will be 
    replaced_directory = ctx.actions.declare_directory("%s" % ctx.label.name)

    inputs = ctx.files.directory

    args = ctx.actions.args()
    args.use_param_file("%s", use_always = True)

    # The mapping of substitutions to apply
    args.add(ctx.attr.substitutions)
    # All of the file/directory locations to discover files to apply the substitutions to.
    args.add(json.encode([input.path for input in inputs]))
    # The location to place all of the copied files.
    args.add(replaced_directory.path)
    
    ctx.actions.run(
        progress_message = "Applying substitutions (%s)" % ctx.label.name,
        mnemonic = "TextReplace",
        executable = ctx.executable._text_replace,
        inputs = inputs,
        outputs = [replaced_directory],
        arguments = [args],
        env = {
            # Since the files be substituted in shouldn't be in `BAZEL_BINDIR`, we can set our location to `.` and use full paths.
            "BAZEL_BINDIR": ".",
        },
    )
    
    return [
        DefaultInfo(files = depset([replaced_directory])),
    ]

text_replace = rule(
    implementation = _text_replace_impl,
    attrs = {
        "directory": attr.label(
            doc = "A label which provides the directory for the files considered for text replacement",
            mandatory = True,
            allow_files = True,
        ),
        "substitutions": attr.string_dict(
            doc = """Key-value pairs which are replaced in all the files provided.""",
            mandatory = True,
        ),
        "_text_replace": attr.label(
            doc = "The binary used to process the provided files and apply text substitutions",
            executable = True,
            default = Label("//src/ng_package/text_replace:bin"),
            cfg = "exec",
        )
    },
)
