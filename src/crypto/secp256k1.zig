const std = @import("std");
const powmod = @import("math.zig").powmod;
const modinv = @import("math.zig").modinv;
const math = @import("std").math;

const PRIME_MODULUS: u256 = @intCast(math.pow(u512, 2, 256) - math.pow(u256, 2, 32) - math.pow(u256, 2, 9) - math.pow(u256, 2, 8) - math.pow(u256, 2, 7) - math.pow(u256, 2, 6) - math.pow(u256, 2, 4) - 1);
pub const NUMBER_OF_POINTS = 115792089237316195423570985008687907852837564279074904382605163141518161494337;
const BASE_POINT = Point{ .x = 55066263022277343669578718895168534326250603453777594175500187360389116729240, .y = 32670510020758816978083085130507043184471273380659243275938904335757337482424 };

pub const Point = struct {
    x: u256,
    y: u256,

    pub fn isEqual(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn double(self: *Point) void {
        // slope = (3x^2 + a) / 2y
        const slope = @mod(((3 * math.pow(i1024, self.x, 2)) * modinv(i1024, 2 * @as(u512, self.y), PRIME_MODULUS)), PRIME_MODULUS);

        const x: u256 = @intCast(@mod(math.pow(i1024, slope, 2) - (2 * @as(u512, self.x)), PRIME_MODULUS));
        const y: u256 = @intCast(@mod(slope * (@as(i512, self.x) - x) - self.y, PRIME_MODULUS));

        self.x = x;
        self.y = y;
    }

    pub fn add(self: *Point, other: Point) void {
        if (self.isEqual(other)) {
            self.double();
        } else {
            const slope = @mod(((@as(i512, self.y) - other.y) * modinv(i1024, @as(i512, self.x) - other.x, PRIME_MODULUS)), PRIME_MODULUS);
            const x: u256 = @intCast(@mod(math.pow(i1024, slope, 2) - self.x - other.x, PRIME_MODULUS));
            const y: u256 = @intCast(@mod((slope * (@as(i512, self.x) - x)) - self.y, PRIME_MODULUS));

            self.x = x;
            self.y = y;
        }
    }

    pub fn multiply(self: *Point, k: u256) void {
        var current = Point{ .x = self.x, .y = self.y };
        // std.math.log2(x) + 1 -> number of bits required to represent k
        // We need to discard the first bit
        // So we loop from 0 to log2(x)
        const bits = std.math.log2_int(u256, k);
        for (0..bits) |i| {
            const y = std.math.shr(u256, k, bits - i - 1) & 1;
            current.double();

            if (y == 1) {
                current.add(self.*);
            }
        }

        self.x = current.x;
        self.y = current.y;
    }

    pub fn fromCompressed(compressed: [33]u8) !Point {
        const parity = std.mem.readInt(u8, compressed[0..1], .big);
        const x = std.mem.readInt(u256, compressed[1..], .big);
        const y_sq = @mod(powmod(x, 3, PRIME_MODULUS) + 7, NUMBER_OF_POINTS);
        var y = powmod(y_sq, (PRIME_MODULUS + 1) / 4, PRIME_MODULUS);
        if (@mod(y, 2) != @mod(parity, 2)) {
            y = @intCast(PRIME_MODULUS - y);
        }
        return Point{ .x = x, .y = y };
    }

    pub fn getBasePoint() Point {
        return Point{ .x = BASE_POINT.x, .y = BASE_POINT.y };
    }
};

test "double" {
    var point = Point{ .x = 100, .y = 100 };
    point.double();
    try std.testing.expectEqual(
        point.x,
        22300,
    );
    try std.testing.expectEqual(
        point.y,
        115792089237316195423570985008687907853269984665640564039457584007908831341563,
    );
}

test "add" {
    var p1 = Point{ .x = 100, .y = 100 };
    var p2 = Point{ .x = 100, .y = 100 };
    p1.add(p2);
    try std.testing.expectEqual(p1.x, 22300);
    try std.testing.expectEqual(p1.y, 115792089237316195423570985008687907853269984665640564039457584007908831341563);

    p1 = Point{ .x = 100, .y = 100 };
    p2 = Point{ .x = 200, .y = 100 };
    p1.add(p2);
    try std.testing.expectEqual(p1.x, 115792089237316195423570985008687907853269984665640564039457584007908834671363);
    try std.testing.expectEqual(p1.y, 115792089237316195423570985008687907853269984665640564039457584007908834671563);
}

test "multiply" {
    var p1 = Point{ .x = 100, .y = 100 };
    p1.multiply(4);
    try std.testing.expectEqual(p1.x, 83958751277781481219825361860495351419593385084310388531537482022592812456470);
    try std.testing.expectEqual(p1.y, 91813336768047772184641076719937475964665959333856505805054708940286741019295);
}

test "uncompress" {
    const buffer = "02aeb803a9ace6dcc5f11d06e8f30e24186c904f463be84f303d15bb7d48d1201f".*;
    const v = try std.fmt.parseInt(u264, &buffer, 16);
    const compressed: [33]u8 = @bitCast(@byteSwap(v));
    const p = try Point.fromCompressed(compressed);
    try std.testing.expectEqual(p.x, 79027560793086286861659885563794118884743103107570705965389288630856279203871);
    try std.testing.expectEqual(p.y, 70098904748994065624629803197701842741428754294763691930704573059552158053128);
}
