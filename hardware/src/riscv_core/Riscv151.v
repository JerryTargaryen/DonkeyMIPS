`include "defines.vh"
`include "Opcode.vh"
`include "EX/ex_wb.v"
`include "EX/ex.v"
`include "../EECS151.v"
`include "WB/wb.v"
`include "EX/alu_control.v"
`include "EX/forwarding_unit.v"
`include "EX/alu.v"
`include "ID/control_unit.v"
`include "ID/id_ex.v"
`include "ID/imm_gen.v"
`include "ID/id.v"

module Riscv151
#(
    parameter CPU_CLOCK_FREQ    = 50_000_000,
    parameter RESET_PC          = 32'h4000_0000,
    parameter BAUD_RATE         = 115200,
    parameter BIOS_MEM_HEX_FILE = "bios151v3.mif"
)
(
    input  clk,
    input  rst,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,
    output [31:0] csr
);

/*
    parameter CPU_CLOCK_FREQ    = 50_000_000;
    parameter RESET_PC          = 32'h4000_0000;
    parameter BAUD_RATE         = 115200;
    parameter BIOS_MEM_HEX_FILE = "bios151v3.mif";*/
    // Memories
    //-----------first stage----------------//
    localparam BIOS_AWIDTH = 12;
    localparam BIOS_DWIDTH  = 32;
    localparam BIOS_DEPTH  = 4096;

    wire [BIOS_AWIDTH-1:0] bios_addra, bios_addrb;
    wire [BIOS_DWIDTH-1:0] bios_douta, bios_doutb;

    wire [31:0] pc_in;
    wire [31:0] pc_plus;
    wire [31:0] jal_addr;
    wire jump_judge;
    wire [31:0] branch_addr;

    mux_pc mux_pc(
        .pc_plus(pc_plus),
        .jal_addr(jal_addr),
        .branch_addr(branch_addr),
        .jump_judge(jump_judge),
        .pc_in(pc_in));

    wire [31:0] pc_store;
    wire [31:0] pc_output;

    REGISTER_R #(.N(32), .INIT(RESET_PC)) pc_reg(
        .clk(clk),
        .q(pc_store),
        .d(pc_in),
        .rst(rst));

    // BIOS Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    XILINX_SYNC_RAM_DP #(
        .AWIDTH(BIOS_AWIDTH),
        .DWIDTH(BIOS_DWIDTH),
        .DEPTH(BIOS_DEPTH),
        .MEM_INIT_HEX_FILE(BIOS_MEM_HEX_FILE)
    ) bios_mem(
        .q0(bios_douta),    // output
        .d0(),              // intput
        .addr0(bios_addra), // input
        .we0(1'b0),         // input
        .q1(bios_doutb),    // output
        .d1(),              // input
        .addr1(bios_addrb), // input
        .we1(1'b0),         // input
        .clk(clk), .rst(rst));

    localparam IMEM_AWIDTH = 14;
    localparam IMEM_DWIDTH = 32;
    localparam IMEM_DEPTH = 16384;

    wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
    wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
    wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
    wire [3:0] imem_wea, imem_web;

    // Instruction Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    // Byte addressable: select which of the four bytes to write
    XILINX_SYNC_RAM_DP #(
        .AWIDTH(IMEM_AWIDTH),
        .DWIDTH(IMEM_DWIDTH),
        .DEPTH(IMEM_DEPTH)
    ) imem (
        .q0(imem_douta),    // output
        .d0(imem_dina),     // input
        .addr0(imem_addra), // input
        .we0(imem_wea),    // input
        .q1(imem_doutb),    // output
        .d1(imem_dinb),     // input
        .addr1(imem_addrb), // input
        .we1(imem_web),    // input
        .clk(clk), .rst(rst));

    assign bios_addra = pc_in[11:0];
    assign imem_addra = pc_in[13:0];
    
    wire if_flush = jump_judge;

//-----------second stage----------------//
    wire [31:0] inst_output;

    mux_imem_read mux_imem_read(
        .imem_out(imem_douta),
        .bios_out(bios_douta),
        .pc30(1),
        .inst_output(inst_output));
    
    wire [31:0] imm_out;
    
    // imm_gen imm_gen(
    //     .opcode_i(inst_output),
    //     .imm(imm_out));

    wire rf_we;
    wire [4:0]  rf_ra1, rf_ra2, rf_wa;
    wire [31:0] rf_wd;
    wire [31:0] rf_rd1, rf_rd2;

    wire [4:0] wb_addr;
    // assign rf_ra1 = inst_output[19:15];
    // assign rf_ra2 = inst_output[24:20];
    assign rf_we = 1'b1;

    wire [`REG_DBUS] reg1_data_reg;
    wire [`REG_ABUS] reg1_addr_reg;
    wire [`REG_DBUS] reg2_data_reg;
    wire [`REG_ABUS] reg2_addr_reg;

    wire inst_alu30_reg;
    wire [2:0] inst_alu_reg;

    wire [`REG_DBUS]    pc_data_reg;
    wire [`REG_DBUS]    pc_plus_reg;

    wire [1:0] control_forward_reg;
    wire control_dmem_reg;
    wire [1:0] control_jump_reg;    
    wire [1:0] aluOp_reg;
    wire control_uart_reg;
    wire [1:0] control_wr_mux_reg;

    wire[`WORD_BUS] branch_offset;

    id ID (
        .inst_i(inst_output),
        .pc_data_i(pc_output),
        .reg1_data_i(rf_rd1),
        .reg2_data_i(rf_rd2),
        .reg1_addr_o(rf_ra1),
        .reg2_addr_o(rf_ra2),
        .funct3_o(inst_alu_reg),
        .inst_alu30_o(inst_alu30_reg),
        .pc_data_o(pc_data_reg),
        .pc_plus_o(pc_plus_reg),
        .imm_o(imm_out),
        .branch_addr_o(branch_addr),    // branch addr
        .rd_addr_o(rd_addr_reg),
        .rs1_addr_o(reg1_addr_reg),
        .rs2_addr_o(reg2_addr_reg),
        .reg1_data_o(reg1_data_reg),
        .reg2_data_o(reg2_data_reg),
        .control_forward_o(control_forward_reg),
        .control_jump_o(control_jum_reg),
        .alu_op_o(aluOp_reg),
        .control_uart_o(control_uart_reg),
        .control_dmem_o(control_dmem_reg),
        .control_wr_mux_o(control_wr_mux_reg)
    );

    // Asynchronous read: read data is available in the same cycle
    // Synchronous write: write takes one cycle
    REGFILE_1W2R # (
        .AWIDTH(5),
        .DWIDTH(32),
        .DEPTH(32)
    ) rf (
        .d0(rf_wd),     // input
        .addr0(rf_wa), // input
        .we0(rf_we),    // input
        .q1(rf_rd1),    // output
        .addr1(rf_ra1), // input
        .q2(rf_rd2),    // output
        .addr2(rf_ra2), // input
        .clk(clk));
    
    wire [31:0] imm_ex;
    wire [31:0] reg1_output;
    wire [31:0] reg2_output;
    wire [4:0] rf1_forward;
    wire [4:0] rf2_forward;
    wire [4:0] wb_addr_ex;

    wire [`REG_DBUS]    pc_ex;
    wire [`REG_DBUS]    pc_plus_ex;

    wire [1:0] control_forward;
    wire [1:0] control_jump;
    wire [1:0] aluOp;
    wire control_uart;
    wire control_dmem;
    wire [1:0] control_wr_mux;

    wire [2:0] inst_alu;
    wire inst_alu30;

    id_ex ID_EX (
        .clk(clk),
        .rst(rst),
        .pc_data_i(pc_data_reg),
        .pc_plus_i(pc_plus_reg),
        .reg1_data_i(reg1_data_reg),
        .reg2_data_i(reg2_data_reg),
        .rd_addr_i(rd_addr_reg),
        .reg1_addr_i(reg1_addr_reg),
        .reg2_addr_i(reg2_addr_reg),
        .imm_i(imm_out),
        .funct3_i(inst_alu_reg),
        .inst_alu30_i(inst_alu30_reg),
        .control_forward_i(control_forward_reg),
        .control_jump_i(control_jump_reg),
        .alu_op_i(aluOp_reg),
        .control_uart_i(control_uart_reg),
        .control_dmem_i(control_dmem_reg),
        .control_wr_mux_i(control_wr_mux_reg),
        .pc_data_o(pc_ex),
        .pc_plus_o(pc_plus_ex),
        .reg1_data_o(reg1_output),
        .reg2_data_o(reg2_output),
        .rd_addr_o(wb_addr_ex),
        .reg1_addr_o(rf1_forward),
        .reg2_addr_o(rf2_forward),
        .imm_o(imm_ex),
        .control_forward_o(control_forward),
        .control_jump_o(control_jump),
        .alu_op_o(aluOp),
        .control_uart_o(control_uart), // TODO
        .control_dmem_o(control_dmem),
        .control_wr_mux_o(control_wr_mux),
        .funct3_o(inst_alu),
        .inst_alu30_o(inst_alu30)
    );

