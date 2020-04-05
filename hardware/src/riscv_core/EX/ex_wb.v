`include "../defines.vh"


module ex_wb (
    input clk,
    input rst,
    input wire[`WORD_BUS]       alu_result_i,
    input wire[`REG_ABUS]       wb_addr_i,
    input wire[1:0]             control_wr_mux_i,
    input wire[`REG_DBUS]       pc_plus_i,

    output wire[`WORD_BUS]      alu_result_o,
    output wire[`REG_ABUS]      wb_addr_o,
    output wire[1:0]            control_wr_mux_o,
    output wire[`REG_DBUS]      pc_plus_o
);


    REGISTER_R #(.N(32)) store_alu(
        .q(alu_result_o),
        .clk(clk),
        .rst(rst),
        .d(alu_result_i));

    REGISTER_R #(.N(5)) store_addr(
        .q(wb_addr_o),
        .clk(clk),
        .rst(rst),
        .d(wb_addr_i));
    
    REGISTER_R #(.N(32)) store_control(
        .q(control_wr_mux_o),
        .clk(clk),
        .rst(rst),
        .d(control_wr_mux_i));
    
    REGISTER_R # (.N(32)) store_pc_wb(
        .q(pc_plus_o),
        .clk(clk),
        .rst(rst),
        .d(pc_plus_i));

endmodule