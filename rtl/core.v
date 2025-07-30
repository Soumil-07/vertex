module core (
    // TODO: this is a very small memory scratchpad
    input wire [8191:0] mem_i,
    input wire clk_i, rstn_i
);

reg [7:0] data_memory [1023:0];
reg [31:0] pc;
wire [31:0] pc_next;

// register file
reg [31:0] reg_file [31:0];

genvar i;
generate
for (i = 0; i < 1024; i = i + 1) begin : unflatten_memory
always @(*) begin
        // Unflatten the memory input into bytes
        data_memory[i] = mem_i[i*8 +: 8];
end
end
endgenerate

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc <= 0;
    end else begin
        pc <= pc_next;
    end
end

assign pc_next = id_ex_is_branch && branch_taken ? 
                 id_ex_pc + id_ex_imm : // Branch taken, use PC + immediate
                 pc + 4; // Normal increment

// stage 1: instruction fetch
reg [31:0] if_id_pc;
reg [31:0] if_id_instr;

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        if_id_pc <= 0;
        if_id_instr <= 0;
    end else begin
        if_id_pc <= pc;
        if_id_instr <= {data_memory[pc + 3], data_memory[pc + 2], data_memory[pc + 1], data_memory[pc]};
    end
end

// stage 2: instruction decode
reg [31:0] id_ex_pc;
reg [6:0] id_ex_opcode;
reg [11:7] id_ex_rd;
reg [14:12] id_ex_funct3;
reg [19:15] id_ex_rs1;
reg [24:20] id_ex_rs2;
reg [31:25] id_ex_funct7;
reg [31:0] id_ex_imm, id_ex_imm_next;

// ALU control signals
// ALUSrc1 can be rs1 or pc (for JALR/AUIPC/JAL)
reg id_ex_alu_src1, id_ex_alu_src1_next;
// ALUSrc2 can be rs2 or immediate (for I-type, S-type, and B-type)
reg id_ex_alu_src2, id_ex_alu_src2_next;
// ALUOp is a coarse 2-bit control signal for the ALU operation
// 00 -> load/store, 01 -> branch, 10 -> R-type, 11 -> ALU immediate
reg [1:0] id_ex_alu_op, id_ex_alu_op_next;

// Memory and writeback control signals are passed along to MEM and WB 
reg id_ex_mem_read, id_ex_mem_read_next; 
reg id_ex_mem_write, id_ex_mem_write_next;
reg id_ex_mem_to_reg, id_ex_mem_to_reg_next; // Write memory data to register file
reg id_ex_reg_write, id_ex_reg_write_next; // Write to register file

// Branch control signals
reg id_ex_is_branch, id_ex_is_branch_next;

// register read
wire [31:0] id_ex_rs1_val, id_ex_rs2_val;

