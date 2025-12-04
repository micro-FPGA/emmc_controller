# eMMC Controller IP

FPGA IP core for Embedded MultiMediaCard (eMMC) interface controller.

## Overview

Embedded Multi-Media Card (eMMC) is a type of non-volatile storage solution widely used in mobile devices, automotive systems, and embedded applications. It integrates NAND flash memory and a flash memory controller into a single package, providing a compact, cost-effective, and standardized storage interface.

The Lattice eMMC Controller IP is a soft IP block that implements the host-side JEDEC eMMC protocol, bridging an SoC's system bus to an external eMMC device over a 1/4/8-bit MMC interface. It manages the entire transaction lifecycle—command and response sequencing and data transfers. The IP provides memory-mapped control and status registers on standard APB interface, and AXI4 Manager interface for data transfer.

## Features

- JEDEC JESD84-B51A standard support
- Data IO width: x1, x4, x8 support
- AMBA AXI4 Manager bus interface for data transfer
- AMBA APB bus interface for CSR access
- eMMC clock frequencies up to 52 MHz, Single Data Rate
- Programmable clock divider
- Internal FIFO for data buffering (configurable depth)
- Interrupt support
- Optional IO primitive integration

## Limitations / Not Yet Implemented

Higher data rate as well as DDR mode is currently not supported and may be added in the future.

| Feature | Status | Description |
|---------|--------|-------------|
| **DDR Mode** | Not Implemented | Double Data Rate transfers |
| **HS200** | Not Implemented | High Speed 200 MB/s mode |
| **HS400** | Not Implemented | High Speed 400 MB/s mode |
| **Boot Mode** | Not Implemented | eMMC boot partition access |

**Current Maximum Speed:** 52 MB/s (High Speed SDR mode)

## Quick Facts

| Category | Item | Value |
|----------|------|-------|
| **IP Requirements** | Supported Families | LAV-AT (Lattice Avant), LFCPNX (CertusPro-NX), LFD2NX (Certus-NX), LIFCL (CrossLink-NX), LFMXO5 (MachXO5-NX) |
| | Supported User Interface | AXI4 or AHBL (Data), APB (CSR) |
| **Design Tool Support** | Min Radiant Version | 2025.1 |
| | Min Propel Version | 2025.1 |
| | Synthesis | Synopsys Synplify Pro for Lattice, Lattice Synthesis Engine |
| **IP Core** | Version | 1.0.0 |
| | Category | Processors, Controllers and Peripherals |

## Resource Utilization

Sample resource utilization using LFMXO5-100T device with default configuration:

| Resource | Count |
|----------|-------|
| **Slices** | 1,613 |
| **Registers** | 1,417 |
| **LUTs** | 1,877 |
| **EBR (Block RAM)** | 2 |

> **Note:** Resource utilization varies based on configuration parameters (FIFO depth, bus width, etc.)

## Validation Status

| Test Type | Status | Details |
|-----------|--------|---------|
| **RTL Simulation** | ✓ Passed | Functional verification with eMMC device model |
| **Hardware Testing** | ✓ Passed | Basic commands validated on Sentry DC-SCM Board with MachXO5D (XO5D) |
| **STA Timing** | ✓ Met | Static timing analysis passed at 100 MHz |

## User Interfaces

| User Interface | Supported Protocols | Description |
|----------------|---------------------|-------------|
| CSR Interface (Subordinate) | APB | Used to configure the IP core and control the IP to send eMMC commands. Register map is 1 KiB. |
| Data Interface (Manager) | AXI4, AHBL | Used to move data blocks from local system memory to eMMC device or vice versa. 32-bit address, 32-bit data. Selectable via GUI. |

> **Note:** AHB-Lite (AHBL) data interface is available but not as extensively tested as AXI4. When using AHBL, the AXI4 ports are tied off internally.

## Register Map

The eMMC Controller provides memory-mapped registers accessible via the APB interface. Register addresses are byte offsets (DWORD aligned).

