`include "../defines.vh"
`include "../mux.v"

module wb (
    // from ex_wb
    input wire[31:0]             alu_result_i,
    input wire[4:0]              wb_addr_i,
    input wire[1:0]             control_wr_mux_i,
    input wire[31:0]             pc_plus_i,
    input wire[2:0]              control_load_i,

    //from mem
    input wire[`DMEM_DBUS]      dmem_douta_i,
    input wire[`BIOS_DBUS]      bios_doutb_i,          
    output wire[`REG_ABUS]      wb_addr_o,
    output wire[`REG_DBUS]      wb_data_o
);
    assign wb_addr_o = wb_addr_i;
    wire [31:0] dmem_load_i;
    mux_dmem mux_dmem(
        .dmem_output(dmem_load_i),
        .bios_output(bios_doutb_i),
        .pc_output(pc_plus_i),
        .rtype_output(alu_result_i),
        .control_data(control_wr_mux_i),
        .addr(alu_result_i[31:28]),
        .wb_data(wb_data_o));
    
    load_type load_type(
        .control_load(control_load_i),
        .dmem_load_i(dmem_douta_i),
        .dmem_data_o(dmem_load_i));

endmodule