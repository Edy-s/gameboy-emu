package main

gpu_state : struct {
  mode: enum {OAM_SCAN, PRE_DRAW, DRAWING, H_BLANK, RENDER, V_BLANK},
  dot_index: int,
  
  line_objects: [10]Object,
  object_count: int,
  
  pixels: [LCD_HEIGHT][LCD_WIDTH]u8
}
LCD_WIDTH ::  160
LCD_HEIGHT :: 144

init_GPU :: proc() {
  rl.InitWindow(LCD_WIDTH, LCD_HEIGHT, "emulator")
  rl.SetTargetFPS(60)
  target_image   = rl.GenImageColor(LCD_WIDTH, LCD_HEIGHT, rl.WHITE)
  target_texture = rl.LoadTextureFromImage(target_image)
}

target_image: rl.Image
target_texture: rl.Texture2D

Pixel :: bit_field u8 {
  color: u8            | 2,
  palette: u8          | 4,
  sprite_prio: bool    | 1, // used in color gameboy
  backgroud_prio: bool | 1,
}

background_FIFO, object_FIFO: [8]Pixel
bg_FIFO_i, object_FIFO_i: u8
fetcher_x: u8
video_ram := raw_memory_map[rg.VIDEO_RAM_START : rg.VIDEO_RAM_END]

do_GPU_tick :: proc() -> (success: bool) {
  lcd_control = transmute(rg.LCD_Control_Byte)raw_memory_map[rg.LCD_CONTROL]
  current_line := raw_memory_map[rg.LCD_Y_COORD]
  
  switch gpu_state.mode {
  case .OAM_SCAN:
    if gpu_state.dot_index % 2 == 0 && gpu_state.object_count < 10 {
      obj := objects[gpu_state.dot_index % 2]
      
      // if .obj_enable not_in lcd_control { break }
      
      obj_height :u8= (.obj_size in lcd_control) ? 16 : 8
      
      lo_y := obj.pos.y + obj_height
      hi_y := obj.pos.y
      
      if lo_y <= current_line && hi_y > current_line {
        gpu_state.line_objects[gpu_state.object_count] = obj
        gpu_state.object_count += 1
      }
    }
    if gpu_state.dot_index == 79 { gpu_state.mode = .PRE_DRAW }
  
  case .PRE_DRAW:
    if gpu_state.dot_index == 80 {
      get_tile_data(current_line)
      fetcher_x += raw_memory_map[rg.BACKGROUND_X]
    } else if gpu_state.dot_index == 171 {
      gpu_state.mode = .DRAWING
    }
  case .DRAWING:
    if bg_FIFO_i == len(background_FIFO) {
      get_tile_data(current_line)
      bg_FIFO_i = 0
    }
    if fetcher_x < 160 {
      gpu_state.pixels[current_line][fetcher_x] = background_FIFO[bg_FIFO_i].color
      fetcher_x += 1
    }
    if fetcher_x == 160 {
      gpu_state.mode = .H_BLANK
    }
    bg_FIFO_i += 1

  case .H_BLANK:
    if gpu_state.dot_index == 455 {
      fetcher_x = 0
      current_line += 1
      gpu_state.mode = .OAM_SCAN
      if current_line == 143 {
        gpu_state.mode = .RENDER
      }
      gpu_state.dot_index = -1
    }
  case .RENDER:
    rl.BeginDrawing()
    rl.ClearBackground(rl.PINK)
    for px_line, y in gpu_state.pixels {
      for px, x in px_line {
        col := rl.Color{px * 60, px * 60, px * 60, 255}
        rl.ImageDrawPixel(&target_image, auto_cast x, auto_cast y, col)
      }
    }
    rl.UpdateTexture(target_texture, target_image.data)
    rl.DrawTexture(target_texture, 0, 0, rl.WHITE)
    rl.EndDrawing()
    
    gpu_state.mode = .V_BLANK
    fallthrough
  
  case .V_BLANK:
    if gpu_state.dot_index == 455 {
      current_line += 1
      gpu_state.dot_index = -1
    }
    if current_line > 153 {
      current_line = 0
      gpu_state.dot_index = -1
      gpu_state.mode = .OAM_SCAN
    }
      
  }
  
  raw_memory_map[rg.LCD_Y_COORD] = current_line
  gpu_state.dot_index += 1
  return true
}

get_tile_data :: proc(current_line: u8) {
  cam_x := fetcher_x    + raw_memory_map[rg.BACKGROUND_X]
  cam_y := current_line + raw_memory_map[rg.BACKGROUND_Y]
  
  tile_index := u16(cam_x >> 3) | (u16(cam_y >> 3) << 5)
  if .bg_tile_map_area in lcd_control { tile_index += 0x0400 }
  
  tile_address := tile_index | rg.TILE_MAP_OFFSET
  
  tile_data_index := u16(video_ram[tile_address])
  
  tile_data_address := tile_data_index << 4
  tile_data_address |= (u16(cam_y) & 0x7) << 1
  
  if .bg_window_tile_data_area not_in lcd_control { 
    tile_data_address ~= 0x0080
    tile_data_address |= 0x0800
  }
  
  lsb := video_ram[tile_data_address]
  msb := video_ram[tile_data_address+1]
  
  for &pix, i in background_FIFO {
    ui := u8(i)
    bit_mask := u8(0x80 >> ui)
    pix.color = (lsb & bit_mask) >> (7 - ui) | (((msb & bit_mask) >> (7 - ui)) << 1)
  }
}

V2 :: struct {x, y: u8}
Object :: struct {
  pos: V2,
  tile_index: u8,
  flags: bit_field u8 {
    priority: bool    | 1,
    y_flip: bool      | 1,
    x_flip: bool      | 1,
    dmg_palette: bool | 1,
    bank: bool        | 1,
    cbg_palette: u8   | 3
  }
}

objects := mem.slice_data_cast([]Object, raw_memory_map[rg.OAM_START:rg.OAM_END + 1])

gpu_vars : struct {
  bg_viewport: V2,
  window: V2,
  OAM_DMA: ^u8,
}

lcd_control: rg.LCD_Control_Byte


import rg "memory_regions"
import "core:mem"
import rl "vendor:raylib"
