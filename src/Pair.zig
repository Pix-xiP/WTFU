const Pair = @This();

ip: []const u8,
mac: []const u8,

pub fn init(ip: []const u8, mac: []const u8) Pair {
    return Pair{
        .ip = ip,
        .mac = mac,
    };
}

pub fn mac_to_bytes(self: Pair) []const u8 {
    var bytes: [6]u8 = undefined;
    @memcpy(bytes[0..], self.mac[0..6]);
    return bytes[0..];
}
