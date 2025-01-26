package main

ROM_data : []u8

@(private="file")
memory_map : [0xFFFF+1]u8
raw_memory_map := memory_map[:]

ROM_header : struct {
  entry_point: [4]u8,
  nintendo_logo: [48]u8,
  game_title: [16]u8,
  license_code: [2]u8,
  sgb_flag: u8,
  
  cart_type: u8,
  rom_size: u8,
  ram_size: u8,
  
  country_code: u8,
  old_license_code: u8,
  rom_version: u8,
  header_checksum: u8,
  global_checksum: [2]u8
}

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
  ROM_data = file
  header_type :: type_of(ROM_header)
  ROM_header = mem.slice_data_cast([]header_type, ROM_data[0x0100:0x0150])[0]
  
  supported := false
  for sup in supported_MBCs {
    if ROM_header.cart_type == sup {
      supported = true
      break
    }
  }
  if !supported {
    print("Unsupported ROM type - %2x.\n", ROM_header.cart_type)
    return false
  }
  
  MBC_state.rom_bank = 1
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
    write_to_MBC(address, data)
    return
  }
  
  if address >= 0xA000 && address <= 0xBFFF {
    RAM_banks[MBC_state.ram_bank][address & 0x1FFF] = data
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
  
  if address <= 0x3FFF {
    ROM_address := u32(address)
    ROM_address |= u32(MBC_state.upper_bank) << 19
    
    return ROM_data[address]
  }
  if address >= 0x4000 && address <= 0x7FFF {
    ROM_address := u32(address & 0x3FFF) // Only take the first 13 bits
    ROM_address |= u32(MBC_state.rom_bank) << 14
    ROM_address |= u32(MBC_state.upper_bank) << 19
    
    return ROM_data[ROM_address]
  }
  
  if address >= 0xA000 && address <= 0xBFFF {
    return RAM_banks[MBC_state.ram_bank][address & 0x1FFF]
  }
  
  return memory_map[address]
}

get_byte_as_flags :: proc($T: typeid, address: u16) -> ^T {
  return transmute(^T)&memory_map[address]
}


//
// -- Memory Bank Controller
//

supported_MBCs := [?]u8{0x00, 0x01, 0x02, 0x03}

RAM_banks: [16][8192]u8

MBC_state : struct {
  rom_bank: u8,
  ram_bank: u8,
  upper_bank: u8,
  
  ram_enabled: bool,
  banking_mode: bool,
}

write_to_MBC :: proc(address: u16, data: u8) {
  switch {
  case address <= 0x1FFF:
    // assert(ROM_header.ram_size != 0, "Attempted to toggle ram when ram size is 0 in ROM header.")
    if (data & 0xF) == 0xA {
      MBC_state.ram_enabled = true
    } else {
      MBC_state.ram_enabled = false
    }
    
  case address >= 0x2000 && address <= 0x3FFF:
    rom_bits := data & 0x1F
    if rom_bits == 0 { rom_bits = 1 }
    // if ROM_header.rom_size < 0x05 { rom_bits &= 0xF }
    MBC_state.rom_bank = rom_bits
    
  case address >= 0x4000 && address <= 0x5FFF:
    ram_bits := data & 0x3
    if ram_bits != 0 {
      // assert(ROM_header.ram_size >= 0x02, "Attempted to switch ram bank when there are no ram banks defined in ROM header.")
      MBC_state.ram_bank = ram_bits
    }
    
    if MBC_state.banking_mode {
      upper_bank_bits := (data & 0x60) >> 5 // bits 5 and 6
      MBC_state.upper_bank = upper_bank_bits
    }
      
  case address >= 0x6000 && address <= 0x7FFF:
    MBC_state.banking_mode = data != 0
  }
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
import "core:mem"
import rg "memory_regions"
import rl "vendor:raylib"