### Address Map Overview

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00 | ID | R | IP Identification (0x4C534343 = "LSCC") |
| 0x04 | INT_ENA | R/W | Interrupt Enable |
| 0x08 | CFG0 | R/W | Configuration 0 (clock, IO) |
| 0x0C | CFG1 | R/W | Configuration 1 (timeouts) |
| 0x100 | INFO_STS | R | Information Status |
| 0x104 | INT_STS | R/W1C | Interrupt Status |
| 0x108 | RSP_DAT0 | R | Response Data 0 (command index + status) |
| 0x10C | RSP_DAT1 | R | Response Data 1 |
| 0x110 | RSP_DAT2 | R | Response Data 2 |
| 0x114 | RSP_DAT3 | R | Response Data 3 |
| 0x118 | RSP_DAT4 | R | Response Data 4 |
| 0x200 | SOFT_RST | R/W | Soft Reset Control |
| 0x204 | INT_SET | W | Interrupt Set (debug) |
| 0x208 | SRC_DST_ADDR | R/W | DMA Source/Destination Address |
| 0x20C | CTRL0 | R/W | Control 0 (block size/count) |
| 0x210 | CTRL1 | R/W | Control 1 (command argument) |
| 0x214 | CTRL2 | R/W | Control 2 (command trigger) |

---

### CFG0 - Configuration Register 0 (Offset: 0x08)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:22] | reserved | RO | 0 | Reserved |
| [21:20] | io_width | R/W | 0 | Data IO width: 0=x1, 2=x4, 3=x8 |
| [19:18] | reserved | RO | 0 | Reserved |
| [17] | ddr_mode | R/W | 0 | DDR mode: 0=SDR, 1=DDR (requires EN_DDR_MODE) |
| [16] | pp1_od0 | R/W | 0 | IO drive mode: 0=Open-Drain, 1=Push-Pull |
| [15:0] | clk_div | R/W | * | Clock divider. eMMC CLK = clk_i / (2 × clk_div). 0=divide by 1 |

> \* Default clk_div is calculated from system clock to achieve ~400 KHz initial eMMC clock.

---

### CFG1 - Configuration Register 1 (Offset: 0x0C)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:24] | reserved | RO | 0 | Reserved |
| [23:16] | dat_timeout | R/W | 0 | Data timeout in multiples of 32 eMMC clocks |
| [15:8] | reserved | RO | 0 | Reserved |
| [7:0] | cmd_timeout | R/W | 0 | Command timeout in multiples of 32 eMMC clocks |

Timeout calculation: `timeout_cycles = 32 × (value + 1)` eMMC clock cycles

---

### INT_ENA - Interrupt Enable Register (Offset: 0x04)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:22] | reserved | RO | 0 | Reserved |
| [21] | dat_timeout | R/W | 0 | Enable data timeout interrupt |
| [20] | cmd_timeout | R/W | 0 | Enable command timeout interrupt |
| [19] | bus_rd_err | R/W | 0 | Enable bus read error interrupt |
| [18] | bus_wr_err | R/W | 0 | Enable bus write error interrupt |
| [17] | dat_crc_err | R/W | 0 | Enable data CRC error interrupt |
| [16] | cmd_crc_err | R/W | 0 | Enable command CRC error interrupt |
| [15:1] | reserved | RO | 0 | Reserved |
| [0] | cmd_done | R/W | 0 | Enable command done interrupt |

---

### INT_STS - Interrupt Status Register (Offset: 0x104)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:22] | reserved | RO | 0 | Reserved |
| [21] | dat_timeout | R/W1C | 0 | Data timeout occurred |
| [20] | cmd_timeout | R/W1C | 0 | Command response timeout |
| [19] | bus_rd_err | R/W1C | 0 | AXI4 bus read error |
| [18] | bus_wr_err | R/W1C | 0 | AXI4 bus write error |
| [17] | dat_crc_err | R/W1C | 0 | Data CRC mismatch |
| [16] | cmd_crc_err | R/W1C | 0 | Command CRC mismatch |
| [15:1] | reserved | RO | 0 | Reserved |
| [0] | cmd_done | R/W1C | 0 | Command completed successfully |

> **R/W1C**: Write 1 to clear the corresponding bit.

---

