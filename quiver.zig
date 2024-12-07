const std = @import("std");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const Dict = std.StringHashMap;

const Str = []const u8;

pub fn Vertex(comptime T: type) type {
    return struct {
        value: T,
        repr: Str,
        incoming: List(*Edge(T)),
        outgoing: List(*Edge(T)),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator, value: T, repr: Str) !@This() {
            return @This() {
                .value = value,
                .repr = repr,
                .allocator = allocator,
                .incoming = List(*Edge(T)).init(allocator.*),
                .outgoing = List(*Edge(T)).init(allocator.*),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.incoming.deinit();
            self.outgoing.deinit();
        }

        pub fn print(self: *@This()) void {
            std.debug.print("Vertex: {s}", .{self.repr});
            std.debug.print("\n", .{});
        }

        pub fn relations(self: *@This()) void {
            std.debug.print("Vertex: {s}\n", .{self.repr});
            for (self.outgoing.items) |relation| {
                std.debug.print("-> {s}, {s}\n", .{relation.to.repr, relation.label});
            }
        }

        pub fn removeEdge(self: *@This(), edge: *Edge(T)) !void {
            var temp_list_in = List(*Edge(T)).init(self.allocator.*);
            var temp_list_out = List(*Edge(T)).init(self.allocator.*);

            for(self.incoming.items) |e| {
                if (e != edge) {
                    try temp_list_in.append(e);
                }
            }

            for (self.outgoing.items) |e| {
                if(e != edge) {
                    try temp_list_out.append(e);
                }
            }

            self.incoming.deinit();
            self.outgoing.deinit();
            self.incoming = temp_list_in;
            self.outgoing = temp_list_out;
        }
    };
}


pub fn Edge(comptime T: type) type {
    return struct {
        from: *Vertex(T),
        to: *Vertex(T),
        label: Str,

        pub fn init(allocator: *std.mem.Allocator, from: *Vertex(T), to: *Vertex(T), label: Str) !@This() {
            return @This(){ 
                .from = from,
                .to = to,
                .label = try allocator.dupe(u8, label),
            };
        }

        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            var from_index: usize = 0;
            for (self.from.*.outgoing.items) |e| {
                if (e == self) {
                    break;
                }
                from_index += 1;
            }
            _ = self.from.*.outgoing.swapRemove(from_index);

            var to_index: usize = 0;
            for (self.to.*.incoming.items) |e| {
                if (e == self) {
                    break;
                }
                to_index += 1;
            }
            _ = self.to.*.incoming.swapRemove(to_index);

            allocator.free(self.label);
        }

        pub fn print(self: *@This()) void {
            std.debug.print("Edge from: {s} to: {s}, label: {s}", .{self.from.repr, self.to.repr, self.label});
            std.debug.print("\n", .{});
        }
    };
}

