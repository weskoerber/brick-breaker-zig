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

        pub fn init() State {
            return .{
                .running = true,
                .started = false,
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
            .state = State.init(),
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

        if (keys[Sdl.SDL_SCANCODE_SPACE] == 1) {
            self.state.started = true;
            self.ball.dx = 1;
            self.ball.dy = -1;
        }

        if (!self.state.started) {
            return;
        }

        // Determine the bar's direction
        self.bar.dx = 0;
        if (keys[Sdl.SDL_SCANCODE_A] == 1) {
            self.bar.dx += -1;
        }
        if (keys[Sdl.SDL_SCANCODE_D] == 1) {
            self.bar.dx += 1;
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
        std.debug.print("{}\n", .{self.ball});

        if (self.ball.rect.x == self.options.width - self.ball.rect.w or self.ball.rect.x == 0) {
            self.ball.dx *= -1;
        }
        if (self.ball.rect.y == self.options.height - self.ball.rect.h or self.ball.rect.y == 0) {
            self.ball.dy *= -1;
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
