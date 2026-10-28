`default_nettype none
// G07: 8-bit peak detector, programmable decay interval.
// N=0 is interpreted as N=1. Count advances only on valid samples.
module g07_peak_decay_runtime (
    input wire clk, rst_n, valid_in,
    input wire [7:0] sample_in,
    input wire [7:0] decay_n,
    output reg [7:0] peak_out,
    output reg valid_out,
    output reg decaying
);
    reg [7:0] count_q;
    wire [7:0] n_eff = (decay_n == 8'd0) ? 8'd1 : decay_n;
    always @(posedge clk) begin
        if (!rst_n) begin
            peak_out <= 8'd0;
            count_q <= 8'd0;
            valid_out <= 1'b0;
            decaying <= 1'b0;
        end else begin
            valid_out <= valid_in;
            decaying <= 1'b0;
            if (valid_in) begin
                if (sample_in > peak_out) begin
                    peak_out <= sample_in;
                    count_q <= 8'd0;
                end else if (count_q >= (n_eff - 8'd1)) begin
                    if (peak_out != 8'd0) begin
                        peak_out <= peak_out - 8'd1;
                        decaying <= 1'b1;
                    end
                    count_q <= 8'd0;
                end else begin
                    count_q <= count_q + 8'd1;
                end
            end
        end
    end
endmodule
`default_nettype wire
