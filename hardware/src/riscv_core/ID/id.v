
`include "../defines.vh"
`include "../Opcode.vh"
/*
*   TODO:
*   id stage file, connect to id_ex
*   @OUTPUT:
*   reg1_data
*   reg2_data
*   imm
*   wb_addr
*   alu_op
*   //write_back enable
*   
*/

module id (
    input wire[`IMEM_DBUS]      inst_i,
    input wire[`REG_DBUS]       pc_data_i,    

    // reg data from regfile
    input wire[`REG_DBUS] reg1_data_i,
    input wire[`REG_DBUS] reg2_data_i,
    // reg addr to regfile
    output wire[`REG_ABUS] reg1_addr_o,
    output wire[`REG_ABUS] reg2_addr_o,

    output wire[`WORD_BUS]     branch_addr_o,

// data to id_ex
    output wire [2:0]                funct3_o,

    output wire[`REG_DBUS]      pc_data_o,
    output wire[`REG_DBUS]      pc_plus_o,

    output wire[`IMM32_BUS]     imm_o,
    output wire[`REG_ABUS]      rd_addr_o,
    output wire[`REG_ABUS]      rs1_addr_o,
    output wire[`REG_ABUS]      rs2_addr_o,
    output wire[`REG_DBUS]      reg1_data_o,
    output wire[`REG_DBUS]      reg2_data_o,

    output [1:0] control_forward_o,
    output [1:0] control_jump_o,
    output [1:0] control_uart_o, //TODO
    output control_dmem_o,
    output [1:0] control_wr_mux_o,
    output control_csr_we_o,
    output [2:0] control_load_o,
    output control_wb_o,
    output control_branch_o,
    output [3:0] alu_ctrl_o
);

    // decocde
    wire[`REG_ABUS] inst_rd, inst_rs1, inst_rs2;
    wire[`FIELD_OPCODE] inst_opcode;

    assign  inst_rd     = inst_i[`FIELD_RD],
            inst_rs1    = inst_i[`FIELD_RS1],
            inst_rs2    = inst_i[`FIELD_RS2],
            inst_opcode = inst_i[`FIELD_OPCODE];

    assign  funct3_o        = inst_i[`FIELD_FUNCT3],
            inst_alu30_o    = inst_i[30]; 

    assign  rs1_addr_o   = inst_rs1,
            rs2_addr_o   = inst_rs2,
            rd_addr_o    = inst_rd;
        

    // next pc
    assign pc_data_o = pc_data_i;
    assign pc_plus_o = pc_data_i + 4;


    // reg_file

    assign  reg1_addr_o = inst_rs1,
            reg2_addr_o = inst_rs2;

    assign  reg1_data_o = reg1_data_i,
            reg2_data_o = reg2_data_i;    
    

    // control_unit
    wire control_branch;
    wire [1:0] alu_op_o;
    control_unit control (
        .opcode(inst_opcode),
        .funct3_i(inst_i[`FIELD_FUNCT3]),
        .control_jump(control_jump_o),
        .control_forward(control_forward_o),
        .alu_op(alu_op_o),
        .control_uart(control_uart_o),
        .control_dmem(control_dmem_o),
        .control_branch(control_branch_o),
        .control_wr_mux(control_wr_mux_o),
        .control_csr_we(control_csr_we_o),
        .control_load(control_load_o),
        .control_wb(control_wb_o));

    // imm_gen
    wire [31:0] branch_offset_o;

    wire [2:0] funct3_in = inst_i[14:12];
    imm_gen imm (
        .opcode_i(inst_i),
        .funct_i(funct3_in),
        .imm(imm_o),
        .branch_offset(branch_offset_o));

    assign branch_addr_o = branch_offset_o + pc_data_o;

    alu_control alu_control(
        .inst_alu(funct3_in),
        .inst_alu30(inst_i[30]),
        .aluOp(alu_op_o),
        .aluCtrl(alu_ctrl_o));

endmodule
