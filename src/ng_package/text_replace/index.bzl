# Serializes a file into a struct that matches the `BazelFileInfo` type in the
# packager implementation. Useful for transmission of such information.
def _serialize_file(file):
    return struct(path = file.path, shortPath = file.short_path)

# Serializes a list of files into a JSON string that can be passed as CLI argument
# for the packager, matching the `BazelFileInfo[]` type in the packager implementation.
def _serialize_files_for_arg(files):
    result = []
    for file in files:
        result.append(_serialize_file(file))
    return json.encode(result)


def _text_replace_impl(ctx):
    # Directory where replaced files will be 
    replaced_directory = ctx.actions.declare_directory("%s" % ctx.label.name)

    inputs = ctx.files.data

    args = ctx.actions.args()
    args.use_param_file("%s", use_always = True)

    # The mapping of substitutions to apply
    args.add(ctx.attr.substitutions)
    # All of the file/directory locations to discover files to apply the substitutions to.
    args.add(_serialize_files_for_arg(inputs))
    # The location to place all of the copied files.
    args.add(json.encode(_serialize_file(replaced_directory)))
    
    ctx.actions.run(
        progress_message = "Applying substitutions (%s)" % ctx.label.name,
        mnemonic = "TextReplace",
        executable = ctx.executable._text_replace,
        inputs = inputs,
        outputs = [replaced_directory],
        arguments = [args],
        env = {
            "BAZEL_BINDIR": ".",
        },
    )
    
    return [
        DefaultInfo(files = depset([replaced_directory])),
    ]

text_replace = rule(
    implementation = _text_replace_impl,
    attrs = {
        "data": attr.label_list(
            doc = "List of labels which are included in the files considered for text replacement",
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