### INFO_STS - Information Status Register (Offset: 0x100)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:24] | debug_dat_oe | RO | - | Data IO output enable (emmc_dat_oe_o) |
| [23:16] | debug_dat_o | RO | - | Data IO output (emmc_dat_o) |
| [15:8] | debug_dat_i | RO | - | Data IO input (emmc_dat_i) |
| [7] | reserved | RO | 0 | Reserved |
| [6] | debug_cmd_oe | RO | - | Command IO output enable |
| [5] | debug_cmd_o | RO | - | Command IO output |
| [4] | debug_cmd_i | RO | - | Command IO input |
| [3:1] | reserved | RO | 0 | Reserved |
| [0] | emmc_busy | RO | 0 | Controller busy: 0=Idle, 1=Transaction in progress |

---

### SOFT_RST - Soft Reset Register (Offset: 0x200)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:2] | reserved | RO | 0 | Reserved |
| [1] | emmc_rst | R/W | 0 | Assert eMMC device reset (emmc_rst_n_o) |
| [0] | ip_core_rst | R/W | 0 | Reset IP core logic (self-clearing) |

---

### SRC_DST_ADDR - Source/Destination Address Register (Offset: 0x208)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:0] | address | R/W | 0 | System memory address for DMA transfers |

---

### CTRL0 - Control Register 0 (Offset: 0x20C)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:16] | num_blocks | R/W | 0 | Number of data blocks (0=no data, 1=1 block, etc.) |
| [15:4] | reserved | RO | 0 | Reserved |
| [3:0] | block_len | R/W | * | Block length: 2^block_len bytes (9=512 bytes) |

> \* Default block_len is log2(DEF_BLOCK_SIZE).

---

### CTRL1 - Control Register 1 (Offset: 0x210)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:0] | cmd_arg | R/W | 0 | 32-bit command argument |

---

### CTRL2 - Control Register 2 (Offset: 0x214)

| Bit | Field | Access | Default | Description |
|-----|-------|--------|---------|-------------|
| [31:15] | reserved | RO | 0 | Reserved |
| [14:12] | rsp_typ | R/W | 0 | Response type: 0=none, 1=R1, 2=R2, 3=R3, 4=R4, 5=R5 |
| [11] | send_stop | R/W | 0 | Send CMD12 (stop) after data transfer |
| [10] | send_deselect | R/W | 0 | Send CMD7 deselect after command |
| [9] | send_select | R/W | 0 | Send CMD7 select before command |
| [8] | cmd_boot | R/W | 0 | Boot mode command (not implemented) |
| [7] | cmd_start | W | 0 | Write 1 to trigger command (self-clearing) |
| [6] | reserved | RO | 0 | Reserved |
| [5:0] | cmd_idx | R/W | 0 | eMMC command index (0-63) |

---

### RSP_DAT0-4 - Response Data Registers (Offset: 0x108-0x118)

| Register | Offset | Description |
|----------|--------|-------------|
| RSP_DAT0 | 0x108 | [5:0] Command index from response |
| RSP_DAT1 | 0x10C | Response bits [31:0] |
| RSP_DAT2 | 0x110 | Response bits [63:32] |
| RSP_DAT3 | 0x114 | Response bits [95:64] |
| RSP_DAT4 | 0x118 | Response bits [127:96] |

For R2 (136-bit) responses, all RSP_DAT registers contain valid data. For shorter responses (R1, R3, etc.), only RSP_DAT0 and RSP_DAT1 are relevant.

## Programming Sequence

### Initialization

1. De-assert reset (`rst_n_i` = 1) and wait at least 4 clock cycles
2. Configure clock divider in CFG0 for ~400 KHz initial clock
3. Set IO mode to Open-Drain (pp1_od0 = 0) and x1 width (io_width = 0)
4. Assert `emmc_rst_n_o` via SOFT_RST if needed
5. Send CMD0 (GO_IDLE_STATE) to reset the eMMC device
6. Send CMD1 (SEND_OP_COND) repeatedly until device is ready
7. Send CMD2 (ALL_SEND_CID) to get device CID
8. Send CMD3 (SET_RELATIVE_ADDR) to assign RCA

### Sending Commands

