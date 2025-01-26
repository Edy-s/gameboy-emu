package main

gpu_state : struct {
  mode: enum {OAM_SCAN, PRE_DRAW, DRAWING, H_BLANK, RENDER, V_BLANK},
  dot_index: int,
  frame_dot_index: int,
  skip_frame: bool,
  
  drawing_window: bool,
  
  palettes: struct {
    bg, obj0, obj1: u8
  },
  line_objects: [10]Object,
  object_count: int,
  
  pixels: [LCD_HEIGHT][LCD_WIDTH]u8
}

LCD_WIDTH  :: 160
LCD_HEIGHT :: 144

RENDER_MULTIPLE :: 4

init_GPU :: proc() {
  name_from_rom := ROM_header.game_title[:]
  for c, i in name_from_rom {
    if c == 0 {
      name_from_rom = name_from_rom[:i]
      break
    }
  }
  title := fmt.tprintf("GBM Emulator - %v", string(name_from_rom))
  rl.InitWindow(LCD_WIDTH * RENDER_MULTIPLE, LCD_HEIGHT * RENDER_MULTIPLE, strings.clone_to_cstring(title))
  rl.SetTargetFPS(60)
  target_image   = rl.GenImageColor(LCD_WIDTH, LCD_HEIGHT, rl.WHITE)
  target_texture = rl.LoadTextureFromImage(target_image)
  
  assert(len(objects) == 40)
}

target_image:   rl.Image
target_texture: rl.Texture2D

pusher_x: u8
video_ram := raw_memory_map[rg.VIDEO_RAM_START : rg.VIDEO_RAM_END]

