load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//src/ng_project/config:compilation_mode.bzl", "partial_compilation_transition")

# Prints a debug message if "--define=VERBOSE_LOGS=true" is specified.
def _debug(vars, *args):
    if "VERBOSE_LOGS" in vars.keys():
        print("[ng_package.bzl]", args)

_DEFAULT_NG_PACKAGER = "//src/ng_package/packager:bin"
_DEFAULT_ROLLUP_CONFIG_TMPL = "//src/ng_package/rollup:rollup.config"
_DEFAULT_ROLLUP = "//src/ng_package/rollup:bin"

_NG_PACKAGE_MODULE_MAPPINGS_ATTR = "ng_package_module_mappings"

WELL_KNOWN_EXTERNALS = [
    "@angular/animations",
    "@angular/animations/browser",
    "@angular/animations/browser/testing",
    "@angular/common",
    "@angular/common/http",
    "@angular/common/http/testing",
    "@angular/common/testing",
    "@angular/common/upgrade",
    "@angular/compiler",
    "@angular/core",
    "@angular/core/testing",
    "@angular/elements",
    "@angular/forms",
    "@angular/localize",
    "@angular/localize/init",
    "@angular/platform-browser",
    "@angular/platform-browser/animations",
    "@angular/platform-browser/testing",
    "@angular/platform-browser-dynamic",
    "@angular/platform-browser-dynamic/testing",
    "@angular/platform-server",
    "@angular/platform-server/init",
    "@angular/platform-server/testing",
    "@angular/router",
    "@angular/router/testing",
    "@angular/router/upgrade",
    "@angular/service-worker",
    "@angular/service-worker/config",
    "@angular/upgrade",
    "@angular/upgrade/static",
    "rxjs",
    "rxjs/operators",
    "tslib",
]

def _write_rollup_config(
        ctx,
        root_dir,
        metadata_arg,
        side_effect_entry_points,
        dts_mode):
    filename = "_%s_%s.rollup.conf.js" % (ctx.label.name, "dts" if dts_mode else "fesm")
    config = ctx.actions.declare_file(filename)

    mappings = dict()
    all_deps = ctx.attr.srcs
    for dep in all_deps:
        if hasattr(dep, _NG_PACKAGE_MODULE_MAPPINGS_ATTR):
            for k, v in getattr(dep, _NG_PACKAGE_MODULE_MAPPINGS_ATTR).items():
                if k in mappings and mappings[k] != v:
                    fail(("duplicate module mapping at %s: %s maps to both %s and %s" %
                          (dep.label, k, mappings[k], v)), "deps")
                mappings[k] = v

    externals = WELL_KNOWN_EXTERNALS + ctx.attr.externals

    # Pass external & globals through a templated config file because on Windows there is
    # an argument limit and we there might be a lot of globals which need to be passed to
    # rollup.

    ctx.actions.expand_template(
        output = config,
        template = ctx.file.rollup_config_tmpl,
        substitutions = {
            "TMPL_banner_file": "\"%s\"" % ctx.file.license_banner.path if ctx.file.license_banner else "undefined",
            "TMPL_module_mappings": str(mappings),
            # TODO: Determine node_modules_root
            "TMPL_node_modules_root": "node_modules",
            "TMPL_metadata": json.encode(metadata_arg),
            "TMPL_root_dir": root_dir,
            "TMPL_workspace_name": ctx.workspace_name,
            "TMPL_external": ", ".join(["'%s'" % e for e in externals]),
            "TMPL_side_effect_entrypoints": json.encode(side_effect_entry_points),
            "TMPL_dts_mode": "true" if dts_mode else "false",
        },
    )

    return config

def _run_rollup(ctx, rollup_config, inputs, dts_mode):
    mode_label = "dts" if dts_mode else "fesm"
    outdir = ctx.actions.declare_directory("%s_%s_bundle_out" % (ctx.label.name, mode_label))

    args = ctx.actions.args()
    args.add("--config", rollup_config)
    args.add("--output.format", "esm")
    args.add("--output.dir", outdir.path)
    args.add("--preserveSymlinks")

    # We will produce errors as needed. Anything else is spammy: a well-behaved
    # bazel rule prints nothing on success.
    args.add("--silent")

    other_inputs = [rollup_config]
    if ctx.file.license_banner:
        other_inputs.append(ctx.file.license_banner)
    ctx.actions.run(
        progress_message = "ng_package: Rollup %s (%s)" % (ctx.label, mode_label),
        mnemonic = "AngularPackageRollup",
        inputs = depset(other_inputs, transitive = [inputs]),
        outputs = [outdir],
        executable = ctx.executable.rollup,
        tools = depset(ctx.files._rollup_runtime_deps),
        arguments = [args],
        env = {
            "BAZEL_BINDIR": ".",
        },
    )
    return outdir

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

