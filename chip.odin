package main

@(private="file")
memory_map : [0xFFFF+1]u8
raw_memory_map := memory_map[:]

init_memory :: proc() -> bool {
  filename: string
  if len(os.args) > 1 { filename = os.args[1] }
  else {
    print("Provide first arg as filename.\n")
    return false
  }
  
  file, ok := os.read_entire_file_from_filename(filename)
  if !ok {
    print("Couldn't read file!\n")
    return false
  }
  
  assert(len(file[:])-1 == 0x7FFF)
  copy(memory_map[0x0000:0x7FFF], file[:])
  
  raw_memory_map[rg.INPUT] = 0xFF
  
  return true
}

do_chip_tick :: proc() {
  if oam_dma.active {
    source_address := u16(oam_dma.source_msb) << 8
    memory_map[rg.OAM_START + oam_dma.index] = memory_map[source_address + oam_dma.index]
    oam_dma.index += 1
    if oam_dma.index == 160 { oam_dma.active = false }
  }
  
  //
  // -- Timer
  //
  if (cycle_index % 256) == 0 {
    memory_map[rg.TIMER_DIV] += 1
  }
  
  timer_control := get_byte_as_flags(rg.Timer_Control_Reg, rg.TIMER_CONTROL)
  if timer_control.enabled {
    if timer_overflew && (cycle_index % 4) == 0 {
      i_flags := get_byte_as_flags(rg.Interrupt_Flags, rg.INTERRUPT_FLAGS)
      i_flags^ |= {.Timer}
      memory_map[rg.TIMER_COUNT] = memory_map[rg.TIMER_MODULO]
      timer_overflew = false
    } else {
      m_cycles: u16
      switch timer_control.clock_select {
      case .M_256:
        m_cycles = 256
      case .M_4:
        m_cycles = 4
      case .M_16:
        m_cycles = 16
      case .M_64:
        m_cycles = 64
      }
      
      t_cycles := int(m_cycles) * 4
      if (cycle_index % t_cycles) == 0 {
        timer := memory_map[rg.TIMER_COUNT]
        timer += 1
        if timer == 0 { timer_overflew = true }
        memory_map[rg.TIMER_COUNT] = timer
      }
    }
  }
  
  
  //
  // -- Input
  //
  input := raw_memory_map[rg.INPUT]
  input |= 0xF
  debug_shite := 0
  if (input & 0x20) == 0 { 
    switch {
    case rl.IsKeyDown(.Z):
      input &= ~u8(0b1) // A
      debug_shite += 1
      
    case rl.IsKeyDown(.X):
      input &= ~u8(0b10) // B
      debug_shite += 1
      
    case rl.IsKeyDown(.A):
      input &= ~u8(0b1000) // start
      debug_shite += 1
      
    case rl.IsKeyDown(.S):
      input &= ~u8(0b100) // select
      debug_shite += 1
      
    }
  } else if (input & 0x10) == 0 {
    switch {
    case rl.IsKeyDown(.UP):
      input &= ~u8(0b100)
      debug_shite += 1
      
    case rl.IsKeyDown(.DOWN):
      input &= ~u8(0b1000)
      debug_shite += 1
      
    case rl.IsKeyDown(.LEFT):
      input &= ~u8(0b10)
      debug_shite += 1
      
    case rl.IsKeyDown(.RIGHT):
      input &= ~u8(0b1)
      debug_shite += 1
      
    }
  }
  raw_memory_map[rg.INPUT] = input
  
  if ~(input & 0xF) == 0 {
    i_flags := get_byte_as_flags(rg.Interrupt_Flags, rg.INTERRUPT_FLAGS)
    i_flags^ |= {.Joypad}
  }
}

write_at :: proc(address: u16, data: u8) {
  data := data
  switch address {
  case rg.OAM_DMA_REGISTER:
    oam_dma.active = true
    oam_dma.source_msb = data
    oam_dma.index = 0
    return
    
  case rg.TIMER_DIV:
    data = 0
  
  case rg.LCD_STATUS:
    // Low 3 bits are read only.
    data &= ~u8(0b111)
  }
  
  if address < 0x8000 {
    // TODO: MBC handling
    return
  }
  
  memory_map[address] = data
}

import intr "base:intrinsics"
read_at :: proc(address: u16) -> u8 {
  if oam_dma.active && oam_dma.index != 0 && !(address >= 0xFF80 && address <= 0xFFFE) {
    print("Read outside of HRAM during OAM DMA.\n")
    intr.debug_trap()
  }
  
  if address == 0xFF40 { 
    data := 123
    data += 1
  }
  return memory_map[address]
}

get_byte_as_flags :: proc($T: typeid, address: u16) -> ^T {
  return transmute(^T)&memory_map[address]
}


// @(private="file")
oam_dma: struct {
  active: bool,
  source_msb: u8,
  index: u16,
}
@(private="file")
timer_overflew: bool

import "core:os"
import rg "memory_regions"
import rl "vendor:raylib"