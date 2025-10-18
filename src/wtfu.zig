pub fn run(allocator: std.mem.Allocator, pairs: []const Pair) !void {
    _ = allocator;
    // const sock = try std.posix.socket(std.posix.AF_INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
    // errdefer {
    //     std.posix.close(sock);
    //     sock = -1;
    // }
    //
    // try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    // try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.KEEPALIVE, &std.mem.toBytes(@as(c_int, 1)));
    const addr = try std.net.Address.parseIp("0.0.0.0", 44332);

    var server = std.net.Address.listen(addr, .{ .reuse_address = true }) catch |err| switch (err) {
        error.AddressInUse => {
            log.err("Address already in use: {any}", .{err});
            return;
        },
        else => {
            log.err("Error listening", .{});
            log.err("{any}", .{err});
            return;
        },
    };

    while (true) {
        const client = server.accept() catch |err| {
            log.err("Error accepting connection", .{});
            log.err("{any}", .{err});
            continue;
        };

        defer client.stream.close();

        var buf: [256]u8 = undefined;
        const bytes = try client.stream.read(&buf);

        var split = std.mem.splitSequence(u8, buf[0..bytes], "\n");
        const in_ip = split.next() orelse continue;

        log.info("read {d} bytes. got {s}", .{ bytes, buf });

        for (pairs) |pair| {
            log.info("comparing '{s}' to '{s}'", .{ pair.ip, in_ip });
            if (std.mem.eql(u8, pair.ip, in_ip)) {
                log.info("sending magic packet to {s}--{x}", .{ pair.ip, pair.mac });
                try send_magic_packet(pair);
            }
        }
    }
}

fn rn_send_magic_packet(pair: Pair) !void {
    // setup address with wol port.
    var addr = try std.net.Address.parseIp(pair.ip, 9);
}

fn send_magic_packet(pair: Pair) !void {
    const timeout: std.posix.timeval = .{ .sec = 5, .usec = 0 };
    const sock = try std.posix.socket(
        std.posix.AF.INET,
        std.posix.SOCK.DGRAM,
        std.posix.IPPROTO.UDP,
    );
    try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, &std.mem.toBytes(@as(c_int, 1)));
    try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));

    var addr = try std.net.Address.parseIp(pair.ip, 9);
    try std.posix.bind(sock, &addr.any, addr.getOsSockLen());

    var magic: [102]u8 = undefined;
    @memcpy(magic[0..], pair.mac);

    log.info("magic: {x}", .{magic});

    var i: usize = 1;

    while (i <= 16) : (i += 1) {
        @memcpy(magic[i * 6 .. (i + 1) * 6], magic[0..6]);
    }

    _ = std.posix.sendto(sock, magic[0..], 0, &addr.any, addr.getOsSockLen()) catch |err| switch (err) {
        error.AccessDenied => {
            log.err("Access denied", .{});
        },
        else => {
            log.err("Error sending packet", .{});
            log.err("{}", .{err});
        },
    };

    log.info("sent magic packet to {s}--{x}", .{ pair.ip, pair.mac });
}

const Pair = @import("Pair.zig");

const std = @import("std");
const log = std.log;