1. Write command argument to CTRL1 (cmd_arg)
2. Configure CTRL0 if data transfer is needed (num_blocks, block_len)
3. Configure CTRL2 with command index and response type
4. Write 1 to cmd_start bit in CTRL2 to trigger command
5. Wait for cmd_done interrupt or poll INFO_STS[0] for busy status
6. Read response from RSP_DAT registers if applicable
7. Check INT_STS for any errors

### Data Read Operation

1. Configure SRC_DST_ADDR with destination memory address
2. Set CTRL0: num_blocks and block_len
3. Send CMD17 (READ_SINGLE_BLOCK) or CMD18 (READ_MULTIPLE_BLOCK)
4. Wait for cmd_done interrupt
5. Data is automatically transferred via AXI4 to the configured address

### Data Write Operation

1. Configure SRC_DST_ADDR with source memory address
2. Set CTRL0: num_blocks and block_len
3. Send CMD24 (WRITE_BLOCK) or CMD25 (WRITE_MULTIPLE_BLOCK)
4. Wait for cmd_done interrupt
5. Data is automatically transferred via AXI4 from the configured address

### Switching to High Speed Mode

1. Complete initialization sequence
2. Send CMD6 (SWITCH) to set HS_TIMING in EXT_CSD
3. Update CFG0 clock divider for higher frequency (up to 52 MHz)
4. Set IO mode to Push-Pull (pp1_od0 = 1)
5. Optionally switch to x4 or x8 bus width via CMD6

## Clocking

The eMMC Controller IP has a single input clock operating at up to 200 MHz. The IP generates the eMMC clock using internal clock divider. The eMMC clock frequency depends on the divider setting (clk_div):

- `eMMC Clock = Input Clock`, when clk_div = 0
- `eMMC Clock = Input Clock / (2 × clk_div)`, when clk_div ≥ 1

For example, if the input clock is 200 MHz and the divider setting is 2, then the eMMC clock frequency is 50 MHz.

## Reset

The eMMC Controller IP provides:

- **Hardware Reset** (`rst_n_i`) - Asynchronous active-low reset for the entire IP including CSR. Minimum pulse width is one clock cycle.
- **IP Core Reset** - Soft reset that resets the eMMC Controller logic except the CSR block
- **eMMC Target Reset** - Resets the target device through `emmc_rst_n_o`

After de-asserting reset, wait for at least four clock cycles before starting any transaction.

## Directory Structure

```
emmc_controller/
├── rtl/                   # RTL source files (12 files)
├── testbench/             # Testbench files
├── sim/                   # Simulation scripts
├── doc/                   # Documentation (introduction.html)
├── driver/                # C driver files
├── plugin/                # Tool plugins
├── example_design/        # Example Propel SoC project
├── constraints/           # IP level constraints
├── scripts/               # Release and utility scripts
├── hooks/                 # Git hooks
├── metadata.xml           # IP metadata
├── settings.xml           # IP parameter settings
├── ports.xml              # IP port definitions
├── rtl_params.xml         # RTL parameters
├── bus_interface.xml      # Bus interface definitions
├── memory_map.xml         # Memory map definitions
├── address_space.xml      # Address space definitions
├── IP Release Notes.md    # Revision history
├── QUICKSTART.md          # Getting started guide
└── README.md              # This file
```

## RTL Files

| File | Description |
|------|-------------|
| `lscc_emmc_controller.v` | Top-level wrapper |
| `emmc_top.v` | Core controller top |
| `emmc_csr.v` | Control/Status registers (APB subordinate) |
| `emmc_cmd_proc.v` | Command processor |
| `emmc_axi4_m.v` | AXI4 manager interface |
| `emmc_ahbl_m.v` | AHB-Lite manager interface |
| `emmc_apb_s.v` | APB subordinate interface |
| `emmc_fifo.v` | Data FIFO |
| `emmc_clkgen.v` | Clock generator/divider |
| `emmc_serdes.v` | Serializer/Deserializer |
| `emmc_serdes_top.v` | SERDES top wrapper |
| `emmc_iologic.v` | IO logic primitives |

## IP Configuration Parameters

The following parameters are configurable through the Radiant IP Catalog GUI. Default values are shown in **bold**.

### User Interface

