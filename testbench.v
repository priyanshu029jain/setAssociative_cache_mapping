`timescale 1ns / 1ps

module testbench;
    reg clk;
    reg rst;
    reg [4:0] address;
    reg [7:0] data_in;
    reg write_enable;
    reg read_enable;
    wire [7:0] data_out;
    wire hit;
    wire [1:0] hit_line;

    // Instantiate the setAssociative_mapping module
    setAssociative_mapping uut (
        .clk(clk),
        .rst(rst),
        .address(address),
        .data_in(data_in),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .data_out(data_out),
        .hit(hit),
        .hit_line(hit_line)
    );

    always #5 clk = ~clk; // Clock generation

    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        address = 5'b00000;
        data_in = 8'b00000000;
        write_enable = 0;
        read_enable = 0;

        //dumpfile and dumpvars for waveform generation
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        // Monitor the outputs
        $display("Starting simulation...");
        $monitor("Time: %0t | Address: %b | Data In: %b | Write Enable: %b | Read Enable: %b | Data Out: %b | Hit: %b | Hit Line: %b", 
                 $time, address, data_in, write_enable, read_enable, data_out, hit, hit_line);


         // Reset the system
        #12 rst = 1'b0; // Deassert reset after 10 time units\

        // Wait for a few time units and then change the address
        #10 read_enable = 1'b1; // Enable reading
        #10 address = 5'b0_0101; 
        #10 address = 5'b0_1010; 
        #10 address = 5'b0_1100; 
        #10 read_enable = 1'b0; // Disable reading

        // Now enable writing to the cache
        write_enable = 1'b1; // Enable writing
        #10 data_in = 8'h10; 
            address = 5'b1_1001; 
        #10 data_in = 8'h20; 
            address = 5'b0_1100; 
        #10 write_enable = 1'b0; // Disable writing

        // Read from the same address again to check for a hit
        read_enable = 1'b1; // Enable reading again

        $display("Simulation finished.");
        // Finish simulation after some time
        #15 $finish;
    end
endmodule