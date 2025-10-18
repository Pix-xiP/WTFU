var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    .logFn = pix_log_fn,
};

pub fn pix_log_fn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const _NRM = "\x1b[0;0m";
    // const _B_NRM = "\x1b[1;0m";
    const _B_RED = "\x1b[1;31m";
    // const _B_GRN = "\x1b[1;32m";
    const _B_YEL = "\x1b[1;33m";
    // const _B_BLU = "\x1b[1;34m";
    // const _B_MAG = "\x1b[1;35m";
    const _B_CYN = "\x1b[1;36m";
    const _B_WHT = "\x1b[1;37m";

    const prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    var buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&buf);
    const stderr = &stderr_writer.interface;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    // We basically do duplicated code here because it means we have no allocations that need to be
    // freed, giving us a much faster logging system.
    switch (level) {
        .debug => {
            // const level_txt = _B_WHT ++ "[" ++ comptime level.asText() ++ "]" ++ _NRM;
            const level_txt = _B_WHT ++ "[DEBU]" ++ _NRM;
            nosuspend stderr.print(level_txt ++ prefix ++ format ++ "\n", args) catch return;
        },
        .info => {
            const level_txt = _B_CYN ++ "[INFO]" ++ _NRM;
            nosuspend stderr.print(level_txt ++ prefix ++ format ++ "\n", args) catch return;
        },
        .warn => {
            const level_txt = _B_YEL ++ "[WARN]" ++ _NRM;
            nosuspend stderr.print(level_txt ++ prefix ++ format ++ "\n", args) catch return;
        },
        .err => {
            const level_txt = _B_RED ++ "[ERRO]" ++ _NRM;
            nosuspend stderr.print(level_txt ++ prefix ++ format ++ "\n", args) catch return;
        },
    }
    stderr.flush() catch |err| @panic(@errorName(err));
}

fn print_help() !void {
    var buf: [256]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&buf);
    const stderr = &stderr_writer.interface;

    try stderr.print(
        \\ {s} -- v{f}
        \\
        \\ Include multiple pairs_list by using the -p option multiple times.
        \\ If you don't know the ip address of the machine, or use DHCP, use broadcast for the IP.
        \\
        \\ Usage: {s} [options]
        \\
        \\  -p, --pair <ip,mac>  Add a pair of ip and mac address
        \\  -h, --help           Print this help and exit
        \\
        \\
    , .{ build_opts.prog_name, build_opts.version, build_opts.prog_name });

    try stderr.flush();
}

pub fn main() !void {
    const allocator, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var args = std.process.args();
    var pairs_list: std.ArrayList(Pair) = .empty;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try print_help();
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            std.debug.print("{s} --  v{f}\n", .{ build_opts.prog_name, build_opts.version });
            return;
        } else if (std.mem.eql(u8, arg, "--pair") or std.mem.eql(u8, arg, "-p")) {
            const pair = args.next() orelse {
                log.err("missing pair", .{});
                log.err("=================", .{});
                try print_help();
                return;
            };
            var pair_split = std.mem.splitSequence(u8, pair, ",");
            const ip = pair_split.next() orelse return error.MissingIp;
            const mac = pair_split.next() orelse return error.MissingMac;

            try pairs_list.append(allocator, Pair.init(ip, mac));
        }
    }

    if (pairs_list.items.len == 0) return error.NoPairs;

    if (is_debug) log.warn(
        \\
        \\ ==============================
        \\ PIX-WTFU RUNNING IN DEBUG MODE
        \\ ==============================
        \\
    , .{});

    const pairs = try pairs_list.toOwnedSlice(allocator);
    defer allocator.free(pairs);

    log.info("==============================", .{});
    log.info("pairs:", .{});
    for (pairs) |pair| {
        log.info("  ip: {s:>15}, \t mac: {s:>17}", .{ pair.ip, pair.mac });
    }
    log.info("==============================", .{});

    try wtfu.run(allocator, pairs);
}

const Pair = @import("Pair.zig");

const wtfu = @import("wtfu.zig");

const std = @import("std");
const log = std.log;
const assert = std.debug.assert;
const build_opts = @import("build_opts");
const builtin = @import("builtin");
