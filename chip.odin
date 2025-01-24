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
  
  return true
}

do_chip_tick :: proc() {
  if oam_dma.active {
    source_address := u16(oam_dma.source_msb) << 8
    memory_map[rg.OAM_START + oam_dma.index] = memory_map[source_address + oam_dma.index]
    oam_dma.index += 1
    if oam_dma.index == 160 { oam_dma.active = false }
  }
  
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
}

write_at :: proc(address: u16, data: u8) {
  data := data
  switch address {
  case rg.OAM_DMA_REGISTER:
    oam_dma.active = true
    oam_dma.source_msb = data
    oam_dma.index = 0
    return
  case rg.TIMER_COUNT:
    data = data
    
  case rg.TIMER_DIV:
    data = 0
  }
  
  memory_map[address] = data
}

read_at :: proc(address: u16) -> u8 {
  if oam_dma.active && !(address >= 0xFF80 && address <= 0xFFE) {
    panic("Read outside of HRAM during OAM DMA.")
  }
  
  // if address == 0xFF44 { return 0x90 }
  return memory_map[address]
}

get_byte_as_flags :: proc($T: typeid, address: u16) -> ^T {
  return transmute(^T)&memory_map[address]
}

// set_flags_as_byte :: proc(flags: $T, address: u16) {
//   memory_map[address] = transmute(u8)flags
// }

@(private="file")
oam_dma: struct {
  active: bool,
  source_msb: u8,
  index: u16,
}
@(private="file")
timer_overflew: bool

import "core:os"
import rg "memory_regions"
