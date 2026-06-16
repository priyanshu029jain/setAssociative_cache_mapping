# 📋 Module Specifications: setAssociative_mapping

- **Source File:** `setAssociative_mapping.v`

---

## 📐 Block Diagram

Below is the structural block diagram showing the top-level boundary interface ports, parameter hooks, and multi-dimensional tracking arrays:

![Diagram](setAssociative_mapping.svg "Architectural Module Diagram")

---

## ⚙️ Generics / Parameters

These parameters define the architectural limits and dimensional array sizing constraints for the cache level and the background main memory layout:

| Generic name  | Type        | Value | Description |
| ------------- | ----------- | ----- | ----------- |
| `WORD_SIZE`   | `parameter` | `1`     | Width of an individual data word, evaluated in bytes (defaults to 1 byte / 8 bits). |
| `BLOCK_SIZE`  | `parameter` | `4`     | Data grouping density specifying the number of unique words bundled per memory block line. |
| `CACHE_LINES` | `parameter` | `4`     | Total storage row lines allocated across the entire high-speed cache hardware structure. |
| `K_ways`      | `parameter` | `2`     | Association index defining the exact number of parallel lines grouped into each discrete structural set. |
| `RAM_BLOCKS`  | `parameter` | `32`    | Total depth block configuration modeling the storage capacity of the main background memory array. |

---

## 🔌 Interface Ports

Top-level interface boundaries connecting the processor master controller to your cache storage matrices and background memory loops:

| Port name      | Direction | Type                       | Description |
| -------------- | --------- | -------------------------- | ----------- |
| `clk`          | input     | `wire`                       | Master system clock line driving internal state validation updates on its rising edge. |
| `rst`          | input     | `wire`                       | Global active-high synchronous system reset signal used to invoke the `cache_reset` routine. |
| `address`      | input     | `wire [address_bites -1:0]` | Incoming physical memory address target bus supplied by the CPU (maps to 7 bits wide). |
| `data_in`      | input     | `wire [data_bites -1:0]`    | Processor data bus input channel delivering updated values for write transactions. |
| `write_enable` | input     | `wire`                       | Active-high control strobe line triggering data write cycles down to the RAM and cache lines. |
| `read_enable`  | input     | `wire`                       | Active-high control strobe line initiating internal parallel set comparison sweeps. |
| `data_out`     | output    | `reg [data_bites -1:0]`     | Registered data bus output routing the target word slice back out to the processor interface. |
| `hit`          | output    | `reg`                        | Active-high validation flag indicating the targeted block tag exists within the indexed set. |
| `hit_line`     | output    | `reg [hit_line_bites-1:0]` | Binary encoded pointer identifying the precise physical cache line holding the hit block. |

---

## 💾 Hardware Internal Signals

Internal multidimensional registers and slicing wires mapping storage vectors, address bits, and set directories:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `RAM [0:RAM_BLOCKS-1]` | `reg [block_bites -1:0]` | Primary background storage array containing 32 distinct blocks initialized by an external hex memory file. |
| `cache [0:sets-1][0:K_ways-1]` | `reg [line_bites -1:0]` | Multidimensional high-speed register array tracking data blocks across 2 distinct sets containing 2 ways each. |
| `valid_bits [0:K_ways-1]` | `reg [sets-1:0]` | Parallel register array recording line validity flags to isolate lookups against uninitialized boot noise. |
| `tags [0:sets-1][0:K_ways-1]` | `reg [tag_bites -1:0]` | Directory array tracking the 4-bit identifier tag values associated with each individual cache slot. |
| `line_in_set` | `reg [K_bites-1:0]` | Internal pointer tracking variable indicating which lane position inside a target set is being processed. |
| `tag_address = address[address_bites -1 -: tag_bites]` | `wire [tag_bites -1:0]` | Continuous bit-slice extraction isolating the upper 4 block matching tag bits (`address[6:3]`) in real-time. |
| `set_index = address[offset_bites +: index_bites]` | `wire [index_bites -1:0]` | Continuous bit-slice extraction tracking the middle 1 bit (`address[2]`) to route to the correct set. |
| `word_offset = address[offset_bites -1:0]` | `wire [offset_bites -1:0]` | Continuous bit-slice monitoring isolating the lower 2 bits (`address[1:0]`) for multi-word byte selection. |
| `block_no = {tag_address,set_index}` | `wire [block_no_bites -1:0]` | Concatenated 5-bit lookup vector providing the direct root index location inside the main `RAM` structure. |

