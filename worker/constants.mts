import path from "path";

// Walk up blaze-out/<mode>/bin.
// `js_binary` of `rules_js` starts in the `bin` directory by default.
export const execrootDiskPath = path.join(process.cwd(), "../../../");

/** Whether this worker, or instance should compile using vanilla TS. */
export const isVanillaTsCompilation = process.argv.includes("--vanilla-ts");
