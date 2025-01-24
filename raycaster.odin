package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

WALL_SCALAR :: 2

RaycasterPlayer :: struct {
	pos: rl.Vector2,
	dir: rl.Vector2,
	cam: rl.Vector2,
}

Raycaster :: struct {
	player: RaycasterPlayer,
	gw, gh: int,
	cw, ch: f32,
	mmap:   []int,
}

init_raycaster :: proc(rc: ^Raycaster, mapname: string, gw, gh: int, cw, ch: f32) {

	rc.gw = gw
	rc.gh = gh
	rc.cw = cw
	rc.ch = ch

	rc.player = {
		pos = {11.2, 12.3},
		dir = {-1, 0},
		cam = {0, 0.66},
	}

	err := load_map(rc, mapname)
	assert(err == nil)
	assert(len(rc.mmap) == int(gw * gh))
}

delete_raycaster :: proc(rc: ^Raycaster) {
	delete(rc.mmap)
}

// Draws a vertical slice at the x column, with h  total height. 
// The rectangle will be y-centered on the screen.
draw_slice :: proc(rc: ^Raycaster, x: int, h: f32, color: rl.Color) {
	wh := f32(rc.gh) * rc.ch
	start := rl.Vector2{f32(x) * rc.cw, wh / 2 - h / 2}
	start.y = start.y < 0 ? 0 : start.y
	size := rl.Vector2{rc.cw, h}
	size.y = size.y + start.y >= wh ? wh - start.y : size.y
	rl.DrawRectangleV(start, size, color)
}

draw :: proc(rc: ^Raycaster) {
	//ww := rc.gw * int(rc.cw)
	for x in 0 ..< rc.gw {
		h, c := calc_slice_height(rc, x)
		//fmt.printf("h=%f,c=%v\n", h, c)
		draw_slice(rc, x, h, c)
	}
}

// Uses DDA to calculate height of target slice 
calc_slice_height :: proc(rc: ^Raycaster, x: int) -> (h: f32, c: rl.Color) {
	// ww, wh := f32(rc.gw) * rc.cw, f32(rc.gh) * rc.ch
	p := rc.player

	// camera_x is the proportion of p.cam the ray intersects with 
	// the camera plane. Number between -1 and 1. 
	camera_x := 2 * f32(x) / f32(rc.gw) - 1
	// fmt.printf("Camera_X: %v\n", camera_x)

	// the direction of the current ray
	ray_dir := p.dir + p.cam * camera_x
	//fmt.printf("Raydir: %v\n", ray_dir)

	// the integer x, y position of the player on the grid 
	map_pos := [2]int{int(p.pos.x), int(p.pos.y)}
	//fmt.printf("map_pos: %v\n", map_pos)

	//length of ray from current position to next x or y-side
	side_dist: rl.Vector2

	// The distance between one grid line and the next, in either the x 
	// or y direction. 
	delta_dist := rl.Vector2 {
		math.sqrt(1 + (ray_dir.y * ray_dir.y) / (ray_dir.x * ray_dir.x)),
		math.sqrt(1 + (ray_dir.x * ray_dir.x) / (ray_dir.y * ray_dir.y)),
	}
	// fmt.printf("delta_dist: %v\n", delta_dist)

	// Perpendicular distance from the wall to the p.cam plane.
	perpendicular_dist: f32 = 0

	// The step direction we're heading in, either -1 or 1 for each x and y
	step := [2]int{}

	// Have we hit a wall?
	hit := false

	// Which side of the wall have we hit. 0 for the x-side, 1 for y-side
	side := 0

	// First we figure out the step direction and the initial side_dist. 
	// side_dist is calculated in the associated direction and is initially 
	// the dist from the p.pos to that directions x or y grid line. 
	if ray_dir.x < 0 { 	// We're heading Left 
		step.x = -1
		side_dist.x = (p.pos.x - f32(map_pos.x)) * delta_dist.x
	} else { 	// We're heading Right
		step.x = 1
		side_dist.x = (f32(map_pos.x) + 1 - p.pos.x) * delta_dist.x
	}
	if ray_dir.y < 0 { 	// We're heading Up
		step.y = -1
		side_dist.y = (p.pos.y - f32(map_pos.y)) * delta_dist.y
	} else { 	// We're heading Down
		step.y = 1
		side_dist.y = (f32(map_pos.y) + 1 - p.pos.y) * delta_dist.y
	}

	//fmt.printf("Step: %v\n", step)
	//fmt.printf("Before: SideDist: %v\n", side_dist)
	//fmt.printf("Before: Map Pos: %v\n", map_pos)

	// We start stepping
	for !hit {
		if side_dist.x < side_dist.y { 	// Advance to next x line
			side_dist.x += delta_dist.x
			map_pos.x += step.x
			side = 0
		} else { 	// Advance to next y line
			side_dist.y += delta_dist.y
			map_pos.y += step.y
			side = 1
		}

		// fmt.printf("SideDist=%v, MapPos=%v, Side=%d\n", side_dist, map_pos, side)

		// Check to see if we hit a wall
		if rc.mmap[map_pos.y * rc.gw + map_pos.x] > 0 {
			hit = true
		}
	}
	//fmt.printf("After: SideDist: %v\n", side_dist)
	//fmt.printf("After: Map Pos: %v\n", map_pos)
	//fmt.println()

	// Once we've found a wall we can work out the perpendicular_dist. 
	// We have to go back one square to get out of the wall.
	if side == 0 { 	// A x side
		perpendicular_dist = side_dist.x - delta_dist.x
	} else { 	// A y side
		perpendicular_dist = side_dist.y - delta_dist.y
	}
	// fmt.printf("Perpendicular Dist: x=%d, dist=%f\n", x, perpendicular_dist)

	// From the perpendicular_dist we can find the correct height of the wall
	wh := f32(rc.gh) * rc.ch
	h = WALL_SCALAR * wh / perpendicular_dist
	// fmt.printf("h: %v\n", h)

	// And we can choose the color as well 
	switch rc.mmap[map_pos.y * rc.gw + map_pos.x] {
	case 1:
		c = rl.RED
	case 2:
		c = rl.GREEN
	case 3:
		c = rl.BLUE
	case 4:
		c = rl.WHITE
	case:
		c = rl.YELLOW
	}

	// If it's a y side then color it a little less
	if side == 1 do c = c / 2

	return h, c
}

