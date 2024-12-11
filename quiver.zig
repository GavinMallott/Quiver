const std = @import("std");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const Dict = std.StringHashMap;
const Queue = std.PriorityQueue;
const Dequeue = std.PriorityDequeue;

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
            std.debug.print("Vertex: {s}\n", .{self.repr});
        }

        pub fn relations(self: *@This()) void {
            std.debug.print("Vertex Relations: {s}\n", .{self.repr});
            for (self.outgoing.items) |relation| {
                std.debug.print("-> {s}, {s}\n", .{relation.to.repr, relation.label});
            }
            std.debug.print("\n", .{});
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

pub fn Quiver(comptime T: type, comptime M: type) type {
    return struct {
        const Self = @This();
        
        verticies: Map(*Vertex(T), M),
        edges: List(*Edge(T)),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .verticies = Map(*Vertex(T), M).init(allocator.*),
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

        pub fn addVertex(self: *Self, value: T, repr: Str, opt: M) !*Vertex(T) {
            const vertex = try self.allocator.create(Vertex(T));
            vertex.* = try Vertex(T).init(self.allocator, value, repr);
            try self.verticies.put(vertex, opt);
            return vertex;
        }

        pub fn removeVertex(self: *Self, vertex: *Vertex(T)) !void {
            var it = self.verticies.iterator();
            var temp_map = Map(*Vertex((T)), M).init(self.allocator.*);
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

        pub fn addEdge(self: *Self, from: *Vertex(T), to: *Vertex(T), label: Str) !*Edge(T) {
            const edge: *Edge(T) = try self.allocator.create(Edge(T));
            edge.* = try Edge(T).init(self.allocator, from, to, label);
            try self.edges.append(edge);
            try from.outgoing.append(edge);
            try to.incoming.append(edge);
            return edge;
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
            var edge_to_remove: ?*Edge(T) = null;
            for (self.edges.items) |e| {
                if (std.mem.eql(u8, e.label, edge_label)) {
                    edge_to_remove = e;
                }
            }
            if (edge_to_remove == null) {
                std.debug.print("Tried to remove edge by label: {s}\nEdge not found.\n", .{edge_label});
            } else {
                try self.removeEdge(edge_to_remove.?);
            }
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
    var q = Quiver(Str, u8).init(&ally);
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

test "State Machine" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();
    var q = Quiver(Str, u8).init(&ally);
    defer q.deinit();

    const opt: u8 = 0;

    const start: *Vertex(Str) = try q.addVertex("StateStart","Start", opt);
    start.print();
    const step: *Vertex(Str) = try q.addVertex("StateStep","Step", opt);
    step.print();
    const wait: *Vertex(Str) = try q.addVertex("StateWait","Wait", opt);
    wait.print();
    const errors: *Vertex(Str) = try q.addVertex("StateError", "Error", opt);
    errors.print();
    const input: *Vertex(Str) = try q.addVertex("StateInput", "Input", opt);
    input.print();
    const end: *Vertex(Str) = try q.addVertex("StateEnd", "End", opt);
    end.print();

    q.printV();

    _ = try q.addEdge(start, wait, "EnterStandby");
    _ = try q.addEdge(input, step, "ProcessInput");
    _ = try q.addEdge(step,wait, "StepComplete");
    _ = try q.addEdge(wait, input, "TakeInput");
    _ = try q.addEdge(input,wait, "Standby");
    _ = try q.addEdge(wait,wait, "Standby");
    _ = try q.addEdge(step, errors, "ProcessError");
    _ = try q.addEdge(errors, wait, "Standby");
    _ = try q.addEdge(input, errors, "ProcessError");
    _ = try q.addEdge(input, end, "FinishExecuting");
    _ = try q.addEdge(step, end, "FinishExecuting");

    q.printV();
    q.printE();
    input.relations();
    q.print();    
}

test "Family" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();

    var jim = Person().init("Jim", 24, ally);
    defer jim.deinit();

    const PersonQuiver = Quiver(Person(), usize);

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

    //Jim's Relationships
    _ = try q.addEdge(jim_vertex, sue_v, "Jim's Mom");
    _ = try q.addEdge(jim_vertex, bob_v, "Jim's Dad");

    _ = try q.addEdge(jim_vertex, pete_v, "Jim's First Brother");
    _ = try q.addEdge(jim_vertex, dave_v, "Jim's Second Brother");
    _ = try q.addEdge(jim_vertex, chad_v, "Jim's Cousin");
    
    _ = try q.addEdge(jim_vertex, nate_v, "Jim's Grandfather");
    _ = try q.addEdge(jim_vertex, val_v, "Jim's Wife");
    _ = try q.addEdge(jim_vertex, jim_vertex, "Jim's Self");

    _ = try q.addEdge(jim_vertex, jim_vertex, "Jim's Evil Twin");
    

    jim_vertex.relations();

    try q.removeEdgeByLabel("xJim's Evil Twin");
    jim_vertex.relations();


    //Sue's Relationships
    _ = try q.addEdge(sue_v, sue_v, "Sue's Self");
    _ = try q.addEdge(sue_v, bob_v, "Sue's Husband");

    _ = try q.addEdge(sue_v, jim_vertex, "Sue's First Son");
    _ = try q.addEdge(sue_v, pete_v, "Sue's Second Son");
    _ = try q.addEdge(sue_v, dave_v, "Sue's Third Son");
    _ = try q.addEdge(sue_v, chad_v, "Sue's Brother's Son");
    
    _ = try q.addEdge(sue_v, nate_v, "Sue's Father-in-law");
    _ = try q.addEdge(sue_v, val_v, "Sue's Daughter-in-law");
    _ = try q.addEdge(sue_v, sue_v, "Sue's Self");

    _ = try q.addEdge(sue_v, sue_v, "Sue's Evil Twin");

    sue_v.relations();

    try q.removeEdgeByLabel("Sue's Evil Twin");
    sue_v.relations();


    //Bob's Relationships
    _ = try q.addEdge(bob_v, sue_v, "Bob's Wife");
    _ = try q.addEdge(bob_v, bob_v, "Bob's Self");

    _ = try q.addEdge(bob_v, jim_vertex, "Bob's First Son");
    _ = try q.addEdge(bob_v, pete_v, "Bob's Second Son");
    _ = try q.addEdge(bob_v, dave_v, "Bob's Third Son");
    _ = try q.addEdge(bob_v, chad_v, "Bob's Brother-in-law's Son");
    
    _ = try q.addEdge(bob_v, nate_v, "Bob's Father");
    _ = try q.addEdge(bob_v, val_v, "Bob's Daughter-in-law");

    _ = try q.addEdge(bob_v, bob_v, "Bob's Evil Twin");

    bob_v.relations();

    try q.removeEdgeByLabel("Bob's Evil Twin");
    bob_v.relations();

    q.print();
}

test "Labeled Machine" {
    const EdgeType = enum(u8) {
        ENTER_STANDBY = 0b00000000,
        PROCESS_INPUT = 0b00000001,
        STEP_COMPLETE = 0b00000010,
        STANDBY = 0b00000100,
        TAKE_INPUT = 0b00001000,
        PROCESS_ERROR = 0b00010000,
        FINISH_EXECUTING = 0b00100000,

        None = 0b11111111,
    };

    const VertexType = enum(u8) {
        START = 0b00000001,
        STEP = 0b00000010,
        WAIT = 0b00000100,
        ERROR = 0b00001000,
        INPUT = 0b00010000,
        END = 0b00100000,

        None = 0b11111111,
    };

    const State = struct {
        state: VertexType,
        edges: u8, 
    };

    const START_STATE = State{
        .state = VertexType.START,
        .edges = @intFromEnum(EdgeType.ENTER_STANDBY),
    };
    const INPUT_STATE = State{
        .state = VertexType.INPUT,
        .edges = @intFromEnum(EdgeType.PROCESS_INPUT) & @intFromEnum(EdgeType.PROCESS_ERROR) & @intFromEnum(EdgeType.FINISH_EXECUTING),
    };
    const WAIT_STATE = State{
        .state = VertexType.WAIT,
        .edges = @intFromEnum(EdgeType.STANDBY) & @intFromEnum(EdgeType.TAKE_INPUT),
    };
    const STEP_STATE = State{
        .state = VertexType.STEP,
        .edges = @intFromEnum(EdgeType.STEP_COMPLETE) & @intFromEnum(EdgeType.PROCESS_ERROR) & @intFromEnum(EdgeType.PROCESS_INPUT) & @intFromEnum(EdgeType.FINISH_EXECUTING),
    };
    const ERROR_STATE = State{
        .state = VertexType.ERROR,
        .edges = @intFromEnum(EdgeType.STANDBY),
    };
    const END_STATE = State{
        .state = VertexType.END,
        .edges = @intFromEnum(EdgeType.None),
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();

    var q = Quiver(State, u8).init(&ally);
    defer q.deinit();

    const start: *Vertex(State) = try q.addVertex(START_STATE, "Start", START_STATE.edges);
    //start.print();
    const step: *Vertex(State) = try q.addVertex(STEP_STATE, "Step", STEP_STATE.edges); 
    //step.print();
    const wait: *Vertex(State) = try q.addVertex(WAIT_STATE, "Wait", WAIT_STATE.edges);
    //wait.print();
    const errors: *Vertex(State) = try q.addVertex(ERROR_STATE, "Error", ERROR_STATE.edges);
    //errors.print();
    const input: *Vertex(State) = try q.addVertex(INPUT_STATE, "Input", INPUT_STATE.edges);
    //input.print();
    const end: *Vertex(State) = try q.addVertex(END_STATE, "End", END_STATE.edges);
    //end.print();

    //q.printV();

    var EdgeLabel = Map(EdgeType, Str).init(ally);
    defer EdgeLabel.deinit();
    try EdgeLabel.put(EdgeType.ENTER_STANDBY, "Enter Standby");
    try EdgeLabel.put(EdgeType.PROCESS_INPUT, "Process Input");
    try EdgeLabel.put(EdgeType.STEP_COMPLETE, "Step Complete");
    try EdgeLabel.put(EdgeType.TAKE_INPUT, "Take Input");
    try EdgeLabel.put(EdgeType.STANDBY, "Standby");
    try EdgeLabel.put(EdgeType.PROCESS_ERROR, "Process Error");
    try EdgeLabel.put(EdgeType.FINISH_EXECUTING, "Finish Executing");

    _ = try q.addEdge(start, wait, EdgeLabel.get(EdgeType.ENTER_STANDBY).?);
    _ = try q.addEdge(input, step, EdgeLabel.get(EdgeType.PROCESS_INPUT).?);
    _ = try q.addEdge(step,wait, EdgeLabel.get(EdgeType.STEP_COMPLETE).?);
    _ = try q.addEdge(wait, input, EdgeLabel.get(EdgeType.TAKE_INPUT).?);
    _ = try q.addEdge(input,wait, EdgeLabel.get(EdgeType.STANDBY).?);
    _ = try q.addEdge(wait,wait,  EdgeLabel.get(EdgeType.STANDBY).?);
    _ = try q.addEdge(step, errors, EdgeLabel.get(EdgeType.PROCESS_ERROR).?);
    _ = try q.addEdge(errors, wait, EdgeLabel.get(EdgeType.STANDBY).?);
    _ = try q.addEdge(input, errors, EdgeLabel.get(EdgeType.PROCESS_ERROR).?);
    _ = try q.addEdge(input, end, EdgeLabel.get(EdgeType.FINISH_EXECUTING).?);
    _ = try q.addEdge(step, end, EdgeLabel.get(EdgeType.FINISH_EXECUTING).?);

    q.printV();
    q.printE();
    input.relations();
    q.print();    

}

test "Workflow" {
    const Priority = enum(u3) {
        LOWEST = 0,     //0b000
        LOWER = 1,      //0b001
        LOW = 2,        //0b010
        NEUTRAL = 3,    //0b011
        HIGH = 4,       //0b100
        HIGHER = 5,     //0b101
        HIGHEST = 6,    //0b110
        MANUAL = 7,     //0b111
    };

    const Progress = enum(u2) {
        NOT_STARTED = 0b00,
        IN_PROGRESS = 0b01,
        ON_HOLD = 0b10,
        DONE = 0b11,
    };

    const Task = struct {
        name: Str,
        desc: Str,
        priority: Priority,
        progress: Progress,
    };

    const Sequence = struct {
        name: Str,
        desc: Str,
        priority: Priority,
        progress: Progress,

        task_next: ?*Task,
    };

    const Story = struct {
        name: Str,
        desc: Str,
        priority: Priority,
        progress: Progress,

        task_pool: []*Task,
    };

    const Epic = struct {
        name: Str,
        desc: Str,
        priority: Priority,
        progress: Progress,

        sequence_pool: []*Sequence,
        story_pool: []*Story,
    };

    const Backlog = struct {
        epic_pool: []*Epic,
    };

    const Sprint = struct {
        task_pool: []*Task,
    };

    const JiraBoard = struct {
        allocator: *std.mem.allocator,
        backlog: *Backlog,
        current_sprint: *Sprint,
    };
}
