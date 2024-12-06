const std = @import("std");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const Dict = std.StringHashMap;


pub fn Vertex(comptime T: type) type {
    return struct {
        value: T,
        incoming: List(*Edge(T)),
        outgoing: List(*Edge(T)),

        pub fn init(allocator: *std.mem.Allocator, value: T) !@This() {
            return @This() {
                .value = value,
                .incoming = List(*Edge(T)).init(allocator),
                .outgoing = List(*Edge(T)).init(allocator),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.incoming.deinit();
            self.outgoing.deinit();
        }
    };
}

pub fn Edge(comptime T: type, comptime edge_mod: type) type {
    return struct {
        from: *Vertex(T),
        to: *Vertex(T),
        label: edge_mod,

        pub fn init(allocator: *std.mem.Allocator, from: *Vertex(T), to: *Vertex(T), label: edge_mod) !@This() {
            return @This(){ 
                .from = from,
                .to = to,
                .label = allocator.create(edge_mod, label)
            };
        }

        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            allocator.destroy(self.label);
        }
    };
}

pub fn Quiver(comptime T: type, comptime edge_mod: type) type {
    return struct {
        const Self = @This();
        
        verticies: Map(*Vertex(T), ?anyopaque),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .verticies = Map(*Vertex(T), null).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.verticies.iterator();
            while (it.next()) |v| {
                v.key_ptr.*.deinit();
                self.allocator.destroy(v.key_ptr);
            }
            self.verticies.deinit();
        }

        pub fn addVertex(self: *Self, value: T, opt: ?anyopaque) !*Vertex(T) {
            const vertex = try self.allocator.create(Vertex(T));
            vertex.* = try Vertex(T).init(self.allocator, value);
            try self.verticies.put(vertex, opt);
            return vertex;
        }

        pub fn addEdge(self: *Self, from: *Vertex(T), to: *Vertex(T), label: edge_mod) !*Edge(T, edge_mod) {
            const edge = try self.allocator.create(Edge(T, @TypeOf(label)));
            edge.* = try Edge(T, @TypeOf(label)).init(self.allocator, from, to, label);
            try from.outgoing.append(edge);
            try to.incoming.append(edge);
            return edge;
        }

        pub fn removeVertex(self: *Self, vertex: *Vertex(T)) void {
            if(self.verticies.remove(vertex)) {
                vertex.deinit();
                self.allocator.destroy(vertex);
            }
        }

        pub fn removeEdge(self: *Self, edge: *Edge(T, edge_mod)) void {
            var it = self.verticies.iterator();
            while(it.next()) |v| {
                var count: usize = 0;
                for (v.key_ptr.*.incoming.items) |edge_in| {
                    if (edge_in == edge) {
                        break;
                    }
                    count += 1;
                }
                v.key_ptr.*.incoming.unorderedRemove(count);
                count = 0;

                for (v.key_ptr.*.outgoing.items) |edge_out| {
                    if (edge_out == edge) {
                        break;
                    }
                    count += 1;
                }
                v.key_ptr.*.outgoing.unorderedRemove(count);
            }
            edge.deinit();
        }

    };
}
