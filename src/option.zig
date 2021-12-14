const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const meta = std.meta;
const builtin = std.builtin;
const Comparable = @import("comparable.zig");
const option = @This();
/// some type that is a liite bit like rust's optional type
/// I do this just to get rid of if(something != null)
/// and don't want to see some error messages like
/// xxx type not supported member access because is a optional
/// sometime I just want to .expect("get a null xxx");
/// if you like to handle null by you self
/// and you know every optional value's ownership
/// you can skip this type and use the zig original optional type
/// this type is experimental and may contains some bugs
/// help me to make it better!
/// not having unwrap_unchecked
/// just because every unwrap operations here are unchecked
/// no as_pin_ref or as_pin_mut
/// cause zig's async runtime is not the same
/// no ok_or or ok_or_else or some other thing to converts to Result type
pub fn Option(comptime T: type) type {
    return struct {
        /// for hidding memory operations
        /// I specified the allocator for this type
        /// in future versions I will implement a general one for this type
        const allocator: *Allocator = std.heap.page_allocator;
        const Self = @This();
        const ComparedResult = Comparable.ComparedResult;
        /// it just wrapping around a optional type
        /// but this memory's ownership is holded by the type
        value: ?*T,
        /// zig's error handling is different
        /// so I put the errors here
        /// also as you can see
        /// this kind of error handling
        /// Result type could not be implemented here
        pub const Error = error{
            UnhandledNullValue,
            MappingWithInvalidFunctionOrNotFunction,
        };
        /// exactly works the same as the outside one
        pub fn Some(value: T) !Option(T) {
            var ptr = try Self.allocator.create(T);
            ptr.* = value;
            return Self{ .value = ptr };
        }
        /// the none value
        /// just a ownership upon null value
        pub const None = Self{ .value = null };
        /// Returns true if the option is a Some value.
        pub fn is_some(self: *Self) bool {
            return !self.is_none();
        }
        /// Returns true if the option is a None value.
        pub fn is_none(self: *Self) bool {
            return self.value == null;
        }
        /// Returns true if the option is a Some value containing the given value.
        pub fn contains(self: *Self, x: *T) bool {
            if (self.is_none()) return false;
            return self.value.?.* == x.*;
        }
        /// this gives only const pointer
        /// exactly like the borrow in rust
        pub fn as_ref(self: *Self) !Option(*const T) {
            if (self.is_none()) return Option(*const T).None;
            return try Option(*const T).Some(&self.value.?.*);
        }
        /// this will give the mutiable pointer to inner value
        /// but because zig does not check multithread safety
        /// this may not works the same as rust's
        pub fn as_mut(self: *Self) !Option(*T) {
            if (self.is_none()) return Option(*T).None;
            return try Option(*T).Some(self.value.?);
        }

        /// Returns the contained Some value, consuming the self value.
        /// PS: this will drop the inner value's memory address
        /// any optional around this type may cause undefined behavior
        pub fn expect(self: *Self, msg: anyerror) !T {
            if (self.is_none()) return msg;
            var res = self.value.?.*;
            self.deinit();
            return res;
        }
        /// Returns the contained Some value, consuming the self value.
        /// Because this function may panic, its use is generally discouraged.
        /// Instead, prefer to use pattern matching and handle the None case explicitly,
        /// or call unwrap_or, unwrap_or_else, or unwrap_or_default.
        /// PS: this will drop the inner value's memory address
        /// any optional around this type may cause undefined behavior
        pub fn unwrap(self: *Self) !T {
            return self.expect(Self.Error.UnhandledNullValue);
        }
        /// Returns the contained Some value or a provided default.
        /// Arguments passed to unwrap_or are eagerly evaluated;
        /// if you are passing the result of a function call,
        /// it is recommended to use unwrap_or_else, which is lazily evaluated.
        /// PS: this will drop the inner value's memory address
        /// any optional around this type may cause undefined behavior
        pub fn unwrap_or(self: *Self, default: T) T {
            if (self.is_none()) return default;
            var res = self.value.?.*;
            self.deinit();
            return res;
        }
        /// Returns the contained Some value or computes it from a function.
        /// zig not having closure right now, but we can use function pointer
        /// it should works the same but just a little waste of memory
        /// PS: this will drop the inner value's memory address
        /// any optional around this type may cause undefined behavior
        pub fn unwrap_or_else(self: *Self, f: fn () T) T {
            if (self.is_none()) return f();
            var res = self.value.?.*;
            self.deinit();
            return res;
        }

        /// Maps an Option<T> to Option<U> by applying a function to a contained value.
        /// this really takes a litte bit time to found implementation for this
        /// it may not looks like a right implementation
        /// but it works kind well
        /// this operation will not change anything inside this type
        /// the function gives here also not have the chance to change the inner value
        /// even when it can, the value it got is a temporary value
        pub fn map(self: *Self, f: anytype) !Option(@typeInfo(@TypeOf(f)).Fn.return_type.?) {
            if (@typeInfo(@TypeOf(f)).Fn.args.len == 1) {
                if (self.is_none()) return Self.Error.UnhandledNullValue;
                var value_cloned = try Self.allocator.create(T);
                value_cloned.* = self.value.?.*;
                var output = f(value_cloned.*);
                var res = try Option(@TypeOf(output)).Some(output);
                Self.allocator.destroy(value_cloned);
                return res;
            } else {
                return Self.Error.MappingWithInvalidFunctionOrNotFunction;
            }
        }
        /// Returns the provided default result (if none),
        /// or applies a function to the contained value (if any).
        /// Arguments passed to map_or are eagerly evaluated;
        /// if you are passing the result of a function call,
        /// it is recommended to use map_or_else, which is lazily evaluated.
        /// same rule as the map one
        pub fn map_or(self: *Self, f: anytype, default: @typeInfo(@TypeOf(f)).Fn.return_type.?) !@typeInfo(@TypeOf(f)).Fn.return_type.? {
            if (self.is_none()) return default;
            return (try self.map(f)).unwrap();
        }
        /// Computes a default function result (if none),
        /// or applies a different function to the contained value (if any).
        /// also the same rule as the map one
        pub fn map_or_else(self: *Self, f: anytype, default: fn () @typeInfo(@TypeOf(f)).Fn.return_type.?) !@typeInfo(@TypeOf(f)).Fn.return_type.? {
            if (self.is_none()) return default();
            return (try self.map(f)).unwrap();
        }
        /// zig not having auto drop
        /// so we need to drop it ourselves
        pub fn deinit(self: *Self) void {
            if (self.is_some()) Self.allocator.destroy(self.value.?);
        }
        // try to implement a comparable for Option type
        // inner type is must be comparable or implement Comparable
        pub fn cmp(self: *Self, other: Self) Self.ComparedResult {
            if (self.is_none())
                return Self.ComparedResult.Less;

            var value = self.value.?.*;
            var othervalue = other.value.?.*;
            switch (@typeInfo(@TypeOf(value))) {
                .Float, .Int => {
                    if (value == othervalue) return Self.ComparedResult.Equal;
                    if (value < othervalue) return Self.ComparedResult.Less;
                    if (value > othervalue) return Self.ComparedResult.Greater;
                },
                .Struct => {
                    if (@TypeOf(value) == Comparable) {
                        return value.cmp(othervalue);
                    } else {
                        std.log.warn("struct type {s} is not implemented comparable", .{@TypeOf(value)});
                    }
                },
                .Pointer => {
                    var res = std.cstr.cmp(value, othervalue);
                    if(res == 0) return Self.ComparedResult.Equal;
                    if(res == 1) return Self.ComparedResult.Greater;
                    if(res == -1) return Self.ComparedResult.Less;
                },
                else => {
                    std.log.warn("type {s} are not comparable", .{@typeInfo(@TypeOf(value))});
                },
            }
            return Self.ComparedResult.NotComparable;
        }
    };
}
const OptionI32 = Option(i32);

