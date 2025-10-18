const Pair = @This();

ip: []const u8,
mac: []const u8,

pub fn init(ip: []const u8, mac: []const u8) Pair {
    return Pair{
        .ip = ip,
        .mac = mac,
    };
}
