// This logic block is in the Execute Stage
module alu_control (
    input  [1:0]  alu_op,      // From main control unit in ID
    input  [2:0]  funct3,      // From instruction
    input         funct7_bit5, // From instruction (instr[30])
    output reg [3:0] alu_control // To the main ALU
);

    localparam ADD  = 4'd0,
               SUB  = 4'd1,
               XOR  = 4'd2,
               OR   = 4'd3,
               AND  = 4'd4,
               SLL  = 4'd5,
               SRL  = 4'd6,
               SRA  = 4'd7,
               SLT  = 4'd8,
               SLTU = 4'd9;

    always @(*) begin
        case (alu_op)
            // Case 1: Load/Store/Jumps/U-types -> ADD
            2'b00:  alu_control = ADD;

            // Case 2: Branch -> SUB
            2'b01:  alu_control = SUB;

            // Case 3: I-type instructions -> Decode based on funct3
            2'b11: begin
                case (funct3)
                    3'b000: alu_control = ADD;  // ADDI
                    3'b001: alu_control = SLL;  // SLLI
                    3'b010: alu_control = SLT;  // SLTI
                    3'b011: alu_control = SLTU; // SLTIU
                    3'b100: alu_control = XOR;  // XORI
                    3'b101: begin // SRLI / SRAI
                        if (funct7_bit5)
                            alu_control = SRA;
                        else
                            alu_control = SRL;
                    end
                    3'b110: alu_control = OR;   // ORI
                    3'b111: alu_control = AND;  // ANDI
                    default: alu_control = ADD; // Default
                endcase
            end

            // Case 4: R-type instructions -> Decode based on funct3 and funct7
            2'b10: begin
                case (funct3)
                    3'b000: begin // ADD / SUB
                        if (funct7_bit5)
                            alu_control = SUB;
                        else
                            alu_control = ADD;
                    end
                    3'b001: alu_control = SLL;
                    3'b010: alu_control = SLT;
                    3'b011: alu_control = SLTU;
                    3'b100: alu_control = XOR;
                    3'b101: begin // SRL / SRA
                        if (funct7_bit5)
                            alu_control = SRA;
                        else
                            alu_control = SRL;
                    end
                    3'b110: alu_control = OR;
                    3'b111: alu_control = AND;
                    default: alu_control = ADD; // Default
                endcase
            end
            default: alu_control = ADD; // Default
        endcase
    end
endmodule