---

## 📐 Synthesis Constants (Localparams)

Compile-time architectural weights calculated automatically from your parameter values:

| Name | Type | Value | Description |
| -------------- | ---- | ------------------------- | ----------- |
| `word_bites`    | `localparam` | `WORD_SIZE * \`BYTE` | Sizing scale configuring an individual data word boundary (evaluates to 8 bits wide). |
| `block_bites`   | `localparam` | `BLOCK_SIZE * word_bites` | Sizing scale mapping a full multi-word block payload space (evaluates to 32 bits wide). |
| `address_bites` | `localparam` | `$clog2(RAM_BLOCKS * BLOCK_SIZE)` | Total bus width tracking the system's entire memory footprint (7 bits to map 128 items). |
| `data_bites`    | `localparam` | `word_bites` | Configuration boundary constant matching the top-level processor data width (8 bits). |
| `line_bites`    | `localparam` | `block_bites` | Register width width allocated to host data arrays in individual cache positions (32 bits). |
| `hit_line_bites`| `localparam` | `$clog2(CACHE_LINES)` | Bit width used to capture and drive the physical cache row address index line (2 bits). |
| `sets`          | `localparam` | `CACHE_LINES / K_ways` | Structuring value evaluating the total number of sets inside the array layout (4 / 2 = 2 sets). |
| `offset_bites`  | `localparam` | `$clog2(BLOCK_SIZE)` | Width required to uniquely identify a word location inside a 4-word block line (2 bits). |
| `index_bites`   | `localparam` | `$clog2(sets)` | Bit width required to navigate and choose one of the internal structural sets (1 bit). |
| `tag_bites`     | `localparam` | `$clog2(RAM_BLOCKS / sets)` | Width reserved for tag directories to confidently identify a main memory block (4 bits). |
| `block_no_bites`| `localparam` | `$clog2(RAM_BLOCKS)` | Direct bit scale representing the 32 discrete main memory storage positions (5 bits). |
| `K_bites`       | `localparam` | `$clog2(K_ways)` | Sizing scale tracking the relative offset line number inside an isolated set row (1 bit). |

---

## 🛠️ Tasks

### `cache_reset`
* **Arguments:** `integer i`, `integer j`
* **Description:** Sweeps the multi-dimensional structure rows across all sets and ways to clear power-on values. It pulls all elements within `cache`, `tags`, and `valid_bits` to zero, and forces all interface output ports to clean default states.

### `cache_search`
* **Arguments:** `output [K_bites -1:0] line_in_set`
* **Description:** Executes a parallel tag look-up sweep across the $K$ lanes within the specified `set_index`. If a target lane is active (`valid_bits`) and the tag matches `tag_address`, it returns the lane identifier position, sets `hit` active-high, and drives the global `hit_line` flag.

### `cache_replacement`
* **Arguments:** `integer i`
* **Description:** Handles cache line allocation when a lookup misses. It sweeps the lines of the selected set looking for a vacant slot (`!valid_bits`). If it captures an open slot, it loads the data block from `RAM`, sets the validation bit, and links the reference tag. If the targeted set is full, it drops back to an eviction policy that overwrites Way-0.

---

## ⚙️ Behavioral Processes

### `cache_operations`
* **Type:** `always @(posedge clk or posedge rst)`
* **Description:** The master synchronous process coordinating memory execution sequences and layout state transitions.
  * **Asynchronous Reset Step:** Watches for an active `rst` edge to clear internal registries via the `cache_reset` task execution.
  * **Read Operation Mode:** Triggers when `read_enable` is high. It relies on `cache_search` to find entries. On a hit, it extracts the requested word using the `word_offset` bit-slice from the cache line. On a miss, it routes the word directly from `RAM` to `data_out` while simultaneously calling `cache_replacement` to fetch the missing block.
  * **Write Operation Mode:** Triggers when `write_enable` is active. It adopts a **Write-Through** policy, updating the background main `RAM` immediately. It also searches the cache directory; if a write hit occurs, it modifies the corresponding word slice within the specific cache way register in-place to guarantee memory consistency. If it misses, it brings the block into the cache using the replacement task.