//----------------execute stage------------//

    wire [`WORD_BUS]    alu_result_reg;
    wire [`REG_ABUS]    wb_addr_reg;
    wire [1:0]          control_wr_mux_reg2;
    wire [`REG_DBUS]    pc_plus_reg2;
    wire [`REG_DBUS]    mem_write_reg;   

    ex EX (
        .forward_data(wb_data),     // DATA from write back stage
        .pc_data_i(pc_ex),
        .pc_plus_i(pc_plus_ex),
        .reg1_data_i(reg1_output),
        .reg2_data_i(reg2_output),
        .wb_addr_i(wb_addr_ex),
        .reg1_addr_i(rf1_forward),
        .reg2_addr_i(rf2_forward),
        .imm_i(imm_ex),
        .funct3_i(inst_alu),
        .inst_alu30_i(inst_alu30),
        .control_forward_i(control_forward),
        .control_jump_i(control_jump),
        .alu_op_i(aluOp),
        .control_uart_i(control_uart),  //TODO
        .control_dmem_i(control_dmem),
        .control_wr_mux_i(control_wr_mux),
        .mem_write_o(mem_write_reg),
        .alu_result_o(alu_result_reg),
        .wb_addr_o(wb_addr_reg),
        .control_wr_mux_o(control_wr_mux_reg2),
        .pc_plus_o(pc_plux_reg2)
    );

    wire [31:0] rtype_output;
    wire [1:0] control_data;
    wire [31:0] pc_plus_wb;
    ex_wb EX_WB (
        .clk(clk),
        .rst(rst),
        .alu_result_i(alu_result_reg),
        .wb_addr_i(wb_addr_reg),
        .control_wr_mux_i(control_wr_reg2),
        .pc_plus_i(pc_plus_reg2),
        .alu_result_o(rtype_output),
        .wb_addr_o(wb_addr),
        .control_wr_mux_o(control_data),
        .pc_plus_o(pc_plus_wb)
    );

    
    // UART Receiver
    wire [7:0] uart_rx_data_out;
    wire uart_rx_data_out_valid;
    wire uart_rx_data_out_ready;

    localparam DMEM_AWIDTH = 32;
    localparam DMEM_DWIDTH = 32;
    localparam DMEM_DEPTH = 16384;

    wire [DMEM_AWIDTH-1:0] dmem_addra;
    wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
    wire [3:0] dmem_wea;

    assign dmem_wea = control_dmem;
    assign dmem_dina = mem_write_reg;

    // Data Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    // Byte addressable: select which of the four bytes to write
    SYNC_RAM_WBE #(
        .AWIDTH(DMEM_AWIDTH),
        .DWIDTH(DMEM_DWIDTH),
        .DEPTH(DMEM_DEPTH)
    ) dmem (
        .q(dmem_douta),    // output
        .d(dmem_dina),     // input
        .addr(dmem_addra), // input
        .wbe(dmem_wea),    // input
        .clk(clk), .rst(rst));

    //-----------wb stage---------------/
    wb WB (
        .alu_result_i(rtype_output),
        .wb_addr_i(wb_addr),
        .control_wr_mux_i(contro_data),
        .pc_plus_i(pc_plus_wb),
        .dmem_douta_i(dmem_douta),
        .wb_addr_o(rf_wa),
        .bios_doutb_i(bios_doutb),
        .wb_data_o(wb_data)               

    );


/*
    uart_receiver #(
        .CLOCK_FREQ(CPU_CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)) uart_rx (
        .clk(clk),
        .rst(rst),
        .data_out(uart_rx_data_out),             // output
        .data_out_valid(uart_rx_data_out_valid), // output
        .data_out_ready(uart_rx_data_out_ready), // input
        .serial_in(FPGA_SERIAL_RX)               // input
    );

    // UART Transmitter
    wire [7:0] uart_tx_data_in;
    wire uart_tx_data_in_valid;
    wire uart_tx_data_in_ready;

    uart_transmitter #(
        .CLOCK_FREQ(CPU_CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)) uart_tx (
        .clk(clk),
        .rst(reset),
        .data_in(uart_tx_data_in),             // input
        .data_in_valid(uart_tx_data_in_valid), // input
        .data_in_ready(uart_tx_data_in_ready), // output
        .serial_out(FPGA_SERIAL_TX)            // output
    );

*/
    // Construct your datapath, add as many modules as you want

endmodule