`ifndef AXI_IF_SV
`define AXI_IF_SV

interface axi_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input logic ACLK,
    input logic ARESETn
);

    // Write Address Channel
    logic [ID_WIDTH-1:0]   AWID;
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [7:0]            AWLEN;
    logic [2:0]            AWSIZE;
    logic [1:0]            AWBURST;
    logic                  AWVALID;
    logic                  AWREADY;

    // Write Data Channel
    logic [DATA_WIDTH-1:0]     WDATA;
    logic [(DATA_WIDTH/8)-1:0] WSTRB;
    logic                      WLAST;
    logic                      WVALID;
    logic                      WREADY;

    // Write Response Channel
    logic [ID_WIDTH-1:0]   BID;
    logic [1:0]            BRESP;
    logic                  BVALID;
    logic                  BREADY;

    // Read Address Channel
    logic [ID_WIDTH-1:0]   ARID;
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [7:0]            ARLEN;
    logic [2:0]            ARSIZE;
    logic [1:0]            ARBURST;
    logic                  ARVALID;
    logic                  ARREADY;

    // Read Data Channel
    logic [ID_WIDTH-1:0]   RID;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RLAST;
    logic                  RVALID;
    logic                  RREADY;

    modport slave (
        input  ACLK, ARESETn,
        input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
        input  WDATA, WSTRB, WLAST, WVALID,
        input  BREADY,
        input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
        input  RREADY,
        
        output AWREADY, WREADY, BVALID, BRESP, BID,
        output ARREADY, RVALID, RDATA, RRESP, RID, RLAST
    );

    modport master (
        input  ACLK, ARESETn,
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
        output WDATA, WSTRB, WLAST, WVALID,
        output BREADY,
        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
        output RREADY,
        
        input  AWREADY, WREADY, BVALID, BRESP, BID,
        input  ARREADY, RVALID, RDATA, RRESP, RID, RLAST
    );

endinterface

`endif