| Attribute | Values | Description |
|-----------|--------|-------------|
| CSR Interface (Target) | **APB** | Main interface to configure and control the IP registers (informational). |
| Enable Full CSR Address Decoding | Checked, **Unchecked** | If enabled, register address is decoded using full 32-bit address. If disabled, only lower 10 bits are decoded. Disable for Propel-based designs where address space is automatically allocated. |
| Register Map: APB Base Address (32b Hex) | **0x00000000** – 0xFFFFFC00 | Starting address of register space (1 KiB aligned). Only editable when full address decoding is enabled. |
| Data Interface (Controller) | **AXI4**, AHBL | Interface used by IP to move data between eMMC device and system memory. |
| AXI4 Bus ID Width | **1** – 12 | Width of AXI4 transaction ID signals. Only visible when Data Interface is AXI4. |
| FIFO Depth | **512**, 1024, 2048, 4096, 8192 | Depth of data interface FIFO in bytes. Options depend on maximum block size. |
| FIFO Implementation | LUT, EBR, **HARD IP** | FIFO memory implementation type. Available options depend on device family. |

### Capabilities

| Attribute | Values | Description |
|-----------|--------|-------------|
| Enable Double Transfer Rate | **Unchecked** | DDR mode support (not yet implemented, always disabled). |
| Max Number of Data Lanes | X1, X4, **X8** | Maximum data IO width. X1=1-bit, X4=4-bit, X8=8-bit bidirectional data pins. |
| Minimum Block Size Supported (Bytes) | 256 – 16384, **512** | Minimum block size in bytes. Affects internal counter and register width. |
| Maximum Block Size Supported (Bytes) | 256 – 16384, **1024** | Maximum block size in bytes. Affects internal counter and register width. |
| Default Block Size (Bytes) | **512** | Default block size (informational, calculated from min block size). |
| Maximum Number of Blocks in Single Transfer | 3, 7, 15, **31**, 63, ..., 65535 | Maximum blocks per read/write command. Affects internal counter and register width. |
| eMMC Maximum Speed (MBps) | 1 – **52** | Maximum device speed in MB/s. Affects clock frequency range and divider width. |

### Clock Configuration

| Attribute | Values | Description |
|-----------|--------|-------------|
| System Clock Frequency (MHz) | 2 – 200, **100** | System clock (clk_i) frequency. Range depends on eMMC maximum speed. |
| Internal Clock Frequency (MHz) | (calculated) | Same as system clock frequency (informational). |
| Minimum eMMC Clock Frequency (KHz) | 10 – **400** | Minimum eMMC clock frequency for initialization. Affects clock divider width. |
| Default eMMC Clock Pulse Width | 0 – varies, **125** | Default clock divider value. 0=same as clk_i, 1=divide by 2, 2=divide by 4, etc. |
| Default eMMC Clock Frequency (MHz) | (calculated) | Calculated as clk_i/(2×pulse_width) or clk_i if pulse_width=0 (informational). |
| Default eMMC Clock Period (ns) | (calculated) | Calculated from default eMMC clock frequency (informational). |

### IO Primitive

| Attribute | Values | Description |
|-----------|--------|-------------|
| Include IO Primitive | **Checked**, Unchecked | When enabled, eMMC command and data pins are bidirectional IO at top level (emmc_cmd_io, emmc_dat_io). When disabled, tristate control signals are exposed as separate ports (emmc_cmd_i/o/oe, emmc_dat_i/o/oe). |

### RTL Parameters

