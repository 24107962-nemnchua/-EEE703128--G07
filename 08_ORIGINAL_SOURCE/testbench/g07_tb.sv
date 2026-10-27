module g07_tb;
    logic clk,rst_n,valid_in;
    logic [7:0] sample_in,peak_out;
    logic valid_out;

    g07_peak_decay #(.W(8),.N(2)) dut(
        .clk(clk),.rst_n(rst_n),.valid_in(valid_in),
        .sample_in(sample_in),.peak_out(peak_out),
        .valid_out(valid_out)
    );

    always #5 clk=~clk;

    task automatic send(input logic [7:0] x,
                        input logic [7:0] exp);
        begin
            sample_in=x;
            valid_in=1;
            @(posedge clk); #1;
            assert(valid_out) else $fatal(1,"valid_out missing");
            assert(peak_out==exp)
                else $fatal(1,"peak got=%0d expected=%0d",
                            peak_out,exp);
            valid_in=0;
        end
    endtask

    initial begin
        clk=0; rst_n=0; valid_in=0; sample_in=0;
        repeat(2) @(posedge clk);
        rst_n=1;

        // New peak.
        send(8'd10,8'd10);

        // Lower samples do not replace peak.
        send(8'd1,8'd10);
        send(8'd1,8'd9);

        // New peak has priority.
        send(8'd20,8'd20);

        // Underflow boundary.
        rst_n=0;
        @(posedge clk); #1;
        rst_n=1;
        send(8'd1,8'd1);
        send(8'd0,8'd1);
        send(8'd0,8'd0);
        send(8'd0,8'd0);

        // Valid gap.
        valid_in=0;
        repeat(3) @(posedge clk); #1;
        assert(!valid_out) else $fatal(1,"gap generated output");

        $display("G07 TB completed");
        $finish;
    end
endmodule