always @(*) begin
    case (if_id_instr[6:0])
        7'b0110011: begin // R-type
            id_ex_imm_next = 0; // no immediate for R-type
        end
        7'b0010011,
        7'b0000011: begin // I-type (load and ALU-immediate)
            id_ex_imm_next = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
        end
        7'b0100011: begin // S-type (store)
            id_ex_imm_next = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
        end
        7'b1100011: begin // B-type (branch)
            id_ex_imm_next = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};
        end
        7'b1101111: begin // J-type (jal)
            id_ex_imm_next = {{12{if_id_instr[31]}}, if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21], 1'b0};
        end
        7'b1100111: begin // I-type (jalr)
            id_ex_imm_next = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
        end
        7'b0010111,
        7'b0110111: begin // U-type (lui)
            id_ex_imm_next = {if_id_instr[31:12], 12'b0};
        end
        default: begin
            id_ex_imm_next = 0; // default case, should not happen
        end
    endcase
end

// Selects the first ALU operand (ALUSrc1)
always @(*) begin
    case (if_id_instr[6:0])
        7'b1101111, // JAL
        7'b1100111, // JALR
        7'b0010111: // AUIPC
            id_ex_alu_src1_next = 1; // Use PC
        default:
            id_ex_alu_src1_next = 0; // Use rs1
    endcase
end

// Selects the second ALU operand (ALUSrc2)
always @(*) begin
    case (if_id_instr[6:0])
        7'b0010011, // I-type (ALU-imm)
        7'b0000011, // I-type (load)
        7'b1100111, // I-type (jalr)
        7'b0100011, // S-type (store)
        7'b0110111, // U-type (lui)
        7'b0010111: // U-type (auipc)
            id_ex_alu_src2_next = 1; // Use immediate
        default:
            id_ex_alu_src2_next = 0; // Use rs2
    endcase
end

// Select the ALU operation (ALUOp)
always @(*) begin
    case (if_id_instr[6:0])
        // These instructions all perform a simple ADD in the main ALU
        7'b0000011: id_ex_alu_op_next = 2'b00; // Load (rs1 + imm)
        7'b0100011: id_ex_alu_op_next = 2'b00; // Store (rs1 + imm)
        7'b0110111: id_ex_alu_op_next = 2'b00; // LUI (0 + imm)
        7'b0010111: id_ex_alu_op_next = 2'b00; // AUIPC (PC + imm)
        7'b1101111: id_ex_alu_op_next = 2'b00; // JAL (PC + 4)
        7'b1100111: id_ex_alu_op_next = 2'b00; // JALR (PC + 4)

        // This is for branch comparisons
        7'b1100011: id_ex_alu_op_next = 2'b01; // Branch (rs1 - rs2)

        // This requires decoding funct3/funct7
        7'b0110011: id_ex_alu_op_next = 2'b10; // R-type

        // This requires decoding funct3
        7'b0010011: id_ex_alu_op_next = 2'b11; // I-type (ALU-imm)

        default:    id_ex_alu_op_next = 2'b00; // Default to ADD
    endcase
end

// Branch detection
always @(*) begin
    id_ex_is_branch_next = (if_id_instr[6:0] == 7'b1100011);
end

// Control signals for memory and write-back
always @(*) begin
    // Start with defaults for the most common case (R-type/I-type ALU ops)
    id_ex_mem_read_next   = 1'b0;
    id_ex_mem_write_next = 1'b0;
    id_ex_mem_to_reg_next= 1'b0; // Data comes from ALU
    id_ex_reg_write_next = 1'b1; // Most instructions write to a register

    case (if_id_instr[6:0])
        7'b0000011: begin // Load
            id_ex_mem_read_next  = 1'b1;
            id_ex_mem_to_reg_next= 1'b1; // Data comes from Memory
        end
        7'b0100011: begin // Store
            id_ex_mem_write_next= 1'b1;
            id_ex_reg_write_next= 1'b0; // Override default: Stores don't write to registers
        end
        7'b1100011: begin // Branch
            id_ex_reg_write_next = 1'b0; // Override default: Branches don't write to registers
        end
    endcase
end

assign id_ex_rs1_val = id_ex_rs1 == 0 ? 0 : reg_file[id_ex_rs1];
assign id_ex_rs2_val = id_ex_rs2 == 0 ? 0 : reg_file[id_ex_rs2];

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        id_ex_pc <= 0;
        id_ex_opcode <= 0;
        id_ex_rd <= 0;
        id_ex_funct3 <= 0;
        id_ex_rs1 <= 0;
        id_ex_rs2 <= 0;
        id_ex_funct7 <= 0;
        id_ex_imm <= 0;
        id_ex_alu_src1 <= 0;
        id_ex_alu_src2 <= 0;
        id_ex_alu_op <= 0;
        id_ex_mem_read <= 0;
        id_ex_mem_write <= 0;
        id_ex_mem_to_reg <= 0;
        id_ex_reg_write <= 0;
        id_ex_is_branch <= 0;
    end else begin
        id_ex_pc <= if_id_pc;
        id_ex_opcode <= if_id_instr[6:0];
        id_ex_rd <= if_id_instr[11:7];
        id_ex_funct3 <= if_id_instr[14:12];
        id_ex_rs1 <= if_id_instr[19:15];
        id_ex_rs2 <= if_id_instr[24:20];
        id_ex_funct7 <= if_id_instr[31:25];
        
        // immediate generation
        id_ex_imm <= id_ex_imm_next;

        // ALU control signals
        id_ex_alu_src1 <= id_ex_alu_src1_next;
        id_ex_alu_src2 <= id_ex_alu_src2_next;
        id_ex_alu_op <= id_ex_alu_op_next;

        // Memory and write-back control signals
        id_ex_mem_read <= id_ex_mem_read_next;
        id_ex_mem_write <= id_ex_mem_write_next;
        id_ex_mem_to_reg <= id_ex_mem_to_reg_next;
        id_ex_reg_write <= id_ex_reg_write_next;

        // Branch control signal 
        id_ex_is_branch <= id_ex_is_branch_next;
    end
end

// stage 3: execute
reg [31:0] ex_mem_pc;
reg [31:0] ex_mem_out;
reg ex_mem_branch_taken;
// RS2 needs to be passed to MEM for store operations
reg [31:0] ex_mem_rs2_val;
// RD needs to be passed to WB for write-back
reg [4:0] ex_mem_rd;
// forward mem and write-back control signals
reg ex_mem_mem_read;
reg ex_mem_mem_write;
reg ex_mem_mem_to_reg;
reg ex_mem_reg_write;
reg ex_mem_funct3;

// ALU control and data signals
wire [3:0] alu_control;
wire [31:0] alu_result;
wire alu_zero_flag, alu_carry_flag, alu_sign_flag, alu_overflow_flag;

// generate final control signals for the ALU
alu_control alu_ctrl_inst (
    .alu_op(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7_bit5(id_ex_funct7[5]),
    .alu_control(alu_control)
);

alu_top alu_inst (
    .instr_i(alu_control),
    .src1_i(id_ex_alu_src1 ? id_ex_pc : id_ex_rs1_val),
    .src2_i(id_ex_alu_src2 ? id_ex_imm : id_ex_rs2_val),
    .result_o(alu_result),
    .zero_flag_o(alu_zero_flag),
    .carry_flag_o(alu_carry_flag),
    .sign_flag_o(alu_sign_flag),
    .overflow_flag_o(alu_overflow_flag)
);

wire branch_taken;

branch_control branch_ctrl_inst (
    .funct3_i(id_ex_funct3),
    .zero_flag_i(alu_zero_flag),
    .sign_flag_i(alu_sign_flag),
    .carry_flag_i(alu_carry_flag),
    .overflow_flag_i(alu_overflow_flag),
    .branch_taken_o(branch_taken)
);

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        ex_mem_pc <= 0;
        ex_mem_out <= 0;
        ex_mem_branch_taken <= 0;
        ex_mem_rs2_val <= 0;
        ex_mem_rd <= 0;
        ex_mem_mem_read <= 0;
        ex_mem_mem_write <= 0;
        ex_mem_mem_to_reg <= 0;
        ex_mem_reg_write <= 0;
        ex_mem_funct3 <= 0;
    end else begin
        ex_mem_pc <= id_ex_pc;
        ex_mem_out <= alu_result;
        ex_mem_branch_taken <= id_ex_is_branch && branch_taken;
        ex_mem_rs2_val <= id_ex_rs2_val; // Pass RS2 value for store operations
        ex_mem_rd <= id_ex_rd;
        ex_mem_mem_read <= id_ex_mem_read;
        ex_mem_mem_write <= id_ex_mem_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_reg_write <= id_ex_reg_write;
        ex_mem_funct3 <= id_ex_funct3; // Pass funct3 for memory access
    end 
end

// stage 4: memory access
reg [31:0] mem_wb_pc;
reg [4:0]  mem_wb_rd;
reg [31:0] mem_wb_out, mem_wb_out_next;
reg        mem_wb_reg_write;

// Internal wire for the raw word read from memory
wire [31:0] mem_word;
// Internal reg for the processed data after byte/half/word selection
reg  [31:0] mem_read;

// Read the 32-bit word from memory model
assign mem_word = {data_memory[ex_mem_out[31:2] * 4 + 3],
                   data_memory[ex_mem_out[31:2] * 4 + 2],
                   data_memory[ex_mem_out[31:2] * 4 + 1],
                   data_memory[ex_mem_out[31:2] * 4 + 0]};

// This block contains all the combinational logic for the MEM stage
always @(*) begin
    // Default to an unknown value for clarity in simulation
    mem_read = 32'dx;

    if (ex_mem_mem_read) begin
        case (ex_mem_funct3)
            3'b010: // lw (load word)
                mem_read = mem_word;

            3'b000: // lb (load byte)
                case (ex_mem_out[1:0])
                    2'b00: mem_read = {{24{mem_word[7]}},  mem_word[7:0]};
                    2'b01: mem_read = {{24{mem_word[15]}}, mem_word[15:8]};
                    2'b10: mem_read = {{24{mem_word[23]}}, mem_word[23:16]};
                    2'b11: mem_read = {{24{mem_word[31]}}, mem_word[31:24]};
                endcase

            3'b100: // lbu (load byte unsigned)
                case (ex_mem_out[1:0])
                    2'b00: mem_read = {24'b0, mem_word[7:0]};
                    2'b01: mem_read = {24'b0, mem_word[15:8]};
                    2'b10: mem_read = {24'b0, mem_word[23:16]};
                    2'b11: mem_read = {24'b0, mem_word[31:24]};
                endcase

            3'b001: // lh (load half-word)
                if (ex_mem_out[1] == 1'b0)
                    mem_read = {{16{mem_word[15]}}, mem_word[15:0]};
                else
                    mem_read = {{16{mem_word[31]}}, mem_word[31:16]};

            3'b101: // lhu (load half-word unsigned)
                if (ex_mem_out[1] == 1'b0)
                    mem_read = {16'b0, mem_word[15:0]};
                else
                    mem_read = {16'b0, mem_word[31:16]};
        endcase
    end

    // This mux selects the final data to be passed to the Write-Back stage
    mem_wb_out_next = ex_mem_mem_to_reg ? mem_read : ex_mem_out;
end

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        mem_wb_pc <= 0;
        mem_wb_rd <= 0;
        mem_wb_out <= 0;
        mem_wb_reg_write <= 0;
    end else begin
        mem_wb_pc <= ex_mem_pc;
        mem_wb_rd <= ex_mem_rd;
        mem_wb_out <= mem_wb_out_next;
        mem_wb_reg_write <= ex_mem_reg_write;
    end
end

// store logic for MEM stage 
always @(posedge clk_i) begin
    // Check if the instruction currently in the MEM stage is a store
    if (ex_mem_mem_write) begin
        case (ex_mem_funct3)
            3'b000: // sb (store byte)
                data_memory[ex_mem_out] <= ex_mem_rs2_val[7:0];

            3'b001: // sh (store half-word)
                begin
                    data_memory[ex_mem_out]   <= ex_mem_rs2_val[7:0];
                    data_memory[ex_mem_out+1] <= ex_mem_rs2_val[15:8];
                end

            3'b010: // sw (store word)
                begin
                    data_memory[ex_mem_out]   <= ex_mem_rs2_val[7:0];
                    data_memory[ex_mem_out+1] <= ex_mem_rs2_val[15:8];
                    data_memory[ex_mem_out+2] <= ex_mem_rs2_val[23:16];
                    data_memory[ex_mem_out+3] <= ex_mem_rs2_val[31:24];
                end
        endcase
    end
end


// stage 5: write-back
always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        // Reset state
        // Nothing for now
    end else begin
        // Write back to the register file if needed
        if (mem_wb_reg_write && mem_wb_rd != 0) begin
            reg_file[mem_wb_rd] <= mem_wb_out;
        end
    end
end

endmodule