These parameters are passed to the Verilog module and are derived from the GUI settings above.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DEVICE_FAMILY` | string | (auto) | Target FPGA family (from device selection) |
| `SIMULATION` | int | 0 | Enable simulation mode |
| `DATA_INTERFACE` | string | "AXI4" | Data interface type ("AXI4" or "AHBL") |
| `CSR_INTERFACE` | string | "APB" | CSR interface type |
| `CLKI_FREQ` | real | 100.0 | System clock frequency (MHz) |
| `MAX_NUMLANE` | int | 8 | Maximum data lanes (1, 4, or 8) |
| `DEF_BLOCK_SIZE` | int | 512 | Default block size (bytes) |
| `MIN_BLOCK_SIZE` | int | 512 | Minimum block size (bytes) |
| `MAX_BLOCK_SIZE` | int | 1024 | Maximum block size (bytes) |
| `MAX_NUM_BLOCK` | int | 32 | Maximum blocks per transfer (gui_max_num_blk + 1) |
| `FIFO_DEPTH` | int | 512 | FIFO depth in bytes |
| `MEM_IMPL` | string | "HARD_IP" | Memory implementation ("HARD_IP", "EBR", "LUT") |
| `AXI4_TID_WIDTH` | int | 1 | AXI4 transaction ID width (1–12) |
| `CLKDIV_WID` | int | (calc) | Clock divider register width (calculated from clock settings) |
| `SPI_SCKDIV` | int | 125 | Default clock divider value |
| `USE_CLKDIV1` | int | (calc) | Enable divide-by-1 mode (1 if min divider is 0) |
| `USE_IO_PRIMITIVE` | int | 1 | Include internal IO primitives (0 or 1) |
| `EN_DDR_MODE` | int | 0 | Enable DDR mode (not implemented) |
| `EN_FULLADDR_DECODE` | int | 0 | Enable full 32-bit address decoding |
| `REG_BASE_ADDR` | 32-bit | 32'h00000000 | Register block base address |
| `TMR_WIDTH` | int | 8 | Timeout timer width (bits) |

## Port Descriptions

### System Clock and Reset

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk_i` | Input | System clock. Maximum frequency is 200 MHz. |
| `rst_n_i` | Input | Asynchronous active-low reset. Minimum pulse width is one clock cycle. After de-asserting reset, wait at least 4 clock cycles before starting any transaction. |

### eMMC Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `emmc_clk_o` | Output | 1 | eMMC output clock. Generated by the IP, synchronous to command and data transfers. Idle state is low. |
| `emmc_rst_n_o` | Output | 1 | Asynchronous active-low reset to eMMC device. Controlled by programmable register. Default state is high. |
| `emmc_dat_ds_i` | Input | 1 | Data strobe input from eMMC device (for HS400 mode - not yet implemented). |

**With Internal IO Primitives (USE_IO_PRIMITIVE=1):**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `emmc_cmd_io` | Inout | 1 | Bidirectional command channel. Open-drain for initialization, push-pull for fast transfers. Default state is tri-stated (device pull-up makes it high). |
| `emmc_dat_io` | Inout | [MAX_NUMLANE-1:0] | Bidirectional data channels (DAT0-DAT7). Push-pull mode. Width depends on MAX_NUMLANE parameter (1, 4, or 8). Default state is tri-stated. |

**With External IO Primitives (USE_IO_PRIMITIVE=0):**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `emmc_cmd_i` | Input | 1 | Command input from external IO buffer |
| `emmc_cmd_o` | Output | 1 | Command output to external IO buffer. Default state is high. |
| `emmc_cmd_oe_o` | Output | 1 | Active-high command output enable. Default state is low. |
| `emmc_dat_i` | Input | [MAX_NUMLANE-1:0] | Data input from external IO buffer |
| `emmc_dat_o` | Output | [MAX_NUMLANE-1:0] | Data output to external IO buffer. Default state is high. |
| `emmc_dat_oe_o` | Output | [MAX_NUMLANE-1:0] | Active-high data output enable. Default state is low. |

### Interrupt

| Signal | Direction | Description |
|--------|-----------|-------------|
| `int_o` | Output | Level-sensitive active-high interrupt. Asserts when any enabled interrupt status bit is set. |

### AXI4 Manager Interface (Data Transfer)

**Write Address Channel:**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_axi4_awready_i` | Input | 1 | Write address ready |
| `m_axi4_awvalid_o` | Output | 1 | Write address valid |
| `m_axi4_awid_o` | Output | [AXI4_TID_WIDTH-1:0] | Write transaction ID |
| `m_axi4_awaddr_o` | Output | 32 | Write address (DWORD aligned) |
| `m_axi4_awlen_o` | Output | 8 | Burst length |
| `m_axi4_awsize_o` | Output | 3 | Burst size (fixed: 2 = 4 bytes) |
| `m_axi4_awburst_o` | Output | 2 | Burst type (fixed: 1 = INCR) |
| `m_axi4_awprot_o` | Output | 3 | Protection (tied to 0) |

**Write Data Channel:**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_axi4_wready_i` | Input | 1 | Write data ready |
| `m_axi4_wvalid_o` | Output | 1 | Write data valid |
| `m_axi4_wdata_o` | Output | 32 | Write data |
| `m_axi4_wstrb_o` | Output | 4 | Write strobes |
| `m_axi4_wlast_o` | Output | 1 | Last write data in burst |

