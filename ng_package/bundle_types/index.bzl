def bundle_type_declaration(
        ctx,
        entry_point,
        output_file,
        types,
        license_banner_file = None):
    """Rule helper for registering a bundle type declaration action."""

    # Microsoft's API extractor requires a `package.json` file to be provided. We
    # auto-generate such a file since such a file needs to exist on disk.
    package_json = ctx.actions.declare_file(
        "__api-extractor.json",
        sibling = output_file,
    )
    ctx.actions.write(package_json, content = json.encode({
        "name": "auto-generated-for-api-extractor",
    }))

    inputs = [package_json]
    args = ctx.actions.args()
    args.add(entry_point.path)
    args.add(output_file.path)
    args.add(package_json.path)

    if license_banner_file:
        args.add(license_banner_file.path)
        inputs.append(license_banner_file)

    # Pass arguments using a flag-file prefixed with `@`. This is
    # a requirement for build action arguments in persistent workers.
    # https://docs.bazel.build/versions/main/creating-workers.html#work-action-requirements.
    args.use_param_file("@%s", use_always = True)
    args.set_param_file_format("multiline")

    ctx.actions.run(
        mnemonic = "BundlingTypes",
        inputs = depset(inputs, transitive = [types]),
        outputs = [output_file],
        executable = ctx.executable._types_bundler_bin,
        arguments = [args],
        execution_requirements = {"supports-workers": "1"},
        progress_message = "Bundling types (%s)" % entry_point.short_path,
    )
