module id_ex (
    input wire          clk_i,
                        rstn_i,
    input wire [31:0]   pc_i,
    input wire [31:0]   instr_i,

    output reg [31:0]   pc_o,
    output reg [6:0]    opcode_o,
    output reg [11:7]   rd_o,
    output reg [14:12]  funct3_o,
    output reg [19:15]  rs1_o,
    output reg [24:20]  rs2_o,
    output reg [31:25]  funct7_o,
    output reg [31:0]   imm_o,

    output reg          alu_src1_o,
    output reg          alu_src2_o,
    output reg [1:0]    alu_op_o,
    output reg          mem_read_o,
    output reg          mem_write_o,
    output reg          mem_to_reg_o,
    output reg          reg_write_o,
    output reg          is_branch_o
);

reg [31:0]   pc_next;
reg [6:0]    opcode_next;
reg [11:7]   rd_next;
reg [14:12]  funct3_next;
reg [19:15]  rs1_next;
reg [24:20]  rs2_next;
reg [31:25]  funct7_next;
reg [31:0]   imm_next;

reg [1:0]    alu_op_next;
reg          alu_src1_next;
reg          alu_src2_next;
reg [1:0]    alu_nextp_next;
reg          mem_read_next;
reg          mem_write_next;
reg          mem_to_reg_next;
reg          reg_write_next;
reg          is_branch_next;

wire [31:0]  rs1_val_next;
wire [31:0]  rs2_val_next;

always @(*) begin
    case (instr_i[6:0])
        7'b0110011: begin // R-type
            imm_next = 0; // no immediate for R-type
        end
        7'b0010011,
        7'b0000011: begin // I-type (load and ALU-immediate)
            imm_next = {{20{instr_i[31]}}, instr_i[31:20]};
        end
        7'b0100011: begin // S-type (store)
            imm_next = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        end
        7'b1100011: begin // B-type (branch)
            imm_next = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
        end
        7'b1101111: begin // J-type (jal)
            imm_next = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
        end
        7'b1100111: begin // I-type (jalr)
            imm_next = {{20{instr_i[31]}}, instr_i[31:20]};
        end
        7'b0010111,
        7'b0110111: begin // U-type (lui)
            imm_next = {instr_i[31:12], 12'b0};
        end
        default: begin
            imm_next = 0; // default case, should not happen
        end
    endcase
end

// Selects the first ALU operand (ALUSrc1)
always @(*) begin
    case (instr_i[6:0])
        7'b1101111, // JAL
        7'b1100111, // JALR
        7'b0010111: // AUIPC
            alu_src1_next = 1; // Use PC
        default:
            alu_src1_next = 0; // Use rs1
    endcase
end

// Selects the second ALU operand (ALUSrc2)
always @(*) begin
    case (instr_i[6:0])
        7'b0010011, // I-type (ALU-imm)
        7'b0000011, // I-type (load)
        7'b1100111, // I-type (jalr)
        7'b0100011, // S-type (store)
        7'b0110111, // U-type (lui)
        7'b0010111: // U-type (auipc)
            alu_src2_next = 1; // Use immediate
        default:
            alu_src2_next = 0; // Use rs2
    endcase
end

// Select the ALU operation (ALUOp)
always @(*) begin
    case (instr_i[6:0])
        // These instr_iuctions all perform a simple ADD in the main ALU
        7'b0000011: alu_op_next = 2'b00; // Load (rs1 + imm)
        7'b0100011: alu_op_next = 2'b00; // Store (rs1 + imm)
        7'b0110111: alu_op_next = 2'b00; // LUI (0 + imm)
        7'b0010111: alu_op_next = 2'b00; // AUIPC (PC + imm)
        7'b1101111: alu_op_next = 2'b00; // JAL (PC + 4)
        7'b1100111: alu_op_next = 2'b00; // JALR (PC + 4)

        // This is for branch comparisons
        7'b1100011: alu_op_next = 2'b01; // Branch (rs1 - rs2)

        // This requires decoding funct3/funct7
        7'b0110011: alu_op_next = 2'b10; // R-type

        // This requires decoding funct3
        7'b0010011: alu_op_next = 2'b11; // I-type (ALU-imm)

        default:    alu_op_next = 2'b00; // Default to ADD
    endcase
end

// Branch detection
always @(*) begin
    is_branch_next = (instr_i[6:0] == 7'b1100011);
end

// Control signals for memory and write-back
always @(*) begin
    // Start with defaults for the most common case (R-type/I-type ALU ops)
    mem_read_next   = 1'b0;
    mem_write_next = 1'b0;
    mem_to_reg_next= 1'b0; // Data comes from ALU
    reg_write_next = 1'b1; // Most instr_iuctions write to a register

    case (instr_i[6:0])
        7'b0000011: begin // Load
            mem_read_next  = 1'b1;
            mem_to_reg_next= 1'b1; // Data comes from Memory
        end
        7'b0100011: begin // Store
            mem_write_next= 1'b1;
            reg_write_next= 1'b0; // Override default: Stores don't write to registers
        end
        7'b1100011: begin // Branch
            reg_write_next = 1'b0; // Override default: Branches don't write to registers
        end
    endcase
end


always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc_o          <= 0;
        opcode_o      <= 0;
        rd_o          <= 0;
        funct3_o      <= 0;
        rs1_o         <= 0;
        rs2_o         <= 0;
        funct7_o      <= 0;
        imm_o         <= 0;

        alu_src1_o    <= 0;
        alu_src2_o    <= 0;
        alu_op_o      <= 0;
        mem_read_o    <= 0;
        mem_write_o   <= 0;
        mem_to_reg_o  <= 0;
        reg_write_o   <= 0;
        is_branch_o   <= 0;

    end else begin
        pc_o          <= pc_i;
        opcode_o      <= instr_i[6:0];
        rd_o          <= instr_i[11:7];
        funct3_o      <= instr_i[14:12];
        rs1_o         <= instr_i[19:15];
        rs2_o         <= instr_i[24:20];
        funct7_o      <= instr_i[31:25];
        imm_o         <= imm_next;

        alu_src1_o    <= alu_src1_next;
        alu_src2_o    <= alu_src2_next;
        alu_op_o      <= alu_op_next;
        mem_read_o    <= mem_read_next;
        mem_write_o   <= mem_write_next;
        mem_to_reg_o  <= mem_to_reg_next;
        reg_write_o   <= reg_write_next;
        is_branch_o   <= is_branch_next;
    end
end

endmodule