**Write Response Channel:**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_axi4_bready_o` | Output | 1 | Write response ready |
| `m_axi4_bvalid_i` | Input | 1 | Write response valid |
| `m_axi4_bid_i` | Input | [AXI4_TID_WIDTH-1:0] | Write response ID |
| `m_axi4_bresp_i` | Input | 2 | Write response status |

**Read Address Channel:**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_axi4_arready_i` | Input | 1 | Read address ready |
| `m_axi4_arvalid_o` | Output | 1 | Read address valid |
| `m_axi4_arid_o` | Output | [AXI4_TID_WIDTH-1:0] | Read transaction ID |
| `m_axi4_araddr_o` | Output | 32 | Read address (DWORD aligned) |
| `m_axi4_arlen_o` | Output | 8 | Burst length |
| `m_axi4_arsize_o` | Output | 3 | Burst size (fixed: 2 = 4 bytes) |
| `m_axi4_arburst_o` | Output | 2 | Burst type (fixed: 1 = INCR) |
| `m_axi4_arprot_o` | Output | 3 | Protection (tied to 0) |

**Read Data Channel:**

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_axi4_rready_o` | Output | 1 | Read data ready |
| `m_axi4_rvalid_i` | Input | 1 | Read data valid |
| `m_axi4_rid_i` | Input | [AXI4_TID_WIDTH-1:0] | Read response ID |
| `m_axi4_rdata_i` | Input | 32 | Read data |
| `m_axi4_rresp_i` | Input | 2 | Read response status |
| `m_axi4_rlast_i` | Input | 1 | Last read data in burst |

### AHB-Lite Manager Interface (Alternative Data Transfer)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `m_ahbl_hsel_o` | Output | 1 | AHB select |
| `m_ahbl_haddr_o` | Output | 32 | Address |
| `m_ahbl_htrans_o` | Output | 2 | Transfer type |
| `m_ahbl_hwrite_o` | Output | 1 | Write enable |
| `m_ahbl_hsize_o` | Output | 3 | Transfer size |
| `m_ahbl_hburst_o` | Output | 3 | Burst type |
| `m_ahbl_hprot_o` | Output | 4 | Protection |
| `m_ahbl_hmastlock_o` | Output | 1 | Locked transfer |
| `m_ahbl_hwdata_o` | Output | 32 | Write data |
| `m_ahbl_hready_i` | Input | 1 | Transfer done |
| `m_ahbl_hresp_i` | Input | 1 | Transfer response |
| `m_ahbl_hrdata_i` | Input | 32 | Read data |

> **Note:** AHB-Lite interface is available in RTL but not fully validated.

### APB Subordinate Interface (CSR Access)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `s_apb_psel_i` | Input | 1 | APB select. Indicates target is selected for data transfer. |
| `s_apb_penable_i` | Input | 1 | APB enable. Indicates second cycle of APB transfer. |
| `s_apb_pwrite_i` | Input | 1 | APB write. 0=Read, 1=Write. |
| `s_apb_paddr_i` | Input | 32 | APB address (DWORD aligned). |
| `s_apb_pwdata_i` | Input | 32 | APB write data. |
| `s_apb_prdata_o` | Output | 32 | APB read data. |
| `s_apb_pready_o` | Output | 1 | APB ready. Indicates transfer completion. |
| `s_apb_pslverr_o` | Output | 1 | APB error response. |

## Getting Started

See [QUICKSTART.md](QUICKSTART.md) for step-by-step instructions.

## Documentation

- `doc/introduction.html` - IP introduction for Radiant catalog
- This README contains the complete register map and usage information

## References

- JEDEC JESD84-B51A - Embedded Multi-Media Card (eMMC) Electrical Standard

## Version

v1.0.0

