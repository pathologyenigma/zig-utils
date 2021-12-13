pub const Comparable = @This();

pub const ComparedResult = enum {
    Greater,
    Equal,
    Less
};

cmp: fn(a:Comparable, b:Comparable) Comparable.ComparedResult,