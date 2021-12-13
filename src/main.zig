pub const Option = @import("option.zig").Option;
pub const Comparable = @import("comparable.zig");
// only some function is available
// None need to be known the reciever's type
// which is not clear at comptime
// Rust got None because of it's compiler
// But you could still get None type from one of the Option type
pub fn Some(value: anytype) !Option(@TypeOf(value)) {
    return Option(@TypeOf(value)).Some(value);
}
pub const utils = @This();