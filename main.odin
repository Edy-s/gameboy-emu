package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:strings"
print :: fmt.printf
import rl "vendor:raylib"

import rg "memory_regions"

cycle_index := 0


main :: proc() {

  serial_data: [dynamic]u8
  init_log()
  
  RUN_GAPS :: 3_000_000
  // execution_cutoff := RUN_GAPS
  serial_finish := 100_000_000
  
  
  init_GPU()
  init_CPU()
  ok := init_memory()
  if !ok { return }
  
  log_for_doc()
  running := true
  for running {
    do_chip_tick()
    
    cpu_success := do_CPU_tick()
    if !cpu_success { running = false }
    
    gpu_success := do_GPU_tick()
    if !gpu_success { running = false }
    
    cycle_index += 1
    
    
    if rl.WindowShouldClose() { running = false }
    if number_of_instructions_executed_succesfully > serial_finish { running = false }
    
    UNSET_INPUT :: u8(0b00_11_1111)
    input_out := UNSET_INPUT
    switch {
    case rl.IsKeyPressed(.Z):
      input_out &= ~u8(0b1) // A
      input_out &= ~u8(0b100000)
    case rl.IsKeyPressed(.X):
      input_out &= ~u8(0b10) // B
      input_out &= ~u8(0b100000)
    case rl.IsKeyPressed(.A):
      input_out &= ~u8(0b1000) // start
      input_out &= ~u8(0b100000)
    case rl.IsKeyPressed(.S):
      input_out &= ~u8(0b100) // select
      input_out &= ~u8(0b100000)
    
    case rl.IsKeyPressed(.UP):
      input_out &= ~u8(0b100)
      input_out &= ~u8(0b10000)
    case rl.IsKeyPressed(.DOWN):
      input_out &= ~u8(0b1000)
      input_out &= ~u8(0b10000)
    case rl.IsKeyPressed(.LEFT):
      input_out &= ~u8(0b10)
      input_out &= ~u8(0b10000)
    case rl.IsKeyPressed(.RIGHT):
      input_out &= ~u8(0b1)
      input_out &= ~u8(0b10000)
    }
    raw_memory_map[rg.INPUT] = input_out
    
    i_flags := get_byte_as_flags(rg.Interrupt_Flags, rg.INTERRUPT_FLAGS)
    if input_out != UNSET_INPUT { i_flags^ |= {.Joypad} }
    
    
    
    /*
    if number_of_instructions_executed_succesfully > execution_cutoff {
      print("x to stop: ")
      in_thing: [10]u8
      os.read(os.stdin, in_thing[:])
      if in_thing[0] == 'x' { running = false }
      execution_cutoff += RUN_GAPS
    }*/
    
    // if !oam_dma.active && read_at(0xFF02) & 0x80 != 0 {
    //   print("%c", read_at(0xFF01))
    //   append(&serial_data, read_at(0xFF01))
      
    //   pass_string := "Passed"
    //   pass_u8 := transmute([]u8)pass_string
    //   if len(serial_data) > 9 && mem.compare(serial_data[len(serial_data) - 7 : len(serial_data) - 1], pass_u8) == 0 { serial_finish = number_of_instructions_executed_succesfully + 100000000 }
    //   byte := read_at(0xFF02)
    //   write_at(0xFF02, byte & (~u8(0x80)))
    // }
  }
  if strings.builder_len(gb_doc_log) > 0 { os.write_entire_file("doctor.log", transmute([]u8)strings.to_string(gb_doc_log)) }
  print("Number of instructions executed: %v\n", number_of_instructions_executed_succesfully)
}