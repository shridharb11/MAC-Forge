// Processing Element (PE) for weight-stationary systolic array.
// Each PE stores one weight, multiplies it with the input arriving
// from the left, accumulates the partial sum from above, and
// forwards both the input (rightward) and partial sum (downward).
module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // Weight loading interface
    input  wire                    weight_load,
    input  wire [DATA_WIDTH-1:0]   weight_in,

    // Data from the left neighbour (or input memory)
    input  wire [DATA_WIDTH-1:0]   data_in,
    input  wire                    data_in_valid,

    // Partial sum from the upper neighbour (or zero for top row)
    input  wire [ACC_WIDTH-1:0]    psum_in,
    input  wire                    psum_in_valid,

    // Data forwarded to the right neighbour
    output reg  [DATA_WIDTH-1:0]   data_out,
    output reg                     data_out_valid,

    // Partial sum forwarded to the lower neighbour
    output reg  [ACC_WIDTH-1:0]    psum_out,
    output reg                     psum_out_valid
);

    // Stored weight register
    reg [DATA_WIDTH-1:0] weight_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg     <= {DATA_WIDTH{1'b0}};
            data_out       <= {DATA_WIDTH{1'b0}};
            data_out_valid <= 1'b0;
            psum_out       <= {ACC_WIDTH{1'b0}};
            psum_out_valid <= 1'b0;
        end else begin
            // Load weight when requested
            if (weight_load)
                weight_reg <= weight_in;

            // Forward input data to the right (one-cycle latency)
            data_out       <= data_in;
            data_out_valid <= data_in_valid;

            // MAC: multiply input with stored weight, add partial sum
            // Forward result downward (one-cycle latency)
            if (data_in_valid && psum_in_valid) begin
                psum_out       <= psum_in + (data_in * weight_reg);
                psum_out_valid <= 1'b1;
            end else begin
                psum_out       <= {ACC_WIDTH{1'b0}};
                psum_out_valid <= 1'b0;
            end
        end
    end

endmodule
