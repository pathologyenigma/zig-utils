pub const Comparable = @This();

pub const ComparedResult = enum {
    Greater,
    Equal,
    Less,
    NotComparable
};

cmp: fn(self: *Comparable, b: Comparable) Comparable.ComparedResult,