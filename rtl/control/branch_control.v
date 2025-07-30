module branch_control (
    input wire [2:0] funct3_i,
    input wire zero_flag_i,
    input wire sign_flag_i,
    input wire carry_flag_i,
    input wire overflow_flag_i,
    output reg branch_taken_o
);

always @(*) begin
    case (funct3_i)
        3'b000: branch_taken_o = zero_flag_i;          // BEQ
        3'b001: branch_taken_o = ~zero_flag_i;         // BNE
        3'b100: branch_taken_o = sign_flag_i ^ overflow_flag_i; // BLT
        3'b101: branch_taken_o = ~(sign_flag_i ^ overflow_flag_i); // BGE
        3'b110: branch_taken_o = carry_flag_i;         // BLTU
        3'b111: branch_taken_o = ~carry_flag_i;        // BGEU
        default: branch_taken_o = 1'b0;                 // Default case, no branch taken
    endcase
end

endmodule