test "Some and None" {
    var i: i32 = 2;
    var a = try OptionI32.Some(i);
    a = OptionI32.None;
}
test "is_some and is_none" {
    var i: i32 = 2;
    var a = try OptionI32.Some(i);
    try testing.expect(a.is_some());
    defer a.deinit();
    a = OptionI32.None;
    try testing.expect(a.is_none());
}
test "contains" {
    var i: i32 = 2;
    var j: i32 = 2;
    var a = try OptionI32.Some(i);
    defer a.deinit();
    try testing.expect(a.contains(&j));
    a = OptionI32.None;
    try testing.expect(!a.contains(&j));
}

test "as_ref" {
    var i: i32 = 2;
    var a = try OptionI32.Some(i);
    defer a.deinit();
    var b = try (try a.as_ref()).unwrap();
    try testing.expect(b.* == 2);
}

test "as_mut" {
    var i: i32 = 2;
    var a = try OptionI32.Some(i);
    defer a.deinit();
    var b = try (try a.as_mut()).unwrap();
    b.* = 3;
    var c = try (try a.as_ref()).unwrap();
    try testing.expect(c.* == 3);
}
fn ff() *const i32 {
    var res: i32 = 2;
    return &res;
}
test "unwraps" {
    var i: i32 = 2;
    var a = OptionI32.None;
    defer a.deinit();
    var b = (try a.as_ref()).unwrap_or(&i);
    try testing.expect(b.* == i);
    var c = (try a.as_ref()).unwrap_or_else(ff);
    try testing.expect(c.* == 2);
}
fn defaultF() i32 {
    var res: i32 = 2;
    return res;
}
fn mapping(input: i32) i32 {
    return input + 1;
}
test "maps" {
    var i: i32 = 2;
    var a = try OptionI32.Some(i);
    var b = try a.map(mapping);
    try testing.expect((try b.unwrap()) == i + 1);
    a.deinit();
    a = OptionI32.None;
    var c = try a.map_or(mapping, i);
    try testing.expect(c == i);
    var d = OptionI32.None;
    var e = try d.map_or_else(mapping, defaultF);
    try testing.expect(e == i);
}
