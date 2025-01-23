package main

import "core:os"

import rg "memory_regions"

@(private="file")
memory_map : [0xFFFFF]u8
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

oam_dma: struct {
  active: bool,
  source_msb: u8,
  index: u16,
}

do_memory_tick :: proc() {
  if oam_dma.active {
    source_address := u16(oam_dma.source_msb) << 8
    memory_map[rg.OAM_START + oam_dma.index] = memory_map[source_address + oam_dma.index]
    oam_dma.index += 1
    if oam_dma.index == 160 { oam_dma.active = false }
  }
}

write_at :: proc(address: u16, data: u8) {
  if address == rg.OAM_DMA_REGISTER {
    oam_dma.active = true
    oam_dma.source_msb = data
    oam_dma.index = 0
    return
  }
  
  memory_map[address] = data
}

read_at :: proc(address: u16) -> u8 {
  if oam_dma.active && !(address >= 0xFF80 && address <= 0xFFE) {
    panic("Read outside of HRAM during OAM DMA.")
  }
  
  if address == 0xFF44 { return 0x90 }
  return memory_map[address]
}