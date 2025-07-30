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

assign pc_next = id_ex_is_branch && ex_mem_branch_taken ? 
                 id_ex_pc + id_ex_imm : // Branch taken, use PC + immediate
                 pc + 4; // Normal increment

// stage 1: instruction fetch
// keep this in the top-level because it's a PITA to keep
// flattening/unflattening the memory in and out of modules
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
wire [31:0] id_ex_pc;
wire [6:0] id_ex_opcode;
wire [11:7] id_ex_rd;
wire [14:12] id_ex_funct3;
wire [19:15] id_ex_rs1;
wire [24:20] id_ex_rs2;
wire [31:25] id_ex_funct7;
wire [31:0] id_ex_imm, id_ex_imm_next;

// ALU control signals
// ALUSrc1 can be rs1 or pc (for JALR/AUIPC/JAL)
wire id_ex_alu_src1, id_ex_alu_src1_next;
// ALUSrc2 can be rs2 or immediate (for I-type, S-type, and B-type)
wire id_ex_alu_src2, id_ex_alu_src2_next;
// ALUOp is a coarse 2-bit control signal for the ALU operation
// 00 -> load/store, 01 -> branch, 10 -> R-type, 11 -> ALU immediate
wire [1:0] id_ex_alu_op, id_ex_alu_op_next;

// Memory and writeback control signals are passed along to MEM and WB 
wire id_ex_mem_read, id_ex_mem_read_next; 
wire id_ex_mem_write, id_ex_mem_write_next;
wire id_ex_mem_to_reg, id_ex_mem_to_reg_next; // Write memory data to register file
wire id_ex_reg_write, id_ex_reg_write_next; // Write to register file

// Branch control signals
wire id_ex_is_branch, id_ex_is_branch_next;

// register read
wire [31:0] id_ex_rs1_val, id_ex_rs2_val;

id_ex id_ex_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .pc_i(if_id_pc),
    .instr_i(if_id_instr),
    .pc_o(id_ex_pc),
    .opcode_o(id_ex_opcode),
    .rd_o(id_ex_rd),
    .funct3_o(id_ex_funct3),
    .rs1_o(id_ex_rs1),
    .rs2_o(id_ex_rs2),
    .funct7_o(id_ex_funct7),
    .imm_o(id_ex_imm),
    .alu_src1_o(id_ex_alu_src1),
    .alu_src2_o(id_ex_alu_src2),
    .alu_op_o(id_ex_alu_op),
    .mem_read_o(id_ex_mem_read),
    .mem_write_o(id_ex_mem_write),
    .mem_to_reg_o(id_ex_mem_to_reg),
    .reg_write_o(id_ex_reg_write),
    .is_branch_o(id_ex_is_branch)
);

assign id_ex_rs1_val = id_ex_rs1 == 0 ? 0 : reg_file[id_ex_rs1];
assign id_ex_rs2_val = id_ex_rs2 == 0 ? 0 : reg_file[id_ex_rs2];

// stage 3: execute
wire [31:0] ex_mem_pc;
wire [31:0] ex_mem_out;
wire ex_mem_branch_taken;
// RS2 needs to be passed to MEM for store operations
wire [31:0] ex_mem_rs2_val;
// RD needs to be passed to WB for write-back
wire [4:0] ex_mem_rd;
// forward mem and write-back control signals
wire ex_mem_mem_read;
wire ex_mem_mem_write;
wire ex_mem_mem_to_reg;
wire ex_mem_reg_write;
wire ex_mem_funct3;

// ALU control and data signals
wire [3:0] alu_control;
wire [31:0] alu_result;
wire alu_zero_flag, alu_carry_flag, alu_sign_flag, alu_overflow_flag;

ex_mem ex_mem_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .pc_i(id_ex_pc),
    .alu_src1_i(id_ex_alu_src1),
    .alu_src2_i(id_ex_alu_src2),
    .alu_op_i(id_ex_alu_op),
    .funct3_i(id_ex_funct3),
    .funct7_i(id_ex_funct7),
    .rs1_val_i(id_ex_rs1_val),
    .rs2_val_i(id_ex_rs2_val),
    .imm_i(id_ex_imm),
    .rd_i(id_ex_rd),
    .is_branch_i(id_ex_is_branch),
    .mem_read_i(id_ex_mem_read),
    .mem_write_i(id_ex_mem_write),
    .mem_to_reg_i(id_ex_mem_to_reg),
    .reg_write_i(id_ex_reg_write),
    
    // Outputs
    .pc_o(ex_mem_pc),
    .rs2_val_o(ex_mem_rs2_val),
    .rd_o(ex_mem_rd),
    .mem_read_o(ex_mem_mem_read),
    .mem_write_o(ex_mem_mem_write),
    .mem_to_reg_o(ex_mem_mem_to_reg),
    .reg_write_o(ex_mem_reg_write),
    .funct3_o(ex_mem_funct3),

    // ALU control and data signals
    .out_o(ex_mem_out), // ALU result
    .zero_flag_o(alu_zero_flag), // Zero flag
    .carry_flag_o(alu_carry_flag), // Carry flag
    .sign_flag_o(alu_sign_flag), // Sign flag
    .overflow_flag_o(alu_overflow_flag), // Overflow flag
    .branch_taken_o(ex_mem_branch_taken) // Branch taken signal
);

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
