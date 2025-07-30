`timescale 1ns / 1ps

module tb_core;

    // Testbench signals
    reg clk;
    reg rstn;

    // Memory model and flattened wire for the DUT
    localparam MEM_BYTES = 1024;
    reg [7:0] tb_mem [0:MEM_BYTES-1];
    wire [MEM_BYTES*8-1:0] mem_flat;

    core dut (
        .mem_i(mem_flat),
        .clk_i(clk),
        .rstn_i(rstn)
    );

    // This generate block "flattens" our 2D byte-array memory into the
    // single large vector the core expects as an input.
    genvar i;
    generate
        for (i = 0; i < MEM_BYTES; i = i + 1) begin : flatten_mem
            assign mem_flat[(i*8) +: 8] = tb_mem[i];
        end
    endgenerate

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // 1. Load the assembled program into the testbench memory.
        $readmemh("build/test.hex", tb_mem);

        // 2. Start with reset asserted (active low).
        rstn = 1'b0;
        #20; // Hold reset for 20 ns

        // 3. De-assert reset to start the processor.
        rstn = 1'b1;

        // 4. Let the simulation run for a while, then stop.
        #500;
        $display("Simulation finished.");
        $finish;
    end

    always @(posedge clk) begin
        if (rstn) begin // Only monitor after reset is released
            $strobe("Time=%0t PC=0x%h, x1=%d, x2=%d, x3(add)=%d, x4(addr)=0x%h, x5(lw)=%d",
                     $time,
                     dut.pc,              // Program Counter
                     dut.reg_file[1],     // Register x1
                     dut.reg_file[2],     // Register x2
                     dut.reg_file[3],     // Register x3
                     dut.reg_file[4],     // Register x4
                     dut.reg_file[5]);    // Register x5
        end
    end

endmodule