do_GPU_tick :: proc() -> (success: bool) {
  current_line := raw_memory_map[rg.LCD_Y_COORD]
  if !gpu_state.skip_frame && .LCD_enable not_in lcd_control { gpu_state.skip_frame = true }
  
  switch gpu_state.mode {
  case .OAM_SCAN:
    if gpu_state.dot_index % 2 == 0 && gpu_state.object_count < 10 {
      obj := objects[gpu_state.dot_index / 2]
      if obj != {} {
        obj_height :u8= (.obj_size in lcd_control) ? 16 : 8
        lo_y := obj.pos.y + obj_height
        hi_y := obj.pos.y
        
        test_line := current_line + 16
        
        if obj.pos.y != 0 && lo_y > test_line && test_line >= hi_y {
          gpu_state.line_objects[gpu_state.object_count] = obj
          gpu_state.object_count += 1
        }
      }
    }
    if gpu_state.dot_index == 79 { gpu_state.mode = .PRE_DRAW }
  
  case .PRE_DRAW:
    if gpu_state.dot_index == 80 {
      gpu_state.palettes.bg   = raw_memory_map[rg.BG_PALETTE]
      gpu_state.palettes.obj0 = raw_memory_map[rg.OBJ_0_PALETTE]
      gpu_state.palettes.obj1 = raw_memory_map[rg.OBJ_1_PALETTE]
      
      pusher_x = 0
      background_FIFO = {}
      object_FIFO = {}
      
      get_tile_data(current_line, gpu_state.drawing_window)
      for _ in 0..<raw_memory_map[rg.BACKGROUND_X] % 8 {
        pop_pixel(&background_FIFO)
      }
    } else if gpu_state.dot_index == 92 {
      gpu_state.mode = .DRAWING
    }
    
  case .DRAWING:
    if !gpu_state.drawing_window && pusher_x + 7 >= raw_memory_map[rg.WINDOW_X] && current_line >= raw_memory_map[rg.WINDOW_Y] {
      background_FIFO.pixels_left = 0
      gpu_state.drawing_window = true
    }
    if background_FIFO.pixels_left == 0 {
      get_tile_data(current_line, gpu_state.drawing_window)
    }
    if pusher_x < 160 && !gpu_state.skip_frame {
      bg_col := pop_pixel(&background_FIFO).color
      
      get_object_data(current_line)
      obj_pix := pop_pixel(&object_FIFO)
      
      obj_palette := obj_pix.palette == 0 ? gpu_state.palettes.obj0 : gpu_state.palettes.obj1
      obj_final_col := (obj_palette >> (obj_pix.color * 2)) & 0b11 
      bg_final_col := (gpu_state.palettes.bg >> (bg_col * 2)) & 0b11
      
      final_col := bg_final_col
      if !gpu_state.drawing_window && obj_pix.color != 0 && !(obj_pix.under_background && bg_col != 0) {
        final_col = obj_final_col
      }
      
      gpu_state.pixels[current_line][pusher_x] = final_col
      
    }
    if pusher_x == 160 {
      gpu_state.mode = .H_BLANK
    }
    
    pusher_x += 1

  case .H_BLANK:
    if gpu_state.dot_index == 455 {
      gpu_state.object_count = 0
      current_line += 1
      gpu_state.mode = .OAM_SCAN
      gpu_state.drawing_window = false
      if current_line == 144 {
        gpu_state.mode = .RENDER
      }
      gpu_state.dot_index = -1
    }
    
  case .RENDER:
    rl.BeginDrawing()
    rl.ClearBackground(rl.PINK)
    
    if !gpu_state.skip_frame {
      for px_line, y in gpu_state.pixels {
        for px, x in px_line {
          base := 50 + px * 40
          base = 255 - base
          col := rl.Color{base - 25, base, base - 25, 255}
          rl.ImageDrawPixel(&target_image, auto_cast x, auto_cast y, col)
        }
      }
    }
    rl.UpdateTexture(target_texture, target_image.data)
    rl.DrawTextureEx(target_texture, {0, 0}, 0, RENDER_MULTIPLE, rl.WHITE)
    rl.EndDrawing()
    
    if rl.IsKeyPressed(.L) {
      do_logging = !do_logging
    }
    
    i_flags := get_byte_as_flags(rg.Interrupt_Flags, rg.INTERRUPT_FLAGS)
    i_flags^ += {.VBlank}
    
    gpu_state.mode = .V_BLANK
    fallthrough
  
  case .V_BLANK:
    if gpu_state.dot_index == 455 {
      current_line += 1
      gpu_state.dot_index = -1
    }
    if current_line > 153 {
      current_line = 0
      gpu_state = {}
      gpu_state.dot_index = -1
      gpu_state.mode = .OAM_SCAN
    }
      
  }
  
  raw_memory_map[rg.LCD_Y_COORD] = current_line
  
  lcd_stat := get_byte_as_flags(rg.LCD_Status, rg.LCD_STATUS)
  {
    ppu_mode_no: u8
    switch gpu_state.mode {
    case .OAM_SCAN:
      ppu_mode_no = 2
    case .PRE_DRAW, .DRAWING:
      ppu_mode_no = 3
    case .H_BLANK:
      ppu_mode_no = 0
    case .RENDER, .V_BLANK:
      ppu_mode_no = 1
    }
    lcd_stat.PPU_mode = ppu_mode_no
    
    lcd_stat.ly_eq_lyc = current_line == raw_memory_map[rg.LCD_Y_COORD_COMPARE]
    
    do_interrupt: bool
    do_interrupt ||= lcd_stat.lyc_on && lcd_stat.ly_eq_lyc
    do_interrupt ||= lcd_stat.mode_0 && lcd_stat.PPU_mode == 0
    do_interrupt ||= lcd_stat.mode_1 && lcd_stat.PPU_mode == 1
    do_interrupt ||= lcd_stat.mode_2 && lcd_stat.PPU_mode == 2
    
    if do_interrupt {
      get_byte_as_flags(rg.Interrupt_Flags, rg.INTERRUPT_FLAGS)^ |= {.LCD}
    }
  }
  
  gpu_state.dot_index += 1
  gpu_state.frame_dot_index += 1
  return true
}

