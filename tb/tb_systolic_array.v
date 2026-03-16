// Testbench for the systolic array module.
// Performs a 2x2 matrix multiplication to verify dataflow.
`timescale 1ns / 1ps

module tb_systolic_array;

    parameter N          = 2;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg                          clk;
    reg                          rst_n;
    reg                          weight_load;
    reg  [N*N*DATA_WIDTH-1:0]    weight_data;
    reg  [N*DATA_WIDTH-1:0]      data_in;
    reg  [N-1:0]                 data_in_valid;
    wire [N*ACC_WIDTH-1:0]       result_out;
    wire [N-1:0]                 result_out_valid;

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .weight_load      (weight_load),
        .weight_data      (weight_data),
        .data_in          (data_in),
        .data_in_valid    (data_in_valid),
        .result_out       (result_out),
        .result_out_valid (result_out_valid)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;

    // Helper to extract result column value.
    function [ACC_WIDTH-1:0] get_result;
        input integer col;
        begin
            get_result = result_out[col*ACC_WIDTH +: ACC_WIDTH];
        end
    endfunction

    // ---------------------------------------------------------------
    // 2x2 multiply:
    //   A = | 1  2 |   B (weights) = | 5  6 |
    //       | 3  4 |                  | 7  8 |
    //
    //   C = A x B = | 1*5+2*7  1*6+2*8 | = | 19  22 |
    //               | 3*5+4*7  3*6+4*8 |   | 43  50 |
    //
    // Weight matrix B is loaded into PEs:
    //   PE[0][0]=5, PE[0][1]=6, PE[1][0]=7, PE[1][1]=8
    //
    // Input data (A) fed from the left with diagonal skew:
    //   Cycle 0: row0 gets A[0][0]=1, row1 invalid
    //   Cycle 1: row0 gets A[0][1]=2, row1 gets A[1][0]=3
    //   Cycle 2: row0 invalid,        row1 gets A[1][1]=4
    // ---------------------------------------------------------------

    // Collect non-zero results from the bottom of each column.
    reg [ACC_WIDTH-1:0] col0_results [0:N-1];
    reg [ACC_WIDTH-1:0] col1_results [0:N-1];
    integer col0_cnt, col1_cnt;

    initial begin
        pass_count = 0;
        fail_count = 0;
        col0_cnt   = 0;
        col1_cnt   = 0;

        rst_n       = 0;
        weight_load = 0;
        weight_data = 0;
        data_in     = 0;
        data_in_valid = 0;
        #20;
        rst_n = 1;
        @(posedge clk);

        // ---- Load weights (drive on negedge to avoid race) ----
        // Row-major: PE[0][0]=5, PE[0][1]=6, PE[1][0]=7, PE[1][1]=8
        @(negedge clk);
        weight_load = 1;
        weight_data = {8'd8, 8'd7, 8'd6, 8'd5};
        @(posedge clk); // PE latches weights
        @(negedge clk);
        weight_load = 0;

        // ---- Feed cycle 0: row0=A[0][0]=1, row1=invalid ----
        data_in       = {8'd0, 8'd1};
        data_in_valid = 2'b01;
        @(posedge clk);

        // ---- Feed cycle 1: row0=A[1][0]=3, row1=A[0][1]=2 ----
        @(negedge clk);
        data_in       = {8'd2, 8'd3};
        data_in_valid = 2'b11;
        @(posedge clk);

        // ---- Feed cycle 2: row0=invalid, row1=A[1][1]=4 ----
        @(negedge clk);
        data_in       = {8'd4, 8'd0};
        data_in_valid = 2'b10;
        @(posedge clk);

        // ---- No more input ----
        @(negedge clk);
        data_in       = 0;
        data_in_valid = 0;

        // Wait for pipeline to fully drain.
        repeat (6) @(posedge clk);

        // ---- Verify collected results ----
        // Expected C = A x B:
        //   C[0][0]=19, C[0][1]=22, C[1][0]=43, C[1][1]=50
        // Column 0 produces: C[0][0]=19, then C[1][0]=43
        // Column 1 produces: C[0][1]=22, then C[1][1]=50
        $display("\n===========================");
        $display("Systolic Array 2x2 Testbench");
        $display("===========================");

        if (col0_cnt >= 2) begin
            if (col0_results[0] == 32'd19) begin
                $display("PASS: col0[0]=%0d (expected 19)", col0_results[0]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: col0[0]=%0d (expected 19)", col0_results[0]);
                fail_count = fail_count + 1;
            end
            if (col0_results[1] == 32'd43) begin
                $display("PASS: col0[1]=%0d (expected 43)", col0_results[1]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: col0[1]=%0d (expected 43)", col0_results[1]);
                fail_count = fail_count + 1;
            end
        end else begin
            $display("FAIL: col0 only got %0d results, expected 2", col0_cnt);
            fail_count = fail_count + 2;
        end

        if (col1_cnt >= 2) begin
            if (col1_results[0] == 32'd22) begin
                $display("PASS: col1[0]=%0d (expected 22)", col1_results[0]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: col1[0]=%0d (expected 22)", col1_results[0]);
                fail_count = fail_count + 1;
            end
            if (col1_results[1] == 32'd50) begin
                $display("PASS: col1[1]=%0d (expected 50)", col1_results[1]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: col1[1]=%0d (expected 50)", col1_results[1]);
                fail_count = fail_count + 1;
            end
        end else begin
            $display("FAIL: col1 only got %0d results, expected 2", col1_cnt);
            fail_count = fail_count + 2;
        end

        $display("%0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("===========================\n");
        if (fail_count > 0) $finish(1);
        $finish(0);
    end

    // Collect valid results from the bottom of each column.
    // Note: this approach relies on the test matrices not producing
    // zero intermediate results at the array bottom edge.  For the
    // chosen test vectors (non-zero products), this is always true.
    always @(posedge clk) begin
        if (result_out_valid[0] && get_result(0) != 0) begin
            $display("t=%0t col0 result=%0d", $time, get_result(0));
            if (col0_cnt < N) begin
                col0_results[col0_cnt] <= get_result(0);
                col0_cnt <= col0_cnt + 1;
            end
        end
        if (result_out_valid[1] && get_result(1) != 0) begin
            $display("t=%0t col1 result=%0d", $time, get_result(1));
            if (col1_cnt < N) begin
                col1_results[col1_cnt] <= get_result(1);
                col1_cnt <= col1_cnt + 1;
            end
        end
    end

endmodule
