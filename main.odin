package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

GRID :: 48
CELL :: 15

WINDOW_WIDTH :: GRID * CELL // 720
WINDOW_HEIGHT :: GRID * CELL // 720

main :: proc() {
	default := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default)
	defer mem.tracking_allocator_destroy(&tracking_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer print_memory_usage(&tracking_allocator)

	raycaster: Raycaster
	init_raycaster(&raycaster, "map2.txt", GRID, GRID, CELL, CELL)
	defer delete_raycaster(&raycaster)

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "odinary raycaster")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()

		update(&raycaster, delta)

		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)
		rl.DrawFPS(50, 50)

		draw(&raycaster)

		rl.EndDrawing()
	}
}
