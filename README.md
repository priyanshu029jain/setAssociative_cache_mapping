# 🧭 K-Way Set-Associative Cache Memory Architecture

A parameterized, synthesizable **K-Way Set-Associative Cache Controller** implemented in Verilog. This architecture blends the advantages of both direct-mapped and fully associative layouts—restricting memory blocks to specific structural sets to keep search logic fast, while providing $K$ flexible line slots within each set to dramatically lower conflict thrashing.

---

## 🚀 Architectural Overview

In this 2-way associative configuration ($K = 2$), the cache array is divided into indexed structural collections called **sets**. A memory block maps directly to an assigned set based on its address lines, but it can choose to sit within **any available line slot** inside that specific set.

---

## 📐 Address Space Partitioning

Based on your design constants, the total memory space maps to **128 unique addressable byte positions**:

$$\text{Total Addressable Elements} = \text{RAM\_BLOCKS} \times \text{BLOCK\_SIZE} = 32 \times 4 = 128 \text{ elements}$$

To address these elements, the module builds a **7-bit physical address bus** via `$clog2(128) = 7`. The address bus breaks down structurally into three dedicated fields:

```text
 Bit Position:   [6]       [5]       [4]       [3]    |    [2]    |   [1]       [0]
 Field Mapping:  <------- Tag (4 bits) ------>| Index (1) | <- Offset (2 bits) ->
 ```
  
## 🛠️ Design Features

This cache architecture provides optimized data handling and memory tracking through the following core design features:

* **Balanced Hybrid Mapping:** By leveraging a 2-way set-associative layout, the design balances speed and complexity. It reduces the physical hardware comparator footprint compared to a fully associative cache while maintaining strong immunity against conflict thrashing compared to direct-mapped designs.
* **Encapsulated Task Routines:** Cleanly partitions critical state operations into independent, modular hardware blocks using Verilog tasks. Separate tasks manage concurrent tag sweeps (`cache_search`), data allocation during cold-starts or misses (`cache_replacement`), and boot-up cleaning (`cache_reset`).
* **Immediate Write-Through Protocol:** Ensures complete memory consistency across all layout tiers. Whenever the processor executes a write cycle (`write_enable`), updates are instantly driven down to the primary background main `RAM` block concurrently with active internal cache register adjustments.

## 📂 Repository File Structure

```text
setassociative_cache_mapping/
├── .gitignore                 # Specifies untracked compilation & simulation artifacts
├── README.md                  # Main overview, toolchain guide, and simulation instructions
├── setAssociative_mapping.v   # Synthesizable RTL implementation of K-Way Set-Associative cache
├── setAssociative_mapping.md  # Auto-generated detailed hardware module specifications
├── setAssociative_mapping.svg # Top-level schematic block diagram of the module boundary
├── storage.mem                # Hexadecimal main memory initialization image file
├── simulation_5.png           # Waveform capturing verified cache hit/miss transitions
└── testbench.v                # Testbench simulation suite validating reads, writes, & set routing
```

## 📋 Module Specifications

The set-associative cache engine is fully parameterized, allowing easy modifications to data word sizes, cache associativity lines, and total memory blocks.

> 🔍 **Detailed Pinout & Signal Directory:** For the complete, auto-generated hardware port layouts, bit-slice signals, internal task descriptions, and synthesis constants, please refer directly to the full [setAssociative_mapping.md](./setAssociative_mapping.md) architectural specification file.

### ⚙️ Core Configuration Quick-View

| Parameter | Default Value | Description |
| :--- | :---: | :--- |
| `WORD_SIZE` | `1` | Sizing of an individual data word, evaluated in bytes |
| `BLOCK_SIZE` | `4` | Number of words bundled into a single memory block line |
| `CACHE_LINES` | `4` | Total storage rows available across the entire cache |
| `K_ways` | `2` | Association density setting the number of parallel slots per set |
| `RAM_BLOCKS` | `32` | Depth sizing configuration of the background main RAM array |

## 🛠️ Toolchain & EDA Tools

This project was developed, simulated, and documented using the following industrial and open-source hardware engineering tool suite:

* **Design & IDE:** [VS Code](https://code.visualstudio.com/) — Integrated development environment used for writing synthesizable RTL code.
* **Documentation Engine:** [TerosHDL](https://teroshdl.github.io/teroSHDL/) — Used for real-time code parsing, block diagram schematic generation, and automated markdown documentation formatting.
* **Simulation & Synthesis Compiler:** [Icarus Verilog (iVerilog)](http://iverilog.icarus.com/) — Open-source Verilog simulation and synthesis tool used to compile the RTL design and testbench.
* **Waveform Viewer:** [GTKWave](https://gtkwave.sourceforge.net/) — Fully featured wave viewer used to open and analyze the compiled `.vcd` (Value Change Dump) simulation files to verify the controller's state machine transitions.

## 🚀 Compilation and Simulation Guide

This workspace is fully optimized for VS Code utilizing the Icarus Verilog (iverilog) compiler toolchain and GTKWave for visual waveform debugging.

**Prerequisites**
Ensure you have the simulation binaries installed on your system terminal:

```text  
    # Verify installations
    iverilog -v
    vvp -v
```

## 💻Execution Steps

1. **Open your Terminal at the root project directory**  
2. **Compile the Design Modules Together**
3. **Execute the Compiled Binary**
4. **Analyze the Output Waveform**

```text
    # bash cmd
    iverilog -o sim_out.vvp rtl_design/direct_mapping.v testbench/testbench.v
    vvp sim_out.vvp
    gtkwave waveform/testbench.vcd
```
