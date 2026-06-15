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
    input wire [address_bites -1:0] address, // 5 bit address
    input wire [data_bites -1:0] data_in, // 8 bit data input
    input wire write_enable, // write enable signal
    input wire read_enable, // read enable signal
    output reg [data_bites -1:0] data_out, // 8 bit data output
    output reg hit, // hit signal
    output reg [hit_line_bites-1:0] hit_line // line number of the hit
  );

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
  localparam index_bites = $clog2(sets);
  localparam tag_bites = $clog2(RAM_BLOCKS / sets); // Number of bits for the tag
  localparam block_no_bites = $clog2(RAM_BLOCKS);

  // Define the RAM and cache structures
  reg[block_bites -1 :0] RAM [0:RAM_BLOCKS-1];
  reg [line_bites -1:0] cache [0:sets-1][0:K_ways-1]; // 4 lines of cache, each line is 8 bits (1 word)
  reg [sets-1:0] valid_bits [0:K_ways-1]; // valid bits for each line
  reg [tag_bites -1:0] tags [0:sets-1][0:K_ways-1]; // tags for each line

  // Initialize RAM, cache and valid bits
  integer i,j;
  initial
  begin : init_memory_cache
    $readmemh(`FILE, RAM, 0, RAM_BLOCKS-1);

    for (i = 0; i < sets; i = i + 1)
    begin : init_cache
      for (j = 0; j < K_ways; j = j + 1)
      begin : init_lines
          cache[i][j] = {data_bites{1'b0}};
          valid_bits[i][j] = 1'b0;
          tags[i][j] = {tag_bites{1'b0}};
      end
    end
  end

  //extracting the tag_address, set_index and word_offset
  wire [tag_bites -1:0] tag_address = address[address_bites -1 -: tag_bites]; // Extract the tag from the address (first 3 bits)
  wire [index_bites -1:0]set_index = address[offset_bites +: index_bites]; // Extract the set index from the address (last 2 bits)
  wire [offset_bites -1:0] word_offset = address[offset_bites -1:0];
  wire [block_no_bites -1:0] block_no = {tag_address,set_index};


  always @(posedge clk or posedge rst)
  begin : cache_operations
    if (rst)
    begin : reset_cache
      for (i = 0; i < sets; i = i + 1)
      begin
        for (j = 0; j < K_ways; j = j + 1)
        begin
          cache[i][j] <= {data_bites{1'b0}};
          valid_bits[i][j] <= 1'b0;
          tags[i][j] <= {tag_bites{1'b0}};
        end
      end
      data_out <= {data_bites{1'b0}};
      hit <= 1'b0;
      hit_line <= {hit_line_bites{1'b0}};
    end

    else
    begin : normal_operation
      hit <= 1'b0;
      hit_line <= {hit_line_bites{1'b0}};

      if (read_enable && !write_enable)
      begin : read_operation

        for(i = 0; i < K_ways; i = i + 1)
        begin :for_loop
          if (valid_bits[set_index][i] && tags[set_index][i] == tag_address)
          begin : cache_hit
            data_out <= cache[set_index][i][word_offset * word_bites +: word_bites]; // Output the data from the cache if it's a hit
            hit <= 1'b1; // Set hit signal
            hit_line <= i[hit_line_bites -1:0]; // Set the line number of the hit
            disable for_loop; // Exit the loop on hit
          end
        end

        if(!hit)
        begin : cache_miss
          data_out <= RAM[block_no][word_offset * word_bites +: word_bites]; // Output the data from RAM if it's a miss

          for(i = 0; i < 2; i = i + 1)
          begin : update_cache
            if (!valid_bits[set_index][i])
            begin : update_line
              cache[set_index][i] <= RAM[block_no]; // Update the cache line with the new data
              valid_bits[set_index][i] <= 1'b1; // Set the valid bit for the line
              tags[set_index][i] <= tag_address; // Store the tag (the first 3 bits of the address)
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
      end

      else if (write_enable && !read_enable)
      begin : write_operation

        RAM[block_no][word_offset * word_bites +: word_bites] <= data_in; // Write the data to RAM

        for(i = 0; i < 2; i = i + 1)
        begin :for_loop
          if (valid_bits[set_index][i] && tags[set_index][i] == tag_address)
          begin : cache_hit
            cache[set_index][i][word_offset * word_bites +: word_bites] <= data_in; // Update the cache line with the new data
            hit <= 1'b1; // Set hit signal
            hit_line <= i[hit_line_bites -1:0]; // Set the line number of the hit
            disable for_loop; // Exit the loop on hit
          end
        end

        if(!hit)
        begin : cache_miss

          for(i = 0; i < 2; i = i + 1)
          begin : update_cache
            if (!valid_bits[set_index][i])
            begin : update_line
              cache[set_index][i] <= RAM[block_no]; // Update the cache line with the new data
              valid_bits[set_index][i] <= 1'b1; // Set the valid bit for the line
              tags[set_index][i] <= tag_address; // Store the tag (the first 3 bits of the address)
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
      end

      //   else begin : idel_sate
      //     data_out <= {`BYTE{1'bz}};
      //     hit <= 1'bz;
      //     hit_line <= 2'bz;
      //   end
    end
  end
endmodule
