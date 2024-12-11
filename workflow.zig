const std = @import("std");

const Str = []const u8;

const BoundedArray = std.BoundedArray;
const Map = std.AutoHashMap;

const JiraError = error {
    NoCurrentSprint,
    Overflow,
};

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

const Story = struct {
    name: Str,
    desc: Str,
    priority: Priority,
    progress: Progress,

    task_pool: BoundedArray(*Task, @sizeOf(usize)),
};

const Epic = struct {
    name: Str,
    desc: Str,
    priority: Priority,
    progress: Progress,

    story_pool: BoundedArray(*Story, @sizeOf(usize)),
};

const Backlog = struct {
    epic_pool: BoundedArray(*Epic, @sizeOf(usize)),
};

const Sprint = struct {
    start_date: Str,
    end_date: Str,
    objective: Str,
    task_pool: BoundedArray(*Task, @sizeOf(usize)),
};

pub fn JiraBoard() type {
    return struct {
        const Self = @This();
        allocator: *std.mem.Allocator,

        tasks: BoundedArray(*Task,@sizeOf(usize)),
        stories: BoundedArray(*Story,@sizeOf(usize)),
        epics: BoundedArray(*Epic,@sizeOf(usize)),

        backlog: ?*Backlog,
        current_sprint: ?*Sprint,

        pub fn init(allocator: *std.mem.Allocator) !Self {
            const backlog_ptr = try allocator.create(Backlog);
            backlog_ptr.* = Backlog{
                .epic_pool = try BoundedArray(*Epic, @sizeOf(usize)).init(0),
            };
            const tasks_ptr = try BoundedArray(*Task, @sizeOf(usize)).init(0);
            const stories_ptr = try BoundedArray(*Story, @sizeOf(usize)).init(0);
            const epics_ptr = try BoundedArray(*Epic, @sizeOf(usize)).init(0);

            return Self {
                .allocator = allocator,

                .tasks = tasks_ptr,
                .stories = stories_ptr,
                .epics = epics_ptr,

                .backlog = backlog_ptr,
                .current_sprint = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.backlog) |b| {
                self.allocator.destroy(b);
            }
            if (self.tasks.len > 0) {
                const task_slice = self.tasks.constSlice();
                for (task_slice) |t| {
                    self.allocator.destroy(t);
                }
            }
            if (self.stories.len > 0) {
                const story_slice = self.stories.constSlice();
                for (story_slice) |s| {
                    self.allocator.destroy(s);
                }
            }
            if (self.epics.len > 0) {
                const epic_slice = self.epics.constSlice();
                for (epic_slice) |e| {
                    self.allocator.destroy(e);
                }
            }

            if (self.current_sprint) |s| {
                self.allocator.destroy(s);
            }
        }

        pub fn createTask(self: *Self, name: Str, desc: Str, priority: Priority) !*Task {
            const task_ptr = try self.allocator.create(Task);
            task_ptr.* = Task{
                .name = name,
                .desc = desc,
                .priority = priority,
                .progress = Progress.NOT_STARTED,
            };
            try self.tasks.append(task_ptr);
            return task_ptr;
        }

        pub fn createStory(self: *Self, name: Str, desc: Str, priority: Priority) !*Story {
            const story_ptr = try self.allocator.create(Story);
            story_ptr.* = Story{
                .name = name,
                .desc = desc,
                .priority = priority,
                .progress = Progress.NOT_STARTED,

                .task_pool = try BoundedArray(*Task, @sizeOf(usize)).init(0),
            };
            try self.stories.append(story_ptr);
            return story_ptr;
        }

        pub fn createEpic(self: *Self, name: Str, desc: Str, priority: Priority) !*Epic {
            const epic_ptr = try self.allocator.create(Epic);
            const story_pool_ptr = try BoundedArray(*Story, @sizeOf(usize)).init(0);
            epic_ptr.* = Epic{
                .name = name,
                .desc = desc,
                .priority = priority,
                .progress = Progress.NOT_STARTED,

                .story_pool = story_pool_ptr,
            };
            try self.epics.append(epic_ptr);
            return epic_ptr;
        }

        pub fn removeTask(self: *Self, task: *Task) void {
            if (self.current_sprint) |s| {
                var index: usize = 0;
                const task_slice = s.task_pool.constSlice();
                if (task_slice.len > 0) {
                    for (task_slice) |t| {
                        if (task == t) {
                            break;
                        }
                        index += 1;
                    }
                    _ = s.task_pool.swapRemove(index);
                }
            }
            if (self.tasks.len > 0) {
                const task_slice = self.tasks.constSlice();
                var index: usize = 0;
                for (task_slice) |t| {
                    if(t == task) {
                        break;
                    }
                    index += 1;
                }
                _ = self.tasks.swapRemove(index);
            }

            self.allocator.destroy(task);
        }

        pub fn removeStory(self: *Self, story: *Story) void {
            if (story.task_pool.len > 0) {
                const task_slice = story.task_pool.constSlice();
                for (task_slice) |task| {
                    self.removeTask(task);
                }
            }
            if (self.stories.len > 0) {
                const stories_slice = self.stories.constSlice();
                var index: usize = 0;
                for (stories_slice) |s| {
                    if(s == story) {
                        break;
                    }
                    index += 1;
                }
                _ = self.stories.swapRemove(index);
            }
            self.allocator.destroy(story);
        }

        pub fn removeEpic(self: *Self, epic: *Epic) void {
            if (epic.story_pool.len > 0) {
                const story_slice = epic.story_pool.constSlice();
                for (story_slice) |s| {
                    self.removeStory(s);
                }
            }
            if (self.epics.len > 0) {
                const epics_slice = self.epics.constSlice();
                var index: usize = 0;
                for (epics_slice) |e| {
                    if(e == epic) {
                        break;
                    }
                    index += 1;
                }
                _ = self.epics.swapRemove(index);
            }
            //self.removeEpicFromBacklog(epic);

            self.allocator.destroy(epic);
        }
        
        pub fn addTaskToStory(self: *Self, task: *Task, story: *Story) !void {
            _ = self;
            try story.task_pool.append(task);
        }

        pub fn removeTaskFromStory(self: *Self, task: *Task, story: *Story) !void {
            var index: usize = 0;
            const task_slice = story.task_pool.constSlice();
            for (task_slice) |t| {
                if (t == task) {
                    break;
                }
                index += 1;
            }
            _ = story.task_pool.swapRemove(index);
            self.removeTask(task);
        }

        pub fn addStoryToEpic(self: *Self, story: *Story, epic: *Epic) ! void {
            _ = self;
            try epic.story_pool.append(story);
        }

        pub fn removeStoryFromEpic(self: *Self, story: *Story, epic: *Epic) !void {
            var index: usize = 0;
            const story_slice = epic.story_pool.constSlice();
            for (story_slice) |s| {
                if (s == story) {
                    break;
                }
                index += 1;
            }
            _ = epic.story_pool.swapRemove(index);
            self.removeStory(story);
        }

        pub fn addEpicToBacklog(self: *Self, epic: *Epic) !void {
            if (self.backlog) |b| {
                try b.epic_pool.append(epic);
            }
        }

        pub fn removeEpicFromBacklog(self: *Self, epic: *Epic) void {
            if (self.backlog) |b| {
                var index: usize = 0;
                const epic_slice = b.epic_pool.constSlice();
                for (epic_slice) |e| {
                    if (e == epic) {
                        break;
                    }
                    index += 1;
                }
                _ = b.epic_pool.swapRemove(index);
            }
        }

        pub fn createSprint(self: *Self, start_date: Str, end_date: Str, objective: Str) !void {
            const sprint_ptr = try self.allocator.create(Sprint);
            sprint_ptr.* = Sprint {
                .start_date = start_date,
                .end_date = end_date,
                .objective = objective,

                .task_pool = try BoundedArray(*Task, @sizeOf(usize)).init(0),
            };
            if (self.current_sprint) |s| {
                _ = s;
                self.removeSprint();
            }
            self.current_sprint = sprint_ptr;
        }

        pub fn addTaskToSprint(self: *Self, task: *Task) !void {
            if (self.current_sprint) |s| {
                try s.task_pool.append(task);
            }
        }

        pub fn addStoryToSprint(self: *Self, story: *Story) !void {
            if (self.current_sprint) |s| {
                _ = s;
                const task_slice = story.task_pool.constSlice();
                for (task_slice) |t| {
                    try self.addTaskToSprint(t);
                }
            }
        }

        pub fn removeTaskFromSprint(self: *Self, task: *Task) !void {
            if (self.current_sprint) |s| {
                try s.task_pool.append(task);
            }
        }

        pub fn removeSprint(self: *Self) void {
            if (self.current_sprint) |s| {
                self.allocator.destroy(s);
                self.current_sprint = null;
            }
        }
    };
}

