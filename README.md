# vertex: A 32-bit RISC-V Core

vertex is a simple 32-bit RISC-V core designed for educational purposes. It is implemented in IEEE 1364-2005 Verilog and is intended to be used as a starting point for learning about RISC-V architecture and hardware design. It is also intended to be used for exploring different microarchitectural features and optimizations.

## Microarchitecture

Currently, vertex implements the RV32I base instruction set with a classic 5-stage pipeline. The core uses a simple unified memory interface for both instruction and data memory.

## Todo-List

- [ ] Implement hazard detection, forwarding, and stalling
- [ ] Implement branch flushing to handle control hazards
- [ ] Implement a more sophisticated memory interface
- [ ] Add basic exception and interrupt handling

