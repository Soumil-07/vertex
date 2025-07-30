module ex_mem (
    input wire      clk_i,
                    rstn_i,

    input wire [31:0] pc_i,
    input wire alu_src1_i,
    input wire alu_src2_i,
    input wire [1:0] alu_op_i,
    input wire [2:0] funct3_i,
    input wire [6:0] funct7_i,
    input wire [31:0] rs1_val_i,
    input wire [31:0] rs2_val_i,
    input wire [31:0] imm_i,
    input wire [4:0] rd_i,
    input wire        is_branch_i,
    input wire        mem_read_i,
    input wire        mem_write_i,
    input wire        mem_to_reg_i,
    input wire        reg_write_i,
                    
    output reg [31:0] pc_o,
    // RS2 needs to be passed to MEM for store operations
    output reg [31:0] rs2_val_o,
    // RD needs to be passed to WB for write-back
    output reg [4:0] rd_o,
    // forward mem and write-back control signals
    output reg mem_read_o,
    output reg mem_write_o,
    output reg mem_to_reg_o,
    output reg reg_write_o,
    output reg funct3_o,

    // ALU control and data signals
    output reg [31:0] out_o,
    output wire zero_flag_o,
    output wire carry_flag_o,
    output wire sign_flag_o,
    output wire overflow_flag_o,
    output reg branch_taken_o
);

wire [31:0] alu_result;
wire [3:0] alu_control;
wire branch_taken;

alu_control alu_ctrl_inst (
    .alu_op(alu_op_i),
    .funct3(funct3_i),
    .funct7_bit5(funct7_i[5]),
    .alu_control(alu_control)
);

alu_top alu_inst (
    .instr_i(alu_control),
    .src1_i(alu_src1_i ? pc_i : rs1_val_i),
    .src2_i(alu_src2_i ? imm_i : rs2_val_i),
    .result_o(alu_result),
    .zero_flag_o(alu_zero_flag_o),
    .carry_flag_o(alu_carry_flag_o),
    .sign_flag_o(alu_sign_flag_o),
    .overflow_flag_o(alu_overflow_flag_o)
);

branch_control branch_ctrl_inst (
    .funct3_i(funct3_i),
    .zero_flag_i(alu_zero_flag_o),
    .sign_flag_i(alu_sign_flag_o),
    .carry_flag_i(alu_carry_flag_o),
    .overflow_flag_i(alu_overflow_flag_o),
    .branch_taken_o(branch_taken)
);

always @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc_o <= 0;
        out_o <= 0;
        branch_taken_o <= 0;
        rs2_val_o <= 0;
        rd_o <= 0;
        mem_read_o <= 0;
        mem_write_o <= 0;
        mem_to_reg_o <= 0;
        reg_write_o <= 0;
        funct3_o <= 0;
    end else begin
        pc_o <= pc_i;
        out_o <= alu_result;
        branch_taken_o <= is_branch_i && branch_taken;
        rs2_val_o <= rs2_val_i; // Pass RS2 value for store operations
        rd_o <= rd_i;
        mem_read_o <= mem_read_i;
        mem_write_o <= mem_write_i;
        mem_to_reg_o <= mem_to_reg_i;
        reg_write_o <= reg_write_i;
        funct3_o <= funct3_i; // Pass funct3 for memory access
    end 
end

endmodule