def _find_matching_file(files, search_short_paths):
    for file in files:
        for search_short_path in search_short_paths:
            if file.short_path == search_short_path:
                return file
    fail("Could not find file that matches: %s" % (", ".join(search_short_paths)))

def _is_part_of_package(file, owning_package):
    return file.short_path.startswith(owning_package)

def _filter_esm_files_to_include(files, owning_package):
    result = []

    for file in files:
        # We skip all `.externs.js` files as those should not be shipped as part of
        # the ESM2022 output. The externs are empty because `ngc-wrapped` disables
        # externs generation in prodmode for workspaces other than `google3`.
        if file.path.endswith("externs.js"):
            continue

        # We omit all non-JavaScript files. These are not required for the FESM bundle
        # generation and are not expected to be put into the `esm2022` output.
        if not file.path.endswith(".js") and not file.path.endswith(".mjs"):
            continue

        if _is_part_of_package(file, owning_package):
            result.append(file)

    return result

def _angular_package_format_impl(ctx):
    npm_package_directory = ctx.actions.declare_directory("%s.ng_pkg" % ctx.label.name)
    owning_package = ctx.label.package

    # The name of the primary entry-point FESM bundles, computed name from the owning package
    # e.g. For `packages/core:npm_package`, the name is resolved to be `core`.
    primary_bundle_name = owning_package.split("/")[-1]

    # Static files are files which are simply copied over into the tree artifact. These files
    # are not picked up by the entry-point bundling etc. Can also be generated by e.g. a genrule.
    static_files = []

    # Collect static files, and skip files outside of the current owning package.
    for file in ctx.files.srcs:
        if not file.short_path.startswith(owning_package):
            _debug(ctx.var, "File %s is defined outside of %s but part of `srcs`, skipping." % (file, owning_package))
        else:
            static_files.append(file)

    # List of unscoped direct and transitive ESM sources that are provided
    # by all entry-points.
    unscoped_all_entry_point_esm2022 = []

    # List of unscoped direct and transitive dts sources that are provided
    # by all entry-points.
    unscoped_all_entry_point_dts = []

    # We infer the entry points to be:
    # - ng_module rules in the deps (they have an "angular" provider)
    # - in this package or a subpackage
    # - those that have a module_name attribute (they produce flat module metadata)
    collected_entry_points = []

    # Name of the NPM package. The name is computed as we iterate through all
    # dependencies of the `ng_package`.
    npm_package_name = None

    for dep in ctx.attr.srcs:
        if not dep.label.package.startswith(owning_package):
            fail("Unexpected dependency. %s is defined outside of %s." % (dep, owning_package))

        # Module name of the current entry-point. eg. @angular/core/testing
        module_name = ""

        # Package name where this entry-point is defined in,
        entry_point_package = dep.label.package

        # Intentionally evaluates to empty string for the main entry point
        entry_point = entry_point_package[len(owning_package) + 1:]

        # Whether this dependency is for the primary entry-point of the package.
        is_primary_entry_point = entry_point == ""

        # Collect ESM2022 and type definition source files from the dependency, including
        # transitive sources which are not directly defined in the entry-point. This is
        # necessary to allow for entry-points to rely on sub-targets (as a perf improvement).
        unscoped_esm2022_depset = dep[JsInfo].sources
        unscoped_types_depset = dep[JsInfo].transitive_types

        unscoped_all_entry_point_esm2022.append(unscoped_esm2022_depset)
        unscoped_all_entry_point_dts.append(unscoped_types_depset)

        # Extract the "module_name" from either "ts_library" or "ng_module". Both
        # set the "module_name" in the provider struct.
        if hasattr(dep, "module_name"):
            module_name = dep.module_name

        #elif LinkablePackageInfo in dep:
        #    # Modern `ts_project` interop targets don't make use of legacy struct
        #    # providers, and instead encapsulate the `module_name` in an idiomatic provider.
        #    module_name = dep[LinkablePackageInfo].package_name

        if is_primary_entry_point:
            npm_package_name = module_name

        if hasattr(dep, "angular") and hasattr(dep.angular, "flat_module_metadata"):
            # For dependencies which are built using the "ng_module" with flat module bundles
            # enabled, we determine the module name, the flat module index file, the metadata
            # file and the typings entry point from the flat module metadata which is set by
            # the "ng_module" rule.
            ng_module_metadata = dep.angular.flat_module_metadata
            module_name = ng_module_metadata.module_name
            es2022_entry_point = ng_module_metadata.flat_module_out_prodmode_file
            typings_entry_point = ng_module_metadata.typings_file
            guessed_paths = False

            _debug(
                ctx.var,
                "entry-point %s is built using a flat module bundle." % dep,
                "using %s as main file of the entry-point" % es2022_entry_point,
            )
        else:
            _debug(
                ctx.var,
                "entry-point %s does not have flat module metadata." % dep,
                "guessing `index.mjs` as main file of the entry-point",
            )

            # Note: Using `to_list()` is expensive but we cannot get around this here as
            # we need to filter out generated files and need to be able to iterate through
            # typing files in order to determine the entry-point type file.
            unscoped_types = unscoped_types_depset.to_list()

            # Note: Using `to_list()` is expensive but we cannot get around this here as
            # we need to filter out generated files to be able to detect entry-point index
            # files when no flat module metadata is available.
            unscoped_esm2022_list = unscoped_esm2022_depset.to_list()

            # In case the dependency is built through the "ts_library" rule, or the "ng_module"
            # rule does not generate a flat module bundle, we determine the index file and
            # typings entry-point through the most reasonable defaults (i.e. "package/index").
            es2022_entry_point = _find_matching_file(
                unscoped_esm2022_list,
                [
                    "%s/index.mjs" % entry_point_package,
                    # Fallback for `ts_project` support where `.mjs` is not auto-generated.
                    "%s/index.js" % entry_point_package,
                ],
            )
            typings_entry_point = _find_matching_file(unscoped_types, ["%s/index.d.ts" % entry_point_package])
            guessed_paths = True

            # module_name = es2022_entry_point
            module_name = es2022_entry_point.short_path[len(owning_package) + 1:][:-(len("index.js") + 1)]

        bundle_name_base = primary_bundle_name if is_primary_entry_point else entry_point
        dts_bundle_name_base = "index" if is_primary_entry_point else "%s/index" % entry_point

        # Store the collected entry point in a list of all entry-points. This
        # can be later passed to the packager as a manifest.
        collected_entry_points.append(struct(
            module_name = module_name,
            es2022_entry_point = es2022_entry_point,
            fesm2022_file = "fesm2022/%s.mjs" % bundle_name_base,
            # TODO(devversion): Put all types under `/types/` folder. Breaking change in v20.
            dts_bundle_relative_path = "%s.d.ts" % dts_bundle_name_base,
            typings_entry_point = typings_entry_point,
            guessed_paths = guessed_paths,
        ))

    # Note: Using `to_list()` is expensive but we cannot get around this here as
    # we need to filter out generated files and need to be able to iterate through
    # JavaScript files in order to capture the relevant package-owned `esm2022/` in the APF.
    unscoped_all_entry_point_esm2022_depset = depset(transitive = unscoped_all_entry_point_esm2022)
    unscoped_all_entry_point_esm2022_list = unscoped_all_entry_point_esm2022_depset.to_list()

    # Filter ESM2022 JavaScript inputs to files which are part of the owning package. The
    # packager should not copy external files into the package.
    esm2022 = _filter_esm_files_to_include(unscoped_all_entry_point_esm2022_list, owning_package)

    unscoped_all_entry_point_dts_depset = depset(transitive = unscoped_all_entry_point_dts)

    packager_inputs = (
        static_files +
        esm2022
    )

    packager_args = ctx.actions.args()
    packager_args.use_param_file("%s", use_always = True)

    # The order of arguments matters here, as they are read in order in packager.ts.
    packager_args.add(npm_package_directory.path)
    packager_args.add(ctx.label.package)

    # Marshal the metadata into a JSON string so we can parse the data structure
    # in the TypeScript program easily.
    metadata_arg = {}
    for m in collected_entry_points:
        # The captured properties need to match the `EntryPointInfo` interface
        # in the packager executable tool.
        metadata_arg[m.module_name] = {
            "index": _serialize_file(m.es2022_entry_point),
            "typingsEntryPoint": _serialize_file(m.typings_entry_point),
            "fesm2022RelativePath": m.fesm2022_file,
            "dtsBundleRelativePath": m.dts_bundle_relative_path,
            # If the paths for that entry-point were guessed (e.g. "ts_library" rule or
            # "ng_module" without flat module bundle), we pass this information to the packager.
            "guessedPaths": m.guessed_paths,
        }

    for ep in ctx.attr.side_effect_entry_points:
        if not metadata_arg[ep]:
            known_entry_points = ",".join([e.module_name for e in collected_entry_points])
            fail("Unknown entry-point (%s) specified to include side effects. " % ep +
                 "The following entry-points are known: %s" % known_entry_points)

    fesm_rollup_config = _write_rollup_config(
        ctx,
        ctx.bin_dir.path,
        metadata_arg,
        ctx.attr.side_effect_entry_points,
        dts_mode = False,
    )
    fesm_rollup_inputs = depset(static_files, transitive = [unscoped_all_entry_point_esm2022_depset])
    fesm_bundles_out = _run_rollup(ctx, fesm_rollup_config, fesm_rollup_inputs, dts_mode = False)

    dts_rollup_config = _write_rollup_config(
        ctx,
        ctx.bin_dir.path,
        metadata_arg,
        ctx.attr.side_effect_entry_points,
        dts_mode = True,
    )
    dts_rollup_inputs = depset(static_files, transitive = [unscoped_all_entry_point_dts_depset])
    dts_bundles_out = _run_rollup(ctx, dts_rollup_config, dts_rollup_inputs, dts_mode = True)

    packager_inputs.append(fesm_bundles_out)
    packager_inputs.append(dts_bundles_out)

    # Encodes the package metadata with all its entry-points into JSON so that
    # it can be deserialized by the packager tool. The struct needs to match with
    # the `PackageMetadata` interface in the packager tool.
    packager_args.add(json.encode(struct(
        npmPackageName = npm_package_name,
        entryPoints = metadata_arg,
        fesmBundlesOut = _serialize_file(fesm_bundles_out),
        dtsBundlesOut = _serialize_file(dts_bundles_out),
    )))

    if ctx.file.readme_md:
        packager_inputs.append(ctx.file.readme_md)
        packager_args.add(ctx.file.readme_md.path)
    else:
        # placeholder
        packager_args.add("")

    if ctx.file.license:
        packager_inputs.append(ctx.file.license)
        packager_args.add(ctx.file.license.path)
    else:
        #placeholder
        packager_args.add("")

    packager_args.add(_serialize_files_for_arg(esm2022))
    packager_args.add(_serialize_files_for_arg(static_files))

    packager_args.add(json.encode(ctx.attr.side_effect_entry_points))

    ctx.actions.run(
        progress_message = "Angular Packaging: building npm package %s" % str(ctx.label),
        mnemonic = "AngularPackage",
        inputs = packager_inputs,
        outputs = [npm_package_directory],
        executable = ctx.executable.ng_packager,
        arguments = [packager_args],
        env = {
            "BAZEL_BINDIR": ".",
        },
    )

    return [
        DefaultInfo(files = depset([npm_package_directory])),
    ]

