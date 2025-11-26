## How it works

TinyBF is a complete hardware implementation of a Brainfuck interpreter designed for ASIC fabrication through Tiny Tapeout. The design is a fully functional CPU with integrated UART I/O, programmable RAM-based storage, and a UART-based program uploader.

### Architecture

The system consists of six main components:

1. **Control Unit** - An 11-state finite state machine (FSM) that serves as the CPU core. It fetches instructions, decodes them, and orchestrates all operations including memory access and I/O. The FSM uses one-hot encoding for optimal gate count.

2. **Program Memory (RAM)** - 32×8-bit dual-port RAM for instruction storage. Each instruction is encoded as an 8-bit value: 3 bits for the opcode and 5 bits for a signed argument (enabling optimizations like `+5` instead of five separate `+` instructions). Programs can be uploaded via UART using the programmer module.

3. **Tape Memory (RAM)** - 16×8-bit synchronous RAM representing the Brainfuck data tape with 16 cells. This is the working memory where Brainfuck programs manipulate data.

4. **Programmer Module** - A 3-state FSM that receives instructions via UART and writes them sequentially to program memory. When PROG_MODE is high, UART RX is routed to the programmer instead of the CPU, enabling program upload. The programmer auto-increments the write address after each byte.

5. **UART Subsystem** - Includes both transmitter and receiver modules operating at 115200 baud. The UART handles Brainfuck's I/O commands: `.` (output) sends bytes via TX, and `,` (input) receives bytes via RX. A baud rate generator provides precise timing. UART RX is multiplexed between the programmer and CPU based on PROG_MODE.

6. **Reset Synchronizer** - Ensures clean reset propagation across clock domains to prevent metastability issues.

### Default Program

The RAM initializes with a UART-based case converter that demonstrates input, arithmetic, loops, and output (16 instructions). This program can be replaced by uploading new instructions via UART in programming mode:

```
Address | Instruction | Description
--------|-------------|------------
0       | ,           | Read character from UART into cell[0]
1       | >           | Move to cell[1]
2       | +10         | cell[1] = 10 (newline character)
3       | <           | Back to cell[0]
4       | [ +6        | Jump forward 6 if cell[0] == 0 (to address 10)
5       | -15         | Subtract 15 from cell[0]
6       | -15         | Subtract 15 from cell[0] (total -30)
7       | -2          | Subtract 2 from cell[0] (total -32)
8       | .           | Output cell[0] via UART
9       | ,           | Read next character
10      | ] -6        | Jump back -6 if cell[0] != 0 (to address 4)
11      | >           | Move to cell[1]
12      | .           | Output newline (cell[1] = 10)
13-15   | HALT        | End of program
```

**Program behavior:** Reads ASCII characters from UART RX (`,` command). For each non-null character, subtracts 32 (via -15, -15, -2) to convert lowercase to uppercase, then outputs via UART TX (`.` command). On null terminator (0x00), exits loop and outputs newline (0x0A).

**Example:** Input `"abc"` → Output `"ABC\n"`
- 'a' (0x61 = 97) → -32 → 'A' (0x41 = 65)
- 'b' (0x62 = 98) → -32 → 'B' (0x42 = 66)
- 'c' (0x63 = 99) → -32 → 'C' (0x43 = 67)
- null (0x00) → exit loop → output '\n' (0x0A)

### Instruction Set

TinyBF implements all eight Brainfuck commands plus an optimized instruction encoding:

| Opcode | Command | Description | Argument |
|--------|---------|-------------|----------|
| 000 | `>` | Increment data pointer | Signed offset (-16 to +15) |
| 001 | `<` | Decrement data pointer | Signed offset (-16 to +15) |
| 010 | `+` | Increment cell value | Amount (0 to 31) |
| 011 | `-` | Decrement cell value | Amount (0 to 31) |
| 100 | `.` | Output cell via UART | N/A |
| 101 | `,` | Input from UART to cell | N/A |
| 110 | `[` | Jump forward if zero | PC-relative offset |
| 111 | `]` | Jump backward if non-zero | PC-relative offset |

