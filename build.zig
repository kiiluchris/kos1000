const std = @import("std");

const cflags = [_][]const u8{
    "-std=c11", "-O2", "-g3", "-Wall", "-Wextra", "-fno-stack-protector", "-ffreestanding", "-nostdlib",
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const optimize = b.standardOptimizeOption(.{});

    const shell_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .strip = false,
        .link_libc = false,
    });
    shell_mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "shell.c",
            "user.c",
            "common.c",
        },
        .flags = &cflags,
    });

    const shell = b.addExecutable(.{
        .name = "shell",
        .root_module = shell_mod,
    });
    shell.entry = .disabled;
    shell.setLinkerScript(b.path("./src/user.ld"));
    b.installArtifact(shell);

    const shell_bin_cmd = b.addSystemCommand(&.{
        "sh",
    });
    shell_bin_cmd.addFileArg(b.path("objcopy.sh"));
    _ = shell_bin_cmd.addOutputDirectoryArg("test");
    shell_bin_cmd.addArtifactArg(shell);
    const shell_embeddable_elf = shell_bin_cmd.addOutputFileArg("shell.bin.o");

    const kernel_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .strip = false,
        .link_libc = false,
    });
    kernel_mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "kernel.c",
            "common.c",
        },
        .flags = &cflags,
    });
    kernel_mod.addObjectFile(shell_embeddable_elf);

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_module = kernel_mod,
    });
    kernel.step.dependOn(&shell_bin_cmd.step);
    kernel.entry = .disabled;
    kernel.setLinkerScript(b.path("./src/kernel.ld"));
    b.installArtifact(kernel);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-riscv32",
    });
    run_cmd.addArgs(&.{
        "-machine",   "virt",
        "-bios",      "default",
        "-serial",    "mon:stdio",
        "-nographic", "--no-reboot",
        "-d",         "unimp,guest_errors,int,cpu_reset",
        "-D",         "qemu.log",
        "-device",    "virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0",
        "-kernel",
    });
    run_cmd.addArtifactArg(kernel);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel in VM");
    run_step.dependOn(&run_cmd.step);
}