angular_package_format = rule(
    implementation = _angular_package_format_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "TODO",
            allow_files = True,
            cfg = partial_compilation_transition,
        ),
        "side_effect_entry_points": attr.string_list(
            doc = "List of entry-points that have top-level side-effects",
            default = [],
        ),
        "externals": attr.string_list(
            doc = """List of external module that should not be bundled into the flat ESM bundles.""",
            default = [],
        ),
        "license_banner": attr.label(
            doc = """A .txt file passed to the `banner` config option of rollup.
        The contents of the file will be copied to the top of the resulting bundles.
        Configured substitutions are applied like with other files in the package.""",
            allow_single_file = [".txt"],
        ),
        "license": attr.label(
            doc = """A textfile that will be copied to the root of the npm package.""",
            allow_single_file = True,
        ),
        "readme_md": attr.label(allow_single_file = [".md"]),
        "ng_packager": attr.label(
            default = Label(_DEFAULT_NG_PACKAGER),
            executable = True,
            cfg = "exec",
        ),
        "rollup": attr.label(
            default = Label(_DEFAULT_ROLLUP),
            executable = True,
            cfg = "exec",
        ),
        "rollup_config_tmpl": attr.label(
            default = Label(_DEFAULT_ROLLUP_CONFIG_TMPL),
            allow_single_file = True,
        ),
        "_rollup_runtime_deps": attr.label_list(
            default = [
                Label("//:node_modules/@rollup/plugin-commonjs"),
                Label("//:node_modules/@rollup/plugin-node-resolve"),
                Label("//:node_modules/magic-string"),
                Label("//:node_modules/rollup-plugin-dts"),
                Label("//:node_modules/rollup-plugin-sourcemaps2"),
            ],
        ),

        # Needed in order to allow for the outgoing transition on the `deps` attribute.
        # https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