update :: proc(rc: ^Raycaster, delta: f32) {
	move_speed := 5 * delta
	rot_speed := 2 * delta

	if rl.IsKeyDown(.UP) {
		nxt := rc.player.pos + rc.player.dir * move_speed
		if rc.mmap[int(nxt.y) * rc.gw + int(nxt.x)] == 0 {
			rc.player.pos += rc.player.dir * move_speed
		}
	}

	if rl.IsKeyDown(.DOWN) {
		nxt := rc.player.pos - rc.player.dir * move_speed
		if rc.mmap[int(nxt.y) * rc.gw + int(nxt.x)] == 0 {
			rc.player.pos -= rc.player.dir * move_speed
		}
	}

	if rl.IsKeyDown(.RIGHT) {
		old_dir_x := rc.player.dir.x
		rc.player.dir.x =
			rc.player.dir.x * math.cos(-rot_speed) - rc.player.dir.y * math.sin(-rot_speed)
		rc.player.dir.y = old_dir_x * math.sin(-rot_speed) + rc.player.dir.y * math.cos(-rot_speed)

		old_cam_x := rc.player.cam.x
		rc.player.cam.x =
			rc.player.cam.x * math.cos(-rot_speed) - rc.player.cam.y * math.sin(-rot_speed)
		rc.player.cam.y = old_cam_x * math.sin(-rot_speed) + rc.player.cam.y * math.cos(-rot_speed)
	}

	if rl.IsKeyDown(.LEFT) {
		old_dir_x := rc.player.dir.x
		rc.player.dir.x =
			rc.player.dir.x * math.cos(rot_speed) - rc.player.dir.y * math.sin(rot_speed)
		rc.player.dir.y = old_dir_x * math.sin(rot_speed) + rc.player.dir.y * math.cos(rot_speed)

		old_cam_x := rc.player.cam.x
		rc.player.cam.x =
			rc.player.cam.x * math.cos(rot_speed) - rc.player.cam.y * math.sin(rot_speed)
		rc.player.cam.y = old_cam_x * math.sin(rot_speed) + rc.player.cam.y * math.cos(rot_speed)
	}
}

LoadingError :: enum {
	None,
	ZeroLines,
	ZeroCells,
	FileReadError,
	LineSplitError,
	CellSplitError,
	ParseCellError,
}

load_map :: proc(rc: ^Raycaster, path: string) -> LoadingError {

	bmap, bmap_err := os.read_entire_file_or_err(path)
	if bmap_err != nil do return .FileReadError
	smap := string(bmap)
	defer delete(smap)

	lines, line_err := strings.split_lines(smap)
	if line_err != nil do return .LineSplitError
	defer delete(lines)

	lines = lines[0:len(lines) - 1]
	if len(lines) <= 0 do return .ZeroLines

	cells, cells_err := strings.split(lines[0], " ")
	if cells_err != nil do return .CellSplitError
	defer delete(cells)
	if len(cells) <= 0 do return .ZeroCells

	result := make([]int, len(lines) * len(cells))

	for line, i in lines {
		scells, err := strings.split(line, " ")
		if err != nil do return .CellSplitError
		defer delete(scells)
		assert(len(scells) == len(cells))

		for cell, j in scells {
			parsed, ok := strconv.parse_int(cell)
			if !ok do return .ParseCellError
			result[i * rc.gw + j] = parsed
		}
	}

	rc.mmap = result

	return nil
}
