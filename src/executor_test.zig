const std = @import("std");
const builtin = @import("builtin");
const executor = @import("executor.zig");

fn skipWindows() bool {
    return builtin.os.tag == .windows;
}

test "run captures stdout" {
    const r = try executor.exec(
        &.{ "echo", "hello" },
        std.testing.allocator,
        .filter_stdout_only,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expectEqualStrings("hello\n", r.stdout);
    try std.testing.expectEqual(@as(u8, 0), r.exit_code);
}

test "run captures stderr (filter_stdout_only)" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "echo err >&2" },
        std.testing.allocator,
        .filter_stdout_only,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expect(std.mem.indexOf(u8, r.stderr, "err") != null);
}

test "filter_stderr_only swaps streams" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "echo out; echo err >&2" },
        std.testing.allocator,
        .filter_stderr_only,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expect(std.mem.indexOf(u8, r.stdout, "err") != null);
    try std.testing.expect(std.mem.indexOf(u8, r.stderr, "out") != null);
}

test "merge_then_filter concatenates streams" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "echo out; echo err >&2" },
        std.testing.allocator,
        .merge_then_filter,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expect(std.mem.indexOf(u8, r.stdout, "out") != null);
    try std.testing.expect(std.mem.indexOf(u8, r.stdout, "err") != null);
}

test "run preserves nonzero exit code" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "exit 42" },
        std.testing.allocator,
        .filter_both,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expectEqual(@as(u8, 42), r.exit_code);
}

test "run handles sizeable output without crashing" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "yes | head -n 100000" },
        std.testing.allocator,
        .filter_stdout_only,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expectEqual(@as(u8, 0), r.exit_code);
    try std.testing.expect(r.stdout.len > 0);
}

test "run returns sentinel when stdout exceeds cap" {
    if (skipWindows()) return;
    const r = try executor.exec(
        &.{ "sh", "-c", "head -c 17825792 /dev/zero | tr '\\0' 'a'" },
        std.testing.allocator,
        .filter_stdout_only,
    );
    defer std.testing.allocator.free(r.stdout);
    defer std.testing.allocator.free(r.stderr);
    try std.testing.expect(std.mem.indexOf(u8, r.stdout, "16MB cap") != null);
}
