`default_nettype none
// Tiny Tapeout wrapper, G07. Protocol:
// Hold rst_n=0 >=1 rising edge. First rising edge after reset: config N
// from uio_in[7:0] (all uio pins INPUT); no sample accepted.
// Following cycles: ui_in[7:0] = sample; uio_in[2] = valid_in;
// uo_out[7:0] = peak; uio_out[0] = decaying pulse;
// uio_out[1] = valid_out; uio_oe = 8'b00000011.
// ena=0 freezes processing (reset and config remain clocked).
module tt_um_eee703128_g07 (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena, clk, rst_n
);
    reg configured;
    reg [7:0] n_q;
    wire [7:0] peak;
    wire valid_o, decaying;
    always @(posedge clk) begin
        if (!rst_n) begin
            configured <= 1'b0;
            n_q <= 8'd1;
        end else if (!configured) begin
            n_q <= (uio_in == 8'd0) ? 8'd1 : uio_in;
            configured <= 1'b1;
        end
    end
    g07_peak_decay_runtime core (
        .clk(clk), .rst_n(rst_n),
        .valid_in(configured && ena && uio_in[2]),
        .sample_in(ui_in), .decay_n(n_q),
        .peak_out(peak), .valid_out(valid_o), .decaying(decaying)
    );
    assign uo_out = peak;
    assign uio_out = {6'b0, valid_o, decaying};
    assign uio_oe = configured ? 8'b00000011 : 8'b00000000;
endmodule
`default_nettype wire
