# TinyBF - Brainfuck CPU for wafer.space GF180 Tapeout

Hardware implementation of a Brainfuck interpreter designed for the wafer.space GF180 ASIC tapeout as part of the KV Design of Integrated Circuits course (336.007) at Johannes Kepler University Linz, WS25/26.

## Features

- Complete Brainfuck interpreter in hardware
- 32 instructions × 8-bit program memory (RAM, programmable via UART)
- 16 cells × 8-bit data memory (tape)
- UART I/O at 115200 baud for `,` and `.` commands
- UART-based program uploader
- 25MHz system clock
- Default demo program: case converter (lowercase → UPPERCASE)

## Quick Start

1. **Upload a program** (optional - default program loads on reset):
   - Set `PROG_MODE` (`ui[3]`) high
   - Send instruction bytes via UART RX at 115200 baud, 8N1
   - Set `PROG_MODE` low when done

2. **Run the program**:
   - Pulse `START` (`ui[1]`) high
   - Interact via UART at 115200 baud

## Documentation

See [docs/info.md](docs/info.md) for complete details on architecture, instruction set, and testing.

## Author

René Hahn  
Course: KV Design of Integrated Circuits (336.007), WS25/26  
Institution: IICQC, Johannes Kepler University Linz
