`timescale 1ns/1ps
import axi_pkg::*;

module axi_slave_top #(
    parameter ADDR_WIDTH = axi_pkg::ADDR_WIDTH,
    parameter DATA_WIDTH = axi_pkg::DATA_WIDTH,
    parameter ID_WIDTH   = axi_pkg::ID_WIDTH,
    parameter MEM_DEPTH  = axi_pkg::MEM_DEPTH
)(
    axi_if.slave axi
);

    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    typedef enum logic [1:0] {WR_IDLE, WR_DATA, WR_RESP} wr_state_t;
    typedef enum logic [1:0] {RD_IDLE, RD_DATA} rd_state_t;

    wr_state_t wr_state;
    rd_state_t rd_state;

    logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    logic [7:0]            wr_len_cnt, rd_len_cnt;
    logic [ID_WIDTH-1:0]   wr_id, rd_id;
    logic [2:0]            wr_size, rd_size;
    
    // NEW: Latch the burst types
    logic [1:0]            wr_burst, rd_burst; 
    logic                  wr_error; 

    // ================= WRITE CHANNEL =================
    always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
        if (!axi.ARESETn) begin
            wr_state    <= WR_IDLE;
            axi.AWREADY <= 0;
            axi.WREADY  <= 0;
            axi.BVALID  <= 0;
            axi.BID     <= 0;
            axi.BRESP   <= OKAY;
            wr_error    <= 0;
        end
        else begin
            case (wr_state)
                WR_IDLE: begin
                    axi.AWREADY <= 1;
                    if (axi.AWVALID && axi.AWREADY) begin
                        wr_addr    <= axi.AWADDR;
                        wr_len_cnt <= axi.AWLEN;
                        wr_id      <= axi.AWID;
                        wr_size    <= axi.AWSIZE;
                        wr_burst   <= axi.AWBURST; // Latch Write Burst Type
                        wr_error   <= 0;
                        axi.AWREADY <= 0;
                        axi.WREADY  <= 1;
                        wr_state    <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (axi.WVALID && axi.WREADY) begin
                        int mem_idx;
                        mem_idx = wr_addr >> 2;
                        
                        if (mem_idx < MEM_DEPTH) begin
                            // Byte-lane masking using WSTRB
                            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                                if (axi.WSTRB[i])
                                    mem[mem_idx][8*i +: 8] <= axi.WDATA[8*i +: 8];
                            end
                        end else begin
                            wr_error <= 1;
                        end

                        if (wr_len_cnt == 0 || axi.WLAST) begin
                            axi.WREADY  <= 0;
                            axi.BVALID  <= 1;
                            axi.BID     <= wr_id;
                            axi.BRESP   <= wr_error ? SLVERR : OKAY;
                            wr_state    <= WR_RESP;
                        end
                        else begin
                            wr_len_cnt <= wr_len_cnt - 1;
                            if (wr_burst == INCR) // Use Latched Burst Type
                                wr_addr <= wr_addr + (1 << wr_size);
                        end
                    end
                end

                WR_RESP: begin
                    if (axi.BREADY && axi.BVALID) begin
                        axi.BVALID <= 0;
                        wr_state   <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // ================= READ CHANNEL =================
    always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
        if (!axi.ARESETn) begin
            rd_state    <= RD_IDLE;
            axi.ARREADY <= 0;
            axi.RVALID  <= 0;
            axi.RLAST   <= 0;
            axi.RDATA   <= 0;
            axi.RRESP   <= OKAY;
        end
        else begin
            case (rd_state)
                RD_IDLE: begin
                    axi.ARREADY <= 1;
                    if (axi.ARVALID && axi.ARREADY) begin
                        rd_addr    <= axi.ARADDR;
                        rd_len_cnt <= axi.ARLEN;
                        rd_id      <= axi.ARID;
                        rd_size    <= axi.ARSIZE;
                        rd_burst   <= axi.ARBURST; // Latch Read Burst Type
                        axi.ARREADY <= 0;
                        rd_state    <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    int mem_idx;
                    int nxt_idx;
                    mem_idx = rd_addr >> 2;
                    
                    
                    nxt_idx = (rd_burst == INCR) ? ((rd_addr + (1 << rd_size)) >> 2) : mem_idx;

                    // Drive data and valid on first entry
                    if (!axi.RVALID) begin
                        axi.RDATA  <= (mem_idx < MEM_DEPTH) ? mem[mem_idx] : 32'hDEADBEEF;
                        axi.RID    <= rd_id;
                        axi.RRESP  <= (mem_idx < MEM_DEPTH) ? OKAY : SLVERR;
                        axi.RVALID <= 1;
                        axi.RLAST  <= (rd_len_cnt == 0);
                    end

                    // Handshake occurred
                    if (axi.RVALID && axi.RREADY) begin
                        if (rd_len_cnt == 0) begin
                            axi.RVALID <= 0;
                            axi.RLAST  <= 0;
                            rd_state   <= RD_IDLE;
                        end 
                        else begin
                            rd_len_cnt <= rd_len_cnt - 1;
                            if (rd_burst == INCR) // Use Latched Burst Type
                                rd_addr <= rd_addr + (1 << rd_size);
                            
                            // Prepare next beat pipelined
                            axi.RDATA  <= (nxt_idx < MEM_DEPTH) ? mem[nxt_idx] : 32'hDEADBEEF;
                            axi.RRESP  <= (nxt_idx < MEM_DEPTH) ? OKAY : SLVERR;
                            axi.RLAST  <= (rd_len_cnt == 1);
                        end
                    end
                end
            endcase
        end
    end
endmodule
