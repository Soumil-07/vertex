# test.s
.section .text
.global _start

_start:
  # Basic ALU test
  li  x1, 10        # Load immediate 10 into register x1
  li  x2, 25        # Load immediate 20 into register x2
  li  x4, 0x200

  # nops are required here as the core doesn't support hazards yet
  nop 
  nop 

  add x3, x1, x2    # x3 = x1 + x2. Result should be 30 (0x1E)

  nop
  nop

  # Memory test
  sw  x3, 0(x4)     # Store the value of x3 into memory at address 0x200

  nop 
  lw  x5, 0(x4)     # Load the value from memory at 0x200 into x5

# Infinite loop to halt the processor at the end
hang:
  j hang