pub fn main() void {
    
}

test "Basic Impl" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer _ = gpa.deinit();

    const JB1 = JiraBoard();
    var JB = try JB1.init(&ally);
    defer JB.deinit();

    try JB.createSprint("Now", "Then", "Everything");

    const Epic1 = try JB.createEpic("Epic 1", "First Epic", Priority.NEUTRAL);
    try JB.addEpicToBacklog(Epic1);
    JB.removeEpicFromBacklog(Epic1);
    
    const Story1 = try JB.createStory("Story 1", "First Story", Priority.HIGH); 
    const Story2 = try JB.createStory("Story 2", "Second Story",Priority.LOW);

    try JB.addStoryToEpic(Story1, Epic1);
    try JB.addStoryToEpic(Story2, Epic1);

    const T1S1 = try JB.createTask("Task 1", "First Task, Story 1", Priority.HIGHER);
    const T2S1 = try JB.createTask("Task 2", "Second Task, Story 1", Priority.HIGHER);
    const T1S2 = try JB.createTask("Task 1", "First Task, Story 2", Priority.HIGHER);
    const T2S2 = try JB.createTask("Task 2", "Second Task, Story 2", Priority.HIGHER);

    try JB.addTaskToStory(T1S1, Story1);
    try JB.addTaskToStory(T2S1, Story1);
    try JB.addTaskToStory(T1S2, Story2);
    try JB.addTaskToStory(T2S2, Story2);

    try JB.addTaskToSprint(T1S1);
    try JB.addStoryToSprint(Story2); 

    try JB.removeTaskFromSprint(T2S2);

}

