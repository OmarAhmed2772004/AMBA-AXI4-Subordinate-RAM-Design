`timescale 1ns/1ps

module tb_axi_all_cases;

    import axi_pkg::*;

    logic clk;
    logic rstn;

    int error_count = 0;

    
    logic [31:0] ref_mem [0:MEM_DEPTH-1];

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rstn = 0;
        #20 rstn = 1;
    end

    axi_if axi(.ACLK(clk), .ARESETn(rstn));
    axi_slave_top dut(.axi(axi.slave));

    // ================= WRITE TASK =================
    task automatic axi_write(
        input [31:0] addr,
        input int beats,
        input [1:0] burst
    );
        int index = addr >> 2;
        logic [ID_WIDTH-1:0] req_id = $urandom_range(0,15);

        @(posedge clk);
        axi.AWID    <= req_id;
        axi.AWADDR  <= addr;
        axi.AWLEN   <= beats-1;
        axi.AWSIZE  <= 3'b010; 
        axi.AWBURST <= burst;
        axi.AWVALID <= 1;

        do begin @(posedge clk); end while (!axi.AWREADY);
        axi.AWVALID <= 0;

        for (int i=0; i<beats; i++) begin
            axi.WDATA  <= $urandom;
            axi.WSTRB  <= 4'hF;
            axi.WLAST  <= (i == beats-1);
            axi.WVALID <= 1;

            do begin @(posedge clk); end while (!axi.WREADY);
            
            ref_mem[index] = axi.WDATA;
            if (burst == INCR) index++;
        end

        axi.WVALID <= 0;
        axi.BREADY <= 1;
        do begin @(posedge clk); end while (!axi.BVALID);
        axi.BREADY <= 0;

        // Verify BID mapping
        if (axi.BID !== req_id) begin
            $display(" ERR: BID Mismatch! Exp=%h | Got=%h", req_id, axi.BID);
            error_count++;
        end

        $display("WRITE DONE: Addr=%h, Beats=%0d, ID=%0h", addr, beats, req_id);
    endtask

    // ================= READ TASK =================
    task automatic axi_read(
        input [31:0] addr,
        input int beats,
        input [1:0] burst
    );
        int index = addr >> 2;
        logic [ID_WIDTH-1:0] req_id = $urandom_range(0,15);

        @(posedge clk);
        axi.ARID    <= req_id;
        axi.ARADDR  <= addr;
        axi.ARLEN   <= beats-1;
        axi.ARSIZE  <= 3'b010;
        axi.ARBURST <= burst;
        axi.ARVALID <= 1;

        do begin @(posedge clk); end while (!axi.ARREADY);
        axi.ARVALID <= 0;
        axi.RREADY  <= 1;

        for (int i=0; i<beats; i++) begin
            do begin @(posedge clk); end while (!axi.RVALID);
            
            if (axi.RDATA !== ref_mem[index]) begin
                $display(" ERR: Addr=%h | Exp=%h | Got=%h", index<<2, ref_mem[index], axi.RDATA);
                error_count++;
            end else begin
                $display(" PASS: Addr=%h | Data=%h | ID=%h", index<<2, axi.RDATA, axi.RID);
            end

            if (axi.RID !== req_id) begin
                $display(" ERR: RID Mismatch! Exp=%h | Got=%h", req_id, axi.RID);
                error_count++;
            end

            if (burst == INCR) index++;
        end
        
        axi.RREADY <= 0;
    endtask

    // ================= MAIN TEST =================
 initial begin
        // Initialize ALL Master signals to clear the red lines
        axi.AWVALID = 0; axi.AWID = 0; axi.AWADDR = 0; axi.AWLEN = 0; axi.AWSIZE = 0; axi.AWBURST = 0;
        axi.WVALID  = 0; axi.WDATA = 0; axi.WSTRB = 0; axi.WLAST = 0;
        axi.BREADY  = 0;
        axi.ARVALID = 0; axi.ARID = 0; axi.ARADDR = 0; axi.ARLEN = 0; axi.ARSIZE = 0; axi.ARBURST = 0;
        axi.RREADY  = 0;

        wait(rstn); // Wait for reset
        

        for (int i=0; i<MEM_DEPTH; i++)
            ref_mem[i] = 0;
       

        $display("---------------------------------------------------------");
        $display("Starting Full AXI4 Burst Validation Testbench...");
        $display("---------------------------------------------------------");

        // Test cases
        axi_write(32'h0000_0000, 1, INCR);
        axi_write(32'h0000_0010, 4, INCR);
        axi_write(32'h0000_0020, 4, FIXED);
        
        axi_read (32'h0000_0010, 4, INCR);
        axi_read (32'h0000_0020, 4, FIXED);

        repeat (5) begin
            // Separate declarations from assignments to fix QuestaSim error
            logic [31:0] rand_addr;
            int rand_beats;
            
            rand_addr = ($urandom_range(0, 200) << 2); // Word aligned random address
            rand_beats = $urandom_range(1, 8);
            
            axi_write(rand_addr, rand_beats, INCR);
            axi_read (rand_addr, rand_beats, INCR);
        end

        #200;

        $display("---------------------------------------------------------");
        if (error_count == 0)
            $display(" SUCCESS: ALL TESTS PASSED!");
        else
            $display(" FAILURE: TEST FAILED. Errors = %0d", error_count);
        $display("---------------------------------------------------------");

        $finish;
    end

endmodule