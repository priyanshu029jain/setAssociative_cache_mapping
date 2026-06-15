//word = 1 byte
//block = 4 word
//lines = 4
//sey  = 2
//ram = 32

`define BYTE 8
`define FILE "storage.mem"

module setAssociative_mapping(
    input wire clk, // clock signal
    input wire rst, // reset signal
    input wire [6:0] address, // 5 bit address
    input wire [7:0] data_in, // 8 bit data input
    input wire write_enable, // write enable signal
    input wire read_enable, // read enable signal
    output reg [7:0] data_out, // 8 bit data output
    output reg hit, // hit signal
    output reg [1:0] hit_line // line number of the hit
  );

  // Define the RAM and cache structures
  reg[4* `BYTE -1 :0] RAM [0:31];
  reg [4* `BYTE -1:0] cache [0:1][0:1]; // 4 lines of cache, each line is 8 bits (1 word)
  reg [1:0] valid_bits [0:1]; // valid bits for each line
  reg [3:0] tags [0:1][0:1]; // tags for each line

  // Initialize RAM, cache and valid bits
  integer i,j;
  initial
  begin : init_memory_cache
    $readmemh(`FILE, RAM, 0, 31);

    for (i = 0; i < 2; i = i + 1)
    begin : init_cache
      for (j = 0; j < 2; j = j + 1)
      begin : init_lines
        cache[i][j] <= {8{1'b0}};
        valid_bits[i][j] <= 1'b0;
        tags[i][j] <= 4'b0;
      end
    end
  end

  //extracting the tag_address, set_index and word_offset
  wire [3:0] tag_address = address[6:3]; // Extract the tag from the address (first 3 bits)
  wire set_index = address[2]; // Extract the set index from the address (last 2 bits)
  wire [1:0] word_offset = address[1:0];
  wire [4:0] block_no = {tag_address,set_index};


  always @(posedge clk or posedge rst)
  begin : cache_operations
    if (rst)
    begin : reset_cache
      for (i = 0; i < 2; i = i + 1)
      begin
        for (j = 0; j < 2; j = j + 1)
        begin
          cache[i][j] <= {8{1'b0}};
          valid_bits[i][j] <= 1'b0;
          tags[i][j] <= 4'b0;
        end
      end
      data_out <= {8{1'b0}};
      hit <= 1'b0;
      hit_line <= 2'b00;
    end

    else
    begin : normal_operation
      hit <= 1'b0; // Default to no hit
      hit_line <= 2'b00; // Default to no hit line

      if (read_enable && !write_enable)
      begin : read_operation

        for(i = 0; i < 2; i = i + 1)
        begin :for_loop
          if (valid_bits[set_index][i] && tags[set_index][i] == tag_address)
          begin : cache_hit
            data_out <= cache[set_index][i][word_offset * 8 +: 8]; // Output the data from the cache if it's a hit
            hit <= 1'b1; // Set hit signal
            hit_line <= i[1:0]; // Set the line number of the hit
            disable for_loop; // Exit the loop on hit
          end
        end

        if(!hit)
        begin : cache_miss
          data_out <= RAM[block_no][word_offset * 8 +: 8]; // Output the data from RAM if it's a miss

          for(i = 0; i < 2; i = i + 1)
          begin : update_cache
            if (!valid_bits[set_index][i])
            begin : update_line
              cache[set_index][i] <= RAM[block_no][word_offset * 8 +: 8]; // Update the cache line with the new data
              valid_bits[set_index][i] <= 1'b1; // Set the valid bit for the line
              tags[set_index][i] <= tag_address; // Store the tag (the first 3 bits of the address)
              disable update_cache; // Exit the loop after updating
            end
          end

          // If all lines are valid, replace the first line (simple replacement policy)
          if(&valid_bits[set_index])
          begin : replace_line
            cache[set_index][0] <= RAM[block_no][word_offset * 8 +: 8]; // Replace the first line with the new data
            valid_bits[set_index][0] <= 1'b1; // Set the valid bit for the replaced line
            tags[set_index][0] <= tag_address; // Update the tag for the replaced line
          end
        end
      end

      else if (write_enable && !read_enable)
      begin : write_operation

        RAM[block_no][word_offset * 8 +: 8] <= data_in; // Write the data to RAM

        for(i = 0; i < 2; i = i + 1)
        begin :for_loop
          if (valid_bits[set_index][i] && tags[set_index][i] == tag_address)
          begin : cache_hit
            cache[set_index][i][word_offset * 8 +: 8] <= data_in; // Update the cache line with the new data
            hit <= 1'b1; // Set hit signal
            hit_line <= i[1:0]; // Set the line number of the hit
            disable for_loop; // Exit the loop on hit
          end
        end

        if(!hit)
        begin : cache_miss

          for(i = 0; i < 2; i = i + 1)
          begin : update_cache
            if (!valid_bits[set_index][i])
            begin : update_line
              cache[set_index][i] <= RAM[block_no][word_offset * 8 +: 8]; // Update the cache line with the new data
              valid_bits[set_index][i] <= 1'b1; // Set the valid bit for the line
              tags[set_index][i] <= tag_address; // Store the tag (the first 3 bits of the address)
              disable update_cache; // Exit the loop after updating
            end
          end

          // If all lines are valid, replace the first line (simple replacement policy)
          if(&valid_bits[set_index])
          begin : replace_line
            cache[set_index][0] <= RAM[block_no][word_offset * 8 +: 8]; // Replace the first line with the new data
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
