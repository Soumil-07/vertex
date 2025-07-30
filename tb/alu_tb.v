module alu_tb;

reg [3:0] inst;
reg signed [31:0] src1, src2;
wire signed [32:0] out;

alu_top alu_inst (
    .instr_i(inst),
    .src1_i(src1),
    .src2_i(src2),
    .result_o(out)
);

localparam  ADD = 0,
            SUB = 1,
            XOR = 2,
            OR = 3,
            AND = 4,
            SLL = 5,
            SRL = 6,
            SRA = 7,
            SLT = 8;

initial begin
    src1 = 0;
    src2 = 0;
    inst = 0;

    #5 src1 = 32'd20; src2 = 32'd15;
    #5 inst = SUB;
    #5 src1 = -1;
    #5 inst = ADD;
end

initial $monitor("inst = %d src1 = %d src2 = %d out = %d", inst, src1, src2, out);

initial begin
    $dumpfile("alu.vcd");
    $dumpvars;
end

endmodule
