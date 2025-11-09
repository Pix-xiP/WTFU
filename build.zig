const std = @import("std");

const version = std.SemanticVersion{
    .major = 1,
    .minor = 0,
    .patch = 0,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "pix-wtfu",
        .root_module = mod,
    });

    const options = b.addOptions();
    options.addOption(std.SemanticVersion, "version", version);
    options.addOption([]const u8, "prog_name", "pix-wtfu");
    exe.root_module.addOptions("build_opts", options);

    b.installArtifact(exe);

    const exe_check = b.addExecutable(.{
        .name = "pix-wtfu",
        .root_module = mod,
    });
    const check = b.step("check", "Check if prog compiles");
    check.dependOn(&exe_check.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
}
