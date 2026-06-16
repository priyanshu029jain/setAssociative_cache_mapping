//word = 1 byte
//block = 4 word
//lines = 4
//sey  = 2
//ram = 32

`define BYTE 8
`define FILE "storage.mem"

module setAssociative_mapping #(
    parameter WORD_SIZE = 1, //bytes in word
    parameter BLOCK_SIZE = 4, //no. of words per block
    parameter CACHE_LINES = 4, //no of lines in cache
    parameter K_ways = 2, // no of lines per set #K-way
    parameter RAM_BLOCKS = 32 //no of block in RAM memory
  ) (
    input wire clk, // clock signal
    input wire rst, // reset signal
    input wire [address_bites -1:0] address, //address of word
    input wire [data_bites -1:0] data_in, //data input of word length
    input wire write_enable, // write enable signal
    input wire read_enable, // read enable signal
    output reg [data_bites -1:0] data_out, //data output of word length
    output reg hit, // hit signal high when cache hit
    output reg [hit_line_bites-1:0] hit_line // line number of the hit
  );

  // -------------------------------
  // Derived constants
  // -------------------------------
  // Calculate the number of bits for various components based on the parameters
  localparam word_bites = WORD_SIZE * `BYTE; // Number of bits in a word
  localparam block_bites = BLOCK_SIZE * word_bites; // Number of bits in a block
  localparam address_bites = $clog2(RAM_BLOCKS * BLOCK_SIZE); // Number of bits in the address
  localparam data_bites = word_bites; // Number of bits in the data bus
  localparam line_bites = block_bites; // Number of bits in a cache line
  localparam hit_line_bites = $clog2(CACHE_LINES); // Number of bits to represent the cache line index

  // Calculate the number of bits for the tag and offset based on the address breakdown
  localparam sets = CACHE_LINES / K_ways; // number of set in cache
  localparam offset_bites = $clog2(BLOCK_SIZE); // Number of bits for the word offset within a block
  localparam index_bites = $clog2(sets); //number of bites for set index
  localparam tag_bites = $clog2(RAM_BLOCKS / sets); // Number of bits for the tag
  localparam block_no_bites = $clog2(RAM_BLOCKS); //number of bits to represent each block of memory
  localparam K_bites = $clog2(K_ways); // no of bites for line in a set

  // -------------------------------
  // Memory structures
  // -------------------------------
  // Define the RAM and cache structures
  reg[block_bites -1 :0] RAM [0:RAM_BLOCKS-1];// main memory
  reg [line_bites -1:0] cache [0:sets-1][0:K_ways-1]; // 4 lines of cache, each line is 8 bits (1 word)
  reg [sets-1:0] valid_bits [0:K_ways-1]; // valid bits for each line
  reg [tag_bites -1:0] tags [0:sets-1][0:K_ways-1]; // tags for each line
  reg [K_bites-1:0] line_in_set; // line in a perticular set

  // -------------------------------
  // Initialization
  // -------------------------------
  // Initialize RAM, cache and valid bits
  initial
  begin : init_memory_cache
    $readmemh(`FILE, RAM, 0, RAM_BLOCKS-1);

    cache_reset();
  end

  // -------------------------------
  // Address breakdown
  // -------------------------------
  //extracting the tag_address, set_index and word_offset
  wire [tag_bites -1:0] tag_address = address[address_bites -1 -: tag_bites]; // Extract the tag from the address (first 3 bits)
  wire [index_bites -1:0]set_index = address[offset_bites +: index_bites]; // Extract the set index from the address (last 2 bits)
  wire [offset_bites -1:0] word_offset = address[offset_bites -1:0];
  wire [block_no_bites -1:0] block_no = {tag_address,set_index};

  // -------------------------------
  // Task: reset cache
  // -------------------------------
  // reset the cache, tags, valid array all to zero
  task cache_reset;
    integer i, j;
    begin
      //reseting the array
      for (i = 0; i < sets; i = i + 1)
      begin
        for (j = 0; j < K_ways; j = j + 1)
        begin
          cache[i][j] = {line_bites{1'b0}}; // clear cache line
          valid_bits[i][j] = 1'b0; // clear valid bit
          tags[i][j] = {tag_bites{1'b0}}; // clear tag
        end
      end

      //reset the outputs pin to ZERO
      data_out = {data_bites{1'b0}};
      hit = 1'b0;
      hit_line = {hit_line_bites{1'b0}};
    end
  endtask

  // -------------------------------
  // Task: search cache
  // -------------------------------
  //search for the hit line in cache hit = 0 for hit and hit = 1 for miss
  task cache_search;
    output [K_bites -1:0] line_in_set;
    integer i;
    begin
      //deafault values (no hit)
      line_in_set = {K_bites{1'b0}};
      hit = 1'b0;
      hit_line = {hit_line_bites{1'b0}};

      //saerching for hit
      for (i = 0; i < K_ways; i = i + 1)
      begin :for_loop
        if (valid_bits[set_index][i] && tags[set_index][i] == tag_address)
        begin : condition_for_hit
          line_in_set = i[K_bites-1:0]; // return line index
          hit = 1'b1; // set hit flag
          hit_line = i[hit_line_bites-1:0]; // set hit line
          disable for_loop; //exit the loop on hit
        end
      end
    end
  endtask

  // -------------------------------
  // Task: replacement policy
  // -------------------------------
  //replace the line of cache with block from memory
  task cache_replacement;
    integer i;
    begin

      //search for empty line in set (inValid line)
      for(i = 0; i < 2; i = i + 1)
      begin : update_cache
        if (!valid_bits[set_index][i])
        begin : update_line
          cache[set_index][i] <= RAM[block_no]; // Update the cache line with the new data
          valid_bits[set_index][i] <= 1'b1; // Set the valid bit for the line
          tags[set_index][i] <= tag_address; // Store the tag
          disable update_cache; // Exit the loop after updating
        end
      end

      // If all lines are valid, replace the first line (simple replacement policy)
      if(&valid_bits[set_index])
      begin : replace_line
        cache[set_index][0] <= RAM[block_no]; // Replace the first line with the new data
        valid_bits[set_index][0] <= 1'b1; // Set the valid bit for the replaced line
        tags[set_index][0] <= tag_address; // Update the tag for the replaced line
      end
    end
  endtask

  // -------------------------------
  // Main cache operations
  // -------------------------------
  always @(posedge clk or posedge rst)
  begin : cache_operations

    //reset the cache on high rst
    //async reset
    if (rst)
    begin :reset_cache
      cache_reset();
    end

    //normal read & write operation
    else
    begin : normal_operation

      //read when rd = low and wr = high
      if (read_enable && !write_enable)
      begin : read_operation

        //cache_searching for hit
        cache_search(line_in_set);

        if (hit)
        begin : cache_hit
          //output_data from cache
          data_out <= cache[set_index][line_in_set][word_offset*word_bites +: word_bites];
        end

        else
        begin : cache_miss
          // Output_data from RAM
          data_out <= RAM[block_no][word_offset * word_bites +: word_bites];

          //replace the cache with RAM
          cache_replacement();
        end
      end

      //write when rd = low and wr = high
      else if (write_enable && !read_enable)
      begin : write_operation

        //cache searching
        cache_search(line_in_set);

        // Write the data to RAM (always update the RAM)
        RAM[block_no][word_offset * word_bites +: word_bites] <= data_in;

        if (hit)
        begin : cache_hit
          //only update a particular word in block
          cache[set_index][line_in_set][word_offset*word_bites +: word_bites] <= data_in;
        end

        else
        begin : cache_miss
          //replace the cache from RAM
          cache_replacement();
        end
      end

      //   else begin : idel_sate
      //     data_out <= {`BYTE{1'bz}};
      //     hit <= 1'bz;
      //     hit_line <= 2'bz;
      //   end
    end
  end
endmodule
