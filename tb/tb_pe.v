// Testbench for the Processing Element (PE) module.
`timescale 1ns / 1ps

module tb_pe;

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg                    clk;
    reg                    rst_n;
    reg                    weight_load;
    reg  [DATA_WIDTH-1:0]  weight_in;
    reg  [DATA_WIDTH-1:0]  data_in;
    reg                    data_in_valid;
    reg  [ACC_WIDTH-1:0]   psum_in;
    reg                    psum_in_valid;
    wire [DATA_WIDTH-1:0]  data_out;
    wire                   data_out_valid;
    wire [ACC_WIDTH-1:0]   psum_out;
    wire                   psum_out_valid;

    pe #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .weight_load    (weight_load),
        .weight_in      (weight_in),
        .data_in        (data_in),
        .data_in_valid  (data_in_valid),
        .psum_in        (psum_in),
        .psum_in_valid  (psum_in_valid),
        .data_out       (data_out),
        .data_out_valid (data_out_valid),
        .psum_out       (psum_out),
        .psum_out_valid (psum_out_valid)
    );

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;

    task check_psum(input [ACC_WIDTH-1:0] expected);
        begin
            if (psum_out !== expected) begin
                $display("FAIL: psum_out = %0d, expected %0d at time %0t",
                         psum_out, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: psum_out = %0d at time %0t", psum_out, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_data(input [DATA_WIDTH-1:0] expected);
        begin
            if (data_out !== expected) begin
                $display("FAIL: data_out = %0d, expected %0d at time %0t",
                         data_out, expected, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: data_out = %0d at time %0t", data_out, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ---- Reset ----
        rst_n          = 0;
        weight_load    = 0;
        weight_in      = 0;
        data_in        = 0;
        data_in_valid  = 0;
        psum_in        = 0;
        psum_in_valid  = 0;
        #20;
        rst_n = 1;
        @(posedge clk);

        // Drive stimulus on negedge to avoid race conditions at
        // the posedge where the DUT samples.

        // ---- Test 1: Load weight = 3 ----
        $display("\n--- Test 1: Load weight ---");
        @(negedge clk);
        weight_load = 1;
        weight_in   = 8'd3;
        @(posedge clk); // PE latches weight_load=1
        @(negedge clk);
        weight_load = 0;

        // ---- Test 2: MAC operation: data=5, psum=10 -> 10+5*3=25 ----
        $display("\n--- Test 2: MAC 5*3+10=25 ---");
        data_in       = 8'd5;
        data_in_valid = 1;
        psum_in       = 32'd10;
        psum_in_valid = 1;
        @(posedge clk); // PE latches inputs and computes MAC
        #1;
        check_psum(32'd25);
        check_data(8'd5);
        @(negedge clk);
        data_in_valid = 0;
        psum_in_valid = 0;

        // ---- Test 3: MAC with psum=0: data=7, weight=3 -> 0+7*3=21 ----
        $display("\n--- Test 3: MAC 7*3+0=21 ---");
        data_in       = 8'd7;
        data_in_valid = 1;
        psum_in       = 32'd0;
        psum_in_valid = 1;
        @(posedge clk);
        #1;
        check_psum(32'd21);
        check_data(8'd7);
        @(negedge clk);
        data_in_valid = 0;
        psum_in_valid = 0;

        // ---- Test 4: No valid inputs -> psum_out should be 0 ----
        $display("\n--- Test 4: No valid input ---");
        data_in       = 8'd99;
        data_in_valid = 0;
        psum_in       = 32'd99;
        psum_in_valid = 0;
        @(posedge clk);
        #1;
        check_psum(32'd0);

        // ---- Test 5: Change weight to 10, MAC: 4*10+100=140 ----
        $display("\n--- Test 5: New weight, MAC 4*10+100=140 ---");
        @(negedge clk);
        weight_load = 1;
        weight_in   = 8'd10;
        @(posedge clk); // PE latches weight_load=1
        @(negedge clk);
        weight_load = 0;

        data_in       = 8'd4;
        data_in_valid = 1;
        psum_in       = 32'd100;
        psum_in_valid = 1;
        @(posedge clk); // PE computes MAC with new weight
        #1;
        check_psum(32'd140);

        // ---- Summary ----
        $display("\n===========================");
        $display("PE Testbench: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("===========================\n");
        if (fail_count > 0) $finish(1);
        $finish(0);
    end

endmodule
