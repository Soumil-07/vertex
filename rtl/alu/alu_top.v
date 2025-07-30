module alu_top (
    input  [3:0]        instr_i,
    input  signed [31:0] src1_i,
    input  signed [31:0] src2_i,
    output reg signed [31:0] result_o,
    output reg         zero_flag_o,
    output reg         carry_flag_o,
    output reg         sign_flag_o,
    output reg         overflow_flag_o
);

    localparam ADD=0, SUB=1, XOR=2, OR=3, AND=4, SLL=5,
               SRL=6, SRA=7, SLT=8, SLTU=9;

    wire signed [31:0] add_result_val, sub_result_val;
    wire add_carry, sub_carry;

    // Correctly calculate ADD/SUB and their carry bits
    assign {add_carry, add_result_val} = {1'b0, src1_i} + {1'b0, src2_i};
    assign {sub_carry, sub_result_val} = {1'b0, src1_i} - {1'b0, src2_i}; 

    // --- Main ALU and Flag Logic ---
    always @(*) begin
        // Default flags for logical operations
        carry_flag_o    = 1'b0;
        overflow_flag_o = 1'b0;

        // Determine the primary result based on the instruction
        case (instr_i)
            ADD: begin
                result_o        = add_result_val;
                carry_flag_o    = add_carry;
                overflow_flag_o = (src1_i[31] == src2_i[31]) && (add_result_val[31] != src1_i[31]);
            end
            SUB: begin
                result_o        = sub_result_val;
                carry_flag_o    = ~sub_carry; // Invert borrow to get standard carry logic
                overflow_flag_o = (src1_i[31] != src2_i[31]) && (sub_result_val[31] != src1_i[31]);
            end
            SLT: begin
                result_o        = {31'd0, ($signed(src1_i) < $signed(src2_i))};
            end
            SLTU: begin
                result_o        = {31'd0, (src1_i < src2_i)};
            end
            XOR:  result_o = src1_i ^ src2_i;
            OR:   result_o = src1_i | src2_i;
            AND:  result_o = src1_i & src2_i;
            SLL:  result_o = src1_i << src2_i[4:0];
            SRL:  result_o = src1_i >> src2_i[4:0];
            SRA:  result_o = $signed(src1_i) >>> src2_i[4:0];
            default: result_o = 32'dx;
        endcase

        // These flags depend only on the final result
        zero_flag_o = (result_o == 32'b0);
        sign_flag_o = result_o[31];
    end

endmodule
