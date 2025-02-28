NgCompilationMode = provider(
    fields = {"enabled": "Whether partial compilation is enabled for ngc."},
)

def _partial_compilation_flag_impl(ctx):
    return NgCompilationMode(enabled = ctx.build_setting_value)

partial_compilation_flag = rule(
    implementation = _partial_compilation_flag_impl,
    # TODO: Determine if this should be a string config so that all possible compilation modes
    # are supported. 
    build_setting = config.bool(flag = True),
)
