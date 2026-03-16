// Testbench for the top-level matrix multiplier.
// Verifies a 2x2 matrix multiplication end-to-end.
`timescale 1ns / 1ps

module tb_matrix_multiplier;

    parameter N          = 2;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg                            clk;
    reg                            rst_n;
    reg                            start;
    reg  [N*N*DATA_WIDTH-1:0]      input_data;
    reg  [N*N*DATA_WIDTH-1:0]      weight_data;
    wire [N*N*ACC_WIDTH-1:0]       result_data;
    wire                           done;

    matrix_multiplier #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .input_data  (input_data),
        .weight_data (weight_data),
        .result_data (result_data),
        .done        (done)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;

    // Extract element C[row][col] from result_data (row-major).
    function [ACC_WIDTH-1:0] get_c;
        input integer row;
        input integer col;
        begin
            get_c = result_data[(row*N + col)*ACC_WIDTH +: ACC_WIDTH];
        end
    endfunction

    task check_element(input integer row, input integer col,
                       input [ACC_WIDTH-1:0] expected);
        begin
            if (get_c(row, col) !== expected) begin
                $display("FAIL: C[%0d][%0d] = %0d, expected %0d",
                         row, col, get_c(row, col), expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS: C[%0d][%0d] = %0d", row, col, get_c(row, col));
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Test 1: 2x2 multiply
    //   A = | 1  2 |   B = | 5  6 |
    //       | 3  4 |       | 7  8 |
    //
    //   C = | 19  22 |
    //       | 43  50 |
    // ---------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        rst_n       = 0;
        start       = 0;
        input_data  = 0;
        weight_data = 0;
        #20;
        rst_n = 1;
        @(posedge clk);

        $display("\n--- Test 1: 2x2 Matrix Multiply ---");
        // Row-major packing: A[0][0]=1, A[0][1]=2, A[1][0]=3, A[1][1]=4
        input_data  = {8'd4, 8'd3, 8'd2, 8'd1};
        // B[0][0]=5, B[0][1]=6, B[1][0]=7, B[1][1]=8
        weight_data = {8'd8, 8'd7, 8'd6, 8'd5};
        start       = 1;
        @(posedge clk);
        start       = 0;

        // Wait for done
        wait (done == 1'b1);
        @(posedge clk);

        check_element(0, 0, 32'd19);
        check_element(0, 1, 32'd22);
        check_element(1, 0, 32'd43);
        check_element(1, 1, 32'd50);

        // ---------------------------------------------------------------
        // Test 2: Identity multiply
        //   A = | 2  0 |   B = | 1  0 |
        //       | 0  3 |       | 0  1 |
        //
        //   C = | 2  0 |
        //       | 0  3 |
        // ---------------------------------------------------------------
        $display("\n--- Test 2: Identity Multiply ---");
        @(posedge clk);
        input_data  = {8'd3, 8'd0, 8'd0, 8'd2};
        weight_data = {8'd1, 8'd0, 8'd0, 8'd1};
        start       = 1;
        @(posedge clk);
        start       = 0;

        wait (done == 1'b1);
        @(posedge clk);

        check_element(0, 0, 32'd2);
        check_element(0, 1, 32'd0);
        check_element(1, 0, 32'd0);
        check_element(1, 1, 32'd3);

        // ---- Summary ----
        $display("\n===========================");
        $display("Matrix Multiplier Testbench: %0d PASSED, %0d FAILED",
                 pass_count, fail_count);
        $display("===========================\n");
        if (fail_count > 0) $finish(1);
        $finish(0);
    end

endmodule