get_tile_data :: proc(current_line: u8, window: bool) {
  offset_x, offset_y: u8
  tile_map_is_offset: bool
  if window {
    offset_x = raw_memory_map[rg.WINDOW_X]
    offset_y = raw_memory_map[rg.WINDOW_Y]
    tile_map_is_offset = .window_tile_map_area in lcd_control
  } else {
    offset_x = raw_memory_map[rg.BACKGROUND_X]
    offset_y = raw_memory_map[rg.BACKGROUND_Y]
    tile_map_is_offset = .bg_tile_map_area in lcd_control
  }
  
  cam_x := pusher_x     + offset_x
  cam_y := current_line + offset_y
  
  tile_index := u16(cam_x >> 3) | (u16(cam_y >> 3) << 5)
  if tile_map_is_offset { tile_index += 0x0400 }
  
  tile_address := tile_index | rg.TILE_MAP_OFFSET
  tile_data_index := u16(video_ram[tile_address])
  
  tile_data_address: u16
  if .bg_window_tile_data_area not_in lcd_control {
    tile_data_index = u16(i16(i8(tile_data_index)))
    tile_data_address |= 0x1000
  }
  
  tile_data_address += tile_data_index << 4
  tile_data_address |= (u16(cam_y) & 0x7) << 1
  
  lsb := video_ram[tile_data_address]
  msb := video_ram[tile_data_address+1]
  
  for &pix, i in background_FIFO.pixels {
    ui := u8(i)
    bit_mask := u8(0x80 >> ui)
    pix.color = (lsb & bit_mask) >> (7 - ui) | (((msb & bit_mask) >> (7 - ui)) << 1)
  }
  background_FIFO.pixels_left = 8
}

get_object_data :: proc(current_line: u8) {
  x_pos := pusher_x + 8
  y_pos := current_line
  
  for obj_index in 0..<gpu_state.object_count {
    obj := gpu_state.line_objects[obj_index]
    offset: u8
    if obj.pos.x < 8 {
      offset = 8 - obj.pos.x
    }
    
    if obj.pos.x + offset == x_pos {
      tile_index := obj.tile_index
      obj_height := (.obj_size in lcd_control) ? 16 : 8
      if obj_height == 16 { tile_index = (obj.tile_index & ~u8(0b1)) }
      tile_address := u16(tile_index) * 16
      
      sprite_y := y_pos - obj.pos.y
      if obj.flags.y_flip { sprite_y = u8(obj_height) - sprite_y }
      sprite_y &= 0b1111
      
      tile_address += u16(sprite_y) * 2
      
      lsb := video_ram[tile_address]
      msb := video_ram[tile_address+1]
      
      result_pixels: [8]Pixel
      for &pix, i in result_pixels {
        ui := u8(i)
        if obj.flags.x_flip { ui = 7 - ui }
        bit_mask := u8(0x80 >> ui)
        pix.color = (lsb & bit_mask) >> (7 - ui) | (((msb & bit_mask) >> (7 - ui)) << 1)
      }
      
      for pix, i in result_pixels[offset:] {
        fifo_px := &object_FIFO.pixels[i]
        if fifo_px.color == 0 {
          fifo_px.color = pix.color
          fifo_px.palette = obj.flags.dmg_palette ? 1 : 0
          fifo_px.under_background = obj.flags.priority
        }
      }
      object_FIFO.pixels_left = 8 - offset
    }
  }
}

V2 :: struct {y, x: u8}
Object :: struct {
  pos: V2,
  tile_index: u8,
  flags: bit_field u8 {
    cbg_palette: u8   | 3,
    bank: bool        | 1,
    dmg_palette: bool | 1,
    x_flip: bool      | 1,
    y_flip: bool      | 1,
    priority: bool    | 1,
  }
}

objects := mem.slice_data_cast([]Object, raw_memory_map[rg.OAM_START:rg.OAM_END + 1])

Pixel :: bit_field u8 {
  color: u8            | 2,
  palette: u8          | 4,
  sprite_prio: bool    | 1, // used in color gameboy
  under_background: bool | 1,
}

object_FIFO:     FIFO_Device
background_FIFO: FIFO_Device

FIFO_Device :: struct {
  pixels: [8]Pixel,
  pixels_left: u8,
}

pop_pixel :: proc(device: ^FIFO_Device) -> Pixel {
  result := device.pixels[0]
  for i in 0..<7 {
    device.pixels[i] = device.pixels[i+1]
  }
  device.pixels[7] = {}
  if device.pixels_left != 0 { device.pixels_left -= 1 }
  return result
}

lcd_control: ^rg.LCD_Control_Byte = get_byte_as_flags(rg.LCD_Control_Byte, rg.LCD_CONTROL)


import "core:mem"
import rl "vendor:raylib"
import rg "memory_regions"
import "core:fmt"
import "core:strings"