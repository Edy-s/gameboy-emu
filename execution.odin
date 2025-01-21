package main

exec_command :: proc() {
  command := command_buffer[command_index]
  
  #partial switch command.type {
  case:
    print("Unimplemented command! %v\n", command)
  }
}