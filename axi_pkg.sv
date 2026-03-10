`ifndef AXI_PKG_SV
`define AXI_PKG_SV

package axi_pkg;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter ID_WIDTH   = 4;
    parameter MEM_DEPTH  = 1024;

    typedef enum logic [1:0] {
        FIXED = 2'b00,
        INCR  = 2'b01,
        WRAP  = 2'b10
    } burst_t;

    typedef enum logic [1:0] {
        OKAY   = 2'b00,
        EXOKAY = 2'b01,
        SLVERR = 2'b10,
        DECERR = 2'b11
    } resp_t;

endpackage

`endif