pub fn Quiver(comptime T: type) type {
    return struct {
        const Self = @This();
        
        verticies: Map(*Vertex(T), u8),
        edges: List(*Edge(T)),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .verticies = Map(*Vertex(T), u8).init(allocator.*),
                .edges = List(*Edge(T)).init(allocator.*),
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.edges.items) |e| {
                e.deinit(self.allocator);
                self.allocator.destroy(e);
            }
            var it = self.verticies.iterator();
            while (it.next()) |v| {
                const vertex = v.key_ptr.*;
                vertex.deinit();
                self.allocator.destroy(vertex);
            }
            self.verticies.deinit();
            self.edges.deinit();
        }

        pub fn print(self: *Self) void {
            var it = self.verticies.iterator();
            while (it.next()) |v| {
                const x = v.key_ptr.*.repr;
                std.debug.print("Vertex: {s}\n", .{x});
                if (v.key_ptr.*.incoming.items.len > 0) {
                    for (v.key_ptr.*.incoming.items) |in_e| {
                        std.debug.print("->in: {s}\n", .{in_e.from.repr});
                    }
                }
                if (v.key_ptr.*.outgoing.items.len > 0) {
                    for (v.key_ptr.*.outgoing.items) |out_e| {
                        std.debug.print("->out: {s}\n", .{out_e.to.repr});
                    }
                }
            }
            std.debug.print("\n", .{});
        }

        pub fn printV(self: *Self) void {
            var it = self.verticies.iterator();
            std.debug.print("Verticies: \n", .{});
            while (it.next()) |v| {
                std.debug.print("-> {s}\n", .{v.key_ptr.*.repr});
            }
            std.debug.print("\n", .{});
        }

        pub fn printE(self: *Self) void {
            std.debug.print("Edges: \n", .{});
            if (self.edges.items.len > 0) {
                for (self.edges.items) |e| {
                    std.debug.print("-> {s}\n", .{e.label});
                }
            }
            std.debug.print("\n", .{});
        }

        pub fn addVertex(self: *Self, value: T, repr: Str, opt: u8) !*Vertex(T) {
            const vertex = try self.allocator.create(Vertex(T));
            vertex.* = try Vertex(T).init(self.allocator, value, repr);
            try self.verticies.put(vertex, opt);
            return vertex;
        }

        pub fn removeVertex(self: *Self, vertex: *Vertex(T)) !void {
            var it = self.verticies.iterator();
            var temp_map = Map(*Vertex((T)), u8).init(self.allocator.*);
            while(it.next()) |v| {
                if (v.key_ptr.* != vertex) {
                    try temp_map.put(v.key_ptr.*, v.value_ptr.*);
                }
            }
            self.verticies.deinit();
            self.verticies = temp_map;
            var index: usize = 0;
            while (index < self.edges.items.len) {
                const edge = self.edges.items[index];
                if (vertex == edge.to or vertex == edge.from) {
                    edge.deinit(self.allocator);
                    self.allocator.destroy(edge);
                    _ = self.edges.orderedRemove(index);
                } else {
                    index += 1;
                }
            }


            vertex.deinit();
            self.allocator.destroy(vertex);
        }

        pub fn removeEdge(self: *Self, edge: *Edge(T)) !void {
            var index: usize = 0;
            while(index < self.edges.items.len) {
                const e = self.edges.items[index];
                if (e == edge) {
                    _ = self.edges.swapRemove(index);
                } else {
                    index += 1;
                }
            }

            edge.deinit(self.allocator);
            self.allocator.destroy(edge);
        }

        pub fn removeEdgeByLabel(self: *Self, edge_label: Str) !void {
            var edge_to_remove: *Edge(T) = undefined;
            for (self.edges.items) |e| {
                if (std.mem.eql(u8, e.label, edge_label)) {
                    edge_to_remove = e;
                }
            }
            try self.removeEdge(edge_to_remove);
        }

        pub fn addEdge(self: *Self, from: *Vertex(T), to: *Vertex(T), label: Str) !*Edge(T) {
            const edge: *Edge(T) = try self.allocator.create(Edge(T));
            edge.* = try Edge(T).init(self.allocator, from, to, label);
            try self.edges.append(edge);
            try from.outgoing.append(edge);
            try to.incoming.append(edge);
            return edge;
        }
    };
}

