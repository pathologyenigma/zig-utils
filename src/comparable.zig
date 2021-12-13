pub const Comparable = @This();

pub const ComparedResult = enum {
    Greater,
    Equal,
    Less
};

cmp: fn(self: *Comparable, b: Comparable) Comparable.ComparedResult,