**Special:** The instruction `0x00` acts as a HALT, cleanly stopping program execution.

The 5-bit argument field enables compact encoding of common patterns. For example, incrementing a cell by 5 requires just one instruction instead of five, reducing both program size and execution time.

### Memory Timing

Both program memory and tape memory use synchronous reads with 1-cycle latency. The control unit explicitly manages this through dedicated wait states: when initiating a read, the FSM transitions through a WAIT state before the data becomes valid, ensuring correct synchronization without combinational paths through memory.

The program RAM implements write-first semantics: simultaneous read and write to the same address returns the newly written data. This ensures correct behavior when uploading programs.

## How to test

### Pin Configuration

**Inputs:**
- `ui[0]` - UART RX: Serial input for program upload or Brainfuck `,` command (115200 baud, 8N1)
- `ui[1]` - START: Pulse high to begin program execution from address 0
- `ui[2]` - HALT: Pulse high to stop execution immediately
- `ui[3]` - PROG_MODE: When high, UART RX uploads program; when low, normal execution

**Outputs:**
- `uo[0]` - UART TX: Serial output for Brainfuck `.` command (115200 baud, 8N1)
- `uo[1]` - CPU_BUSY or PROG_BUSY: High when CPU executing or programmer active
- `uo[6:2]` - Program counter bits [4:0]: Current instruction address (0-31)
- `uo[7]` - Unused

**Bidirectional (configured as outputs):**
- `uio[3:0]` - Data pointer [3:0]: Current tape position (0-15)
- `uio[7:4]` - Unused

### Testing Procedure

1. **Power-up and Reset**: Apply power and ensure `rst_n` is asserted low, then released high. The CPU will enter IDLE state. The default RAM program is immediately available (loaded during reset).

2. **Program Upload (Optional)**: To upload a new program:
   - Set PROG_MODE (`ui[3]`) high
   - Send program bytes sequentially via UART RX (115200 baud, 8N1)
   - Each byte is written to the next address (starting from 0)
   - Set PROG_MODE low when upload is complete
   - Address counter automatically resets when PROG_MODE goes low

3. **Start Execution**: Pulse the START input (`ui[1]`) high for at least one clock cycle. The CPU will begin executing the program in RAM.

3. **Expected Behavior**:
   - **UART Input**: Program waits for character input on UART RX
   - **Case conversion**: Converts lowercase ASCII to uppercase (subtracts 32)
   - **UART output**: Outputs converted characters via UART TX
   - **Loop termination**: Exits on null character (0x00), outputs newline (0x0A)

5. **Monitor Execution**: 
   - Watch `CPU_BUSY/PROG_BUSY` (`uo[1]`) to see when the system is active
   - Observe the program counter on `{uio[7:6], uo[7:2]}` (full 7-bit address, 0-127)
   - Monitor the data pointer on `uio[5:0]` (6-bit address, 0-63)
   - Track cell values by reading tape memory (not visible on pins in current design)

6. **UART Communication** (with default program):
   - Ensure PROG_MODE (`ui[3]`) is low (execution mode)
   - Connect a UART terminal to `ui[0]` (RX) and `uo[0]` (TX) at 38400 baud, 8N1 format
   - Send lowercase characters like `"abc"` followed by null terminator (0x00)
   - You should receive uppercase output `"ABC\n"`
   - The default program demonstrates interactive UART I/O with both `,` (input) and `.` (output) commands

7. **Program Restart**: To run the program again, pulse START (`ui[1]`) or reset the system.

## External hardware

**Required:**
- UART controller for serial communication
  - Connect TinyBF's TX (`uo[0]`) to converter's RX
  - Connect TinyBF's RX (`ui[0]`) to converter's TX
  - Configure terminal software for 38400 baud, 8 data bits, no parity, 1 stop bit (8N1)

**Optional:**
- Logic analyzer or oscilloscope to monitor debug outputs (program counter, data pointer, cell values)
- Push button for manual START/HALT control

**Note:** The program can be changed at runtime by uploading new instructions via UART in programming mode. This makes TinyBF a fully programmable Brainfuck interpreter, not just a demonstration platform. The default program is restored on reset.