pub fn Person() type {
    return struct {
        name: Str,
        age: u8,
        family: List(*Person()),

        pub fn init(name: Str, age: u8, allocator: std.mem.Allocator) @This() {
            return @This(){
                .name = name,
                .age = age,
                .family = List(*Person()).init(allocator),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.family.deinit();
        }

        pub fn addFamilyMemeber(self: *@This(), person: *Person) void {
            self.family.append(person);
        }

        pub fn removeFamilyMember(self: *@This(), person: *Person) void {
            var index: usize = 0;
            for (self.family.items) |p| {
                if (p == person) {
                    break;
                }
                index += 1;
            }
            _ = self.family.swapRemove(index);
            person.deinit();
        }
    };
}

test "Basic Impl" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();
    var q = Quiver(Str).init(&ally);
    defer q.deinit();

    const opt: u8 = 0;

    const v1: *Vertex(Str) = try q.addVertex("A","A", opt);
    v1.print();
    const v2: *Vertex(Str) = try q.addVertex("B","B", opt);
    v2.print();
    const v3: *Vertex(Str) = try q.addVertex("C","C", opt);
    v3.print();

    q.printV();

    const e1_2: *Edge(Str) = try q.addEdge(v1, v2, "Edge AB");
    e1_2.print();
    const e2_3: *Edge(Str) = try q.addEdge(v2, v3, "Edge BC");
    e2_3.print();
    const e3_1: *Edge(Str) = try q.addEdge(v3, v1, "Edge CA");
    e3_1.print();
    const e1_3: *Edge(Str) = try q.addEdge(v1, v3, "Edge AC");
    e1_3.print();
    const e1_1: *Edge(Str) = try q.addEdge(v1, v1, "Edge AA");
    e1_1.print();
    const e2_2: *Edge(Str) = try q.addEdge(v2, v2, "Edge BB");
    e2_2.print();
    const e2_1: *Edge(Str) = try q.addEdge(v2, v1, "Edge BA");
    e2_1.print();
    const e3_2: *Edge(Str) = try q.addEdge(v3, v2, "Edge CB");
    e3_2.print();
    const e3_3: *Edge(Str) = try q.addEdge(v3, v3, "Edge CC");
    e3_3.print();

    q.printV();
    q.printE();

    try q.removeEdge(e1_2);
    try q.removeEdge(e3_3);
    try q.removeEdge(e3_1);

    q.print();

    try q.removeVertex(v3);

    q.print();

    try q.removeVertex(v2);

    q.print();    
}

test "Family" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();

    var jim = Person().init("Jim", 24, ally);
    defer jim.deinit();

    const PersonQuiver = Quiver(Person());

    var q = PersonQuiver.init(&ally);
    defer q.deinit();

    const jim_vertex = try q.addVertex(jim, jim.name, 0);
    
    q.print();

    //Family boom
    var sue = Person().init("Sue", 67, ally);
    var bob = Person().init("Bob", 68, ally);
    var pete = Person().init("Pete", 20, ally);
    var dave = Person().init("Dave", 18, ally);
    var chad = Person().init("Chad", 25, ally);
    var nate = Person().init("Nate", 88, ally);
    var val = Person().init("Val", 24, ally);

    defer sue.deinit();
    defer bob.deinit();
    defer pete.deinit();
    defer dave.deinit();
    defer chad.deinit();
    defer nate.deinit();
    defer val.deinit();

    const sue_v = try q.addVertex(sue, sue.name, 1);
    const bob_v = try q.addVertex(bob, bob.name, 2);
    const pete_v = try q.addVertex(pete, pete.name, 3);
    const dave_v = try q.addVertex(dave, dave.name,4);
    const chad_v = try q.addVertex(chad, chad.name,5);
    const nate_v = try q.addVertex(nate, nate.name, 6);
    const val_v = try q.addVertex(val, val.name, 7);

    q.print();

    _ = try q.addEdge(jim_vertex, sue_v, "Mom");
    _ = try q.addEdge(jim_vertex, bob_v, "Dad");

    _ = try q.addEdge(jim_vertex, pete_v, "First Brother");
    _ = try q.addEdge(jim_vertex, dave_v, "Second Brother");
    _ = try q.addEdge(jim_vertex, chad_v, "Cousin");
    
    _ = try q.addEdge(jim_vertex, nate_v, "Grandfather");
    _ = try q.addEdge(jim_vertex, val_v, "Wife");
    _ = try q.addEdge(jim_vertex, jim_vertex, "Self");

    _ = try q.addEdge(jim_vertex, jim_vertex, "Evil Twin");
    
    q.print();
    jim_vertex.relations();

    try q.removeEdgeByLabel("Evil Twin");
    jim_vertex.relations();

}

test "Family Factory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();

    const PersonQuiver = Quiver(Person());

    var q = PersonQuiver.init(&ally);
    defer q.deinit();

    var jim = Person().init("Jim", 24, ally);
    defer jim.deinit();
    const jim_v = try q.addVertex(jim, jim.name, 0);
    _ = jim_v;

    const family: [7][]const u8 = .{
        "Sue",
        "Bob",
        "Pete",
        "Dave",
        "Nate",
        "Chad",
        "Val",
    };

    const ages: [7]u8 = .{
        47,
        48,
        20,
        18,
        24,
        88,
        25,
    };

    var i: usize = 0;
    while (i < family.len) {

    }
    
    q.print();

}