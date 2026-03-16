// Weight-stationary systolic array for matrix multiplication.
// Implements an N x N grid of Processing Elements (PEs).
//
// Operation:
//   1. Load weights (one column of the weight matrix per cycle, with
//      weight_load asserted).
//   2. Stream input rows from the left with diagonal skew (row k is
//      delayed by k cycles). The top-level matrix_multiplier handles
//      this skewing.
//   3. Results emerge at the bottom of the array after pipeline
//      latency.
module systolic_array #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                          clk,
    input  wire                          rst_n,

    // Weight loading: load one weight per PE in a single cycle.
    // weight_load is broadcast; weight_data supplies one weight per
    // PE in row-major order (N*N elements).
    input  wire                          weight_load,
    input  wire [N*N*DATA_WIDTH-1:0]     weight_data,

    // Input data fed from the left for each row (already skewed by
    // the caller).
    input  wire [N*DATA_WIDTH-1:0]       data_in,
    input  wire [N-1:0]                  data_in_valid,

    // Output partial sums at the bottom of each column.
    output wire [N*ACC_WIDTH-1:0]        result_out,
    output wire [N-1:0]                  result_out_valid
);

    // Internal wires connecting PEs.
    // Horizontal data wires: N rows x (N+1) columns
    wire [DATA_WIDTH-1:0] h_data  [0:N-1][0:N];
    wire                  h_valid [0:N-1][0:N];

    // Vertical psum wires: (N+1) rows x N columns
    wire [ACC_WIDTH-1:0]  v_psum  [0:N][0:N-1];
    wire                  v_valid [0:N][0:N-1];

    // Connect external inputs to the left edge of each row.
    genvar r;
    generate
        for (r = 0; r < N; r = r + 1) begin : left_edge
            assign h_data[r][0]  = data_in[r*DATA_WIDTH +: DATA_WIDTH];
            assign h_valid[r][0] = data_in_valid[r];
        end
    endgenerate

    // Connect zeros to the top edge of each column (no incoming psum).
    genvar c;
    generate
        for (c = 0; c < N; c = c + 1) begin : top_edge
            assign v_psum[0][c]  = {ACC_WIDTH{1'b0}};
            assign v_valid[0][c] = 1'b1;
        end
    endgenerate

    // Instantiate the N x N PE grid.
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .weight_load    (weight_load),
                    .weight_in      (weight_data[(i*N+j)*DATA_WIDTH +: DATA_WIDTH]),
                    .data_in        (h_data[i][j]),
                    .data_in_valid  (h_valid[i][j]),
                    .psum_in        (v_psum[i][j]),
                    .psum_in_valid  (v_valid[i][j]),
                    .data_out       (h_data[i][j+1]),
                    .data_out_valid (h_valid[i][j+1]),
                    .psum_out       (v_psum[i+1][j]),
                    .psum_out_valid (v_valid[i+1][j])
                );
            end
        end
    endgenerate

    // Connect bottom edge to outputs.
    generate
        for (c = 0; c < N; c = c + 1) begin : bottom_edge
            assign result_out[c*ACC_WIDTH +: ACC_WIDTH] = v_psum[N][c];
            assign result_out_valid[c]                  = v_valid[N][c];
        end
    endgenerate

endmodule
