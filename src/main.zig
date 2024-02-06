const std = @import("std");
const Sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Game = struct {
    bar: Bar,
    ball: Ball,
    options: Options,
    state: State,
    renderer: *Sdl.SDL_Renderer,

    const State = struct {
        running: bool,
        started: bool,
        bricks: std.ArrayList(Brick),

        pub fn init() !State {
            const num = @divTrunc(Options.default_width, Brick.default_width + Brick.default_padding);

            var bricklist = std.ArrayList(Brick).init(std.heap.page_allocator);
            try bricklist.ensureTotalCapacity(num);

            const rows = 3;
            std.log.debug("Initializing {d} bricks\n", .{num * rows});
            var posY: u32 = Brick.default_padding;
            var posX: u32 = Brick.default_padding;
            for (0..rows) |_| {
                for (0..num) |_| {
                    try bricklist.append(Brick.init(posX, posY));
                    posX += Brick.default_width + Brick.default_padding;
                }

                posY += Brick.default_height + Brick.default_padding;
                posX = Brick.default_padding;
            }

            return .{
                .running = true,
                .started = false,
                .bricks = bricklist,
            };
        }
    };

    const Options = struct {
        width: i32,
        height: i32,
        target_fps: u32,

        const default_width = 800;
        const default_height = 600;
        const default_target_fps = 60;

        pub fn init() Options {
            return .{
                .width = Options.default_width,
                .height = Options.default_height,
                .target_fps = Options.default_target_fps,
            };
        }
    };

    const Bar = struct {
        rect: Sdl.SDL_Rect,
        dx: i32,
        v: i32,

        const default_height = 20;
        const default_width = 100;
        const default_velocity = 5;

        pub fn init() Bar {
            return .{
                .rect = Sdl.SDL_Rect{
                    .x = Options.default_width / 2 - Bar.default_width / 2,
                    .y = Options.default_height - 50,
                    .w = Bar.default_width,
                    .h = Bar.default_height,
                },
                .dx = 0,
                .v = Bar.default_velocity,
            };
        }
    };

    const Ball = struct {
        rect: Sdl.SDL_Rect,
        dx: i32,
        dy: i32,
        v: i32,

        const default_size = 10;
        const default_velocity = 5;

        pub fn init(x: i32, y: i32) Ball {
            return .{
                .rect = Sdl.SDL_Rect{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .w = Ball.default_size,
                    .h = Ball.default_size,
                },
                .dx = 0,
                .dy = 0,
                .v = Ball.default_velocity,
            };
        }
    };

    const Brick = struct {
        color: Sdl.SDL_Color,
        rect: Sdl.SDL_Rect,
        alive: bool,

        const default_width = 50;
        const default_height = 20;
        const default_padding = 10;

        pub fn init(x: u32, y: u32) Brick {
            return .{
                .color = Sdl.SDL_Color{ .r = 0, .g = 0xff, .b = 0xff, .a = 0 },
                .rect = Sdl.SDL_Rect{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .w = Brick.default_width,
                    .h = Brick.default_height,
                },
                .alive = true,
            };
        }
    };

    pub fn init() !Game {
        if (Sdl.SDL_Init(Sdl.SDL_INIT_VIDEO) < 0) {
            return error.SdlInitError;
        }

        const window = Sdl.SDL_CreateWindow("Zig Brick Breaker", 0, 0, Options.default_width, Options.default_height, 0) orelse {
            return error.SdlInitError;
        };

        const renderer = Sdl.SDL_CreateRenderer(window, -1, Sdl.SDL_RENDERER_ACCELERATED) orelse {
            return error.SdlInitError;
        };

        const options = Options.init();

        const bar = Bar.init();

        const x: i32 = @intCast(bar.rect.x);
        const y: i32 = @intCast(bar.rect.y);
        const w: i32 = @intCast(bar.rect.w);

        return .{
            .bar = bar,
            .ball = Ball.init(x + @divTrunc(w, 2) - @divTrunc(Ball.default_size, 2), y - Ball.default_size),
            .options = options,
            .state = try State.init(),
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *Game) void {
        const window = Sdl.SDL_RenderGetWindow(self.renderer);

        Sdl.SDL_DestroyRenderer(self.renderer);
        Sdl.SDL_DestroyWindow(window);
        Sdl.SDL_Quit();
    }

    pub fn handleInput(self: *Game) void {
        const keys = Sdl.SDL_GetKeyboardState(null);

        // Determine the bar's direction
        self.bar.dx = 0;
        if (keys[Sdl.SDL_SCANCODE_A] == 1) {
            self.bar.dx += -1;
        }
        if (keys[Sdl.SDL_SCANCODE_D] == 1) {
            self.bar.dx += 1;
        }

        if (self.bar.dx != 0 and !self.state.started) {
            self.ball.dy = -1;
            self.ball.dx = self.bar.dx;
            self.state.started = true;
        }
    }

    pub fn update(self: *Game, delta_time: u32) void {
        const dt_int: i32 = @intCast(delta_time);

        var event: Sdl.SDL_Event = undefined;
        while (Sdl.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                Sdl.SDL_QUIT => self.state.running = false,
                else => {},
            }
        }

        // Move the bar
        self.bar.rect.x += @divTrunc(self.bar.dx * self.bar.v * dt_int, dt_int);

        // Make sure the bar doesn't leave the screen
        self.bar.rect.x = std.math.clamp(self.bar.rect.x, 0, self.options.width - self.bar.rect.w);

        // Move the ball
        self.ball.rect.x += @divTrunc(self.ball.dx * self.ball.v * dt_int, dt_int);
        self.ball.rect.y += @divTrunc(self.ball.dy * self.ball.v * dt_int, dt_int);

        // Make sure the ball doesn't leave the screen
        self.ball.rect.x = std.math.clamp(self.ball.rect.x, 0, self.options.width - self.ball.rect.w);
        self.ball.rect.y = std.math.clamp(self.ball.rect.y, 0, self.options.width - self.ball.rect.h);

        // Bounce the ball off the wall
        if (self.ball.rect.x == self.options.width - self.ball.rect.w or self.ball.rect.x == 0) {
            self.ball.dx *= -1;
        }
        if (self.ball.rect.y == self.options.height - self.ball.rect.h or self.ball.rect.y == 0) {
            self.ball.dy *= -1;
        }

        // TODO: Fix horizontal collision bug
        if (Sdl.SDL_HasIntersection(&self.bar.rect, &self.ball.rect) == 1) {
            self.ball.dy *= -1;
        }

        for (0..self.state.bricks.items.len, self.state.bricks.items) |i, *brick| {
            if (!brick.alive) {
                continue;
            }

            if (Sdl.SDL_HasIntersection(&self.ball.rect, &brick.rect) == 1) {
                std.log.debug("brick {d} is dead\n", .{i});
                brick.*.alive = false;
                self.ball.dy *= -1;
            }
        }
    }

    pub fn render(self: Game) void {
        _ = Sdl.SDL_SetRenderDrawColor(self.renderer, 0x28, 0x28, 0x28, 0);
        _ = Sdl.SDL_RenderClear(self.renderer);

        // Draw the bar
        _ = Sdl.SDL_SetRenderDrawColor(self.renderer, 0xcc, 0x24, 0x1c, 0);
        _ = Sdl.SDL_RenderFillRect(self.renderer, &self.bar.rect);

        // Draw the ball
        _ = Sdl.SDL_SetRenderDrawColor(self.renderer, 0xff, 0xff, 0xff, 0);
        _ = Sdl.SDL_RenderFillRect(self.renderer, &self.ball.rect);

        // Draw the bricks
        for (self.state.bricks.items) |brick| {
            if (!brick.alive) {
                continue;
            }

            _ = Sdl.SDL_SetRenderDrawColor(self.renderer, brick.color.r, brick.color.g, brick.color.b, brick.color.a);
            _ = Sdl.SDL_RenderFillRect(self.renderer, &brick.rect);
        }

        Sdl.SDL_RenderPresent(self.renderer);
    }
};

pub fn main() !void {
    var game = try Game.init();
    defer game.deinit();

    while (game.state.running) {
        const delta_time: u32 = @divTrunc(1000, game.options.target_fps);
        Sdl.SDL_Delay(delta_time);

        game.handleInput();

        game.update(delta_time);

        game.render();
    }
}
