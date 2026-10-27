module g07_peak_decay #(
    parameter int W = 8,
    parameter int N = 8
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         valid_in,
    input  logic [W-1:0] sample_in,
    output logic [W-1:0] peak_out,
    output logic         valid_out
);

    localparam int CW = (N <= 1) ? 1 : $clog2(N);

    logic [W-1:0] peak_q, peak_d;
    logic [CW-1:0] count_q, count_d;

    always_comb begin
        peak_d  = peak_q;
        count_d = count_q;

        if (valid_in) begin
            // New higher peak has priority over decay.
            if (sample_in > peak_q) begin
                peak_d  = sample_in;
                count_d = '0;
            end else if (N <= 1) begin
                peak_d  = (peak_q == '0) ? '0 : peak_q - 1'b1;
                count_d = '0;
            end else if (count_q == N-1) begin
                peak_d  = (peak_q == '0) ? '0 : peak_q - 1'b1;
                count_d = '0;
            end else begin
                count_d = count_q + 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            peak_q   <= '0;
            count_q  <= '0;
            peak_out <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                peak_q   <= peak_d;
                count_q  <= count_d;
                peak_out <= peak_d;
            end
        end
    end

endmodule
