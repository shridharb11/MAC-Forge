// Top-level matrix multiplier built around a weight-stationary
// systolic array.
//
// Computes C = A x B where A, B, and C are N x N matrices.
//
// Usage:
//   1. Assert `start` for one cycle with weight_data (matrix B in
//      row-major order) and input_data (matrix A in row-major order)
//      presented on the bus.
//   2. The module skews input rows, feeds them into the systolic
//      array, and collects results.
//   3. When `done` is asserted, `result_data` holds the N x N
//      product matrix in row-major order.
module matrix_multiplier #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                            clk,
    input  wire                            rst_n,

    // Control
    input  wire                            start,

    // Matrix A (N x N) in row-major order, loaded on start.
    input  wire [N*N*DATA_WIDTH-1:0]       input_data,

    // Matrix B (N x N, weights) in row-major order, loaded on start.
    input  wire [N*N*DATA_WIDTH-1:0]       weight_data,

    // Result matrix C (N x N) in row-major order.
    output reg  [N*N*ACC_WIDTH-1:0]        result_data,
    output reg                             done
);

    // ---------------------------------------------------------------
    // State machine
    // ---------------------------------------------------------------
    localparam IDLE    = 2'd0;
    localparam LOAD    = 2'd1;
    localparam COMPUTE = 2'd2;
    localparam DONE    = 2'd3;

    reg [1:0] state;

    // Cycle counter – needs to count up to 2*N-1 feed cycles + N
    // pipeline drain cycles.
    localparam MAX_CYCLES = 3 * N;
    reg [$clog2(MAX_CYCLES+1)-1:0] cycle_cnt;

    // ---------------------------------------------------------------
    // Input storage
    // ---------------------------------------------------------------
    reg [N*N*DATA_WIDTH-1:0] a_reg;  // Matrix A
    reg [N*N*DATA_WIDTH-1:0] b_reg;  // Matrix B (weights)

    // ---------------------------------------------------------------
    // Systolic array interface signals
    // ---------------------------------------------------------------
    reg                          sa_weight_load;
    reg  [N*N*DATA_WIDTH-1:0]    sa_weight_data;
    reg  [N*DATA_WIDTH-1:0]      sa_data_in;
    reg  [N-1:0]                 sa_data_in_valid;
    wire [N*ACC_WIDTH-1:0]       sa_result_out;
    wire [N-1:0]                 sa_result_out_valid;

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_sa (
        .clk              (clk),
        .rst_n            (rst_n),
        .weight_load      (sa_weight_load),
        .weight_data      (sa_weight_data),
        .data_in          (sa_data_in),
        .data_in_valid    (sa_data_in_valid),
        .result_out       (sa_result_out),
        .result_out_valid (sa_result_out_valid)
    );

    // ---------------------------------------------------------------
    // Diagonal skew logic for input matrix A.
    // Row k of A is delayed by k cycles before being fed in.
    // We feed column `col` of A at cycle `col`, so row r gets
    // element A[r][col-r] when col-r is in [0, N-1].
    // ---------------------------------------------------------------
    integer r_idx;
    reg [$clog2(MAX_CYCLES+1)-1:0] feed_cycle;

    always @(*) begin
        sa_data_in       = {N*DATA_WIDTH{1'b0}};
        sa_data_in_valid = {N{1'b0}};
        // Only output data in COMPUTE state after weights have been
        // loaded (sa_weight_load has returned to 0).
        if (state == COMPUTE && !sa_weight_load) begin
            for (r_idx = 0; r_idx < N; r_idx = r_idx + 1) begin
                // Row k of PEs multiplies with B[k][*], so it needs
                // column k of A.  Element i of column k is A[i][k],
                // where i = feed_cycle - k (diagonal skew).
                if ((feed_cycle >= r_idx) && (feed_cycle - r_idx < N)) begin
                    sa_data_in[r_idx*DATA_WIDTH +: DATA_WIDTH] =
                        a_reg[((feed_cycle - r_idx)*N + r_idx)*DATA_WIDTH +: DATA_WIDTH];
                    sa_data_in_valid[r_idx] = 1'b1;
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Result capture.
    // Results for output row `r` appear at the bottom of column `r`
    // after N + r pipeline stages (N rows of PEs + r skew).
    // We collect N columns simultaneously; column j produces valid
    // results for rows 0..N-1 across N consecutive cycles.
    // ---------------------------------------------------------------
    // result_row_cnt tracks which output row is currently appearing
    // at each column. Column j's first valid result arrives at cycle
    // N + j (0-indexed feed cycles) + 1 (PE register latency).
    // We use the sa_result_out_valid signals to know when to capture.

    reg [$clog2(N):0] col_row_cnt [0:N-1];
    reg               col_started [0:N-1];

    integer c_idx;

    // ---------------------------------------------------------------
    // Main FSM
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            cycle_cnt      <= 0;
            feed_cycle     <= 0;
            a_reg          <= 0;
            b_reg          <= 0;
            sa_weight_load <= 1'b0;
            sa_weight_data <= 0;
            result_data    <= 0;
            done           <= 1'b0;
            for (c_idx = 0; c_idx < N; c_idx = c_idx + 1) begin
                col_row_cnt[c_idx] <= 0;
                col_started[c_idx] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a_reg <= input_data;
                        b_reg <= weight_data;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load weights into the systolic array in one
                    // cycle (broadcast).
                    sa_weight_load <= 1'b1;
                    sa_weight_data <= b_reg;
                    cycle_cnt      <= 0;
                    feed_cycle     <= 0;
                    for (c_idx = 0; c_idx < N; c_idx = c_idx + 1) begin
                        col_row_cnt[c_idx] <= 0;
                        col_started[c_idx] <= 1'b0;
                    end
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    sa_weight_load <= 1'b0;

                    // Skip advancing counters / capturing results
                    // on the first COMPUTE cycle where weight_load
                    // is still asserted (PEs are loading weights).
                    if (!sa_weight_load) begin
                        // Advance feed cycle (used by skew logic)
                        if (feed_cycle < 2 * N - 1)
                            feed_cycle <= feed_cycle + 1;

                        // Capture results emerging from the bottom.
                        for (c_idx = 0; c_idx < N; c_idx = c_idx + 1) begin
                            if (sa_result_out_valid[c_idx]) begin
                                if (!col_started[c_idx]) begin
                                    col_started[c_idx] <= 1'b1;
                                    col_row_cnt[c_idx] <= 1;
                                    result_data[(0*N + c_idx)*ACC_WIDTH +: ACC_WIDTH] <=
                                        sa_result_out[c_idx*ACC_WIDTH +: ACC_WIDTH];
                                end else if (col_row_cnt[c_idx] < N) begin
                                    result_data[(col_row_cnt[c_idx]*N + c_idx)*ACC_WIDTH +: ACC_WIDTH] <=
                                        sa_result_out[c_idx*ACC_WIDTH +: ACC_WIDTH];
                                    col_row_cnt[c_idx] <= col_row_cnt[c_idx] + 1;
                                end
                            end
                        end

                        cycle_cnt <= cycle_cnt + 1;

                        if (cycle_cnt >= MAX_CYCLES - 1)
                            state <= DONE;
                    end
                end

                DONE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
