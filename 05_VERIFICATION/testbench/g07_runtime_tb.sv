`timescale 1ns/1ps
module g07_runtime_tb;
  reg clk=0, rst_n=0, ena=1;
  reg [7:0] ui_in=0, uio_in=0;
  wire [7:0] uo_out, uio_out, uio_oe;
  integer cases=0;
  always #5 clk=~clk;
  tt_um_eee703128_g07 dut(.ui_in(ui_in),.uo_out(uo_out),.uio_in(uio_in),
    .uio_out(uio_out),.uio_oe(uio_oe),.ena(ena),.clk(clk),.rst_n(rst_n));
  task automatic check(input [7:0] expected_peak, input expected_valid, input expected_decay);
    begin
      #1;
      cases=cases+1;
      if (uo_out !== expected_peak || uio_out[1] !== expected_valid || uio_out[0] !== expected_decay)
        $fatal(1,"case=%0d peak=%0d valid=%b decay=%b expected=%0d,%b,%b", cases,
          uo_out,uio_out[1],uio_out[0],expected_peak,expected_valid,expected_decay);
    end
  endtask
  task automatic sample(input [7:0] value, input [7:0] expected, input decay);
    begin
      @(negedge clk); ui_in=value; uio_in=8'b00000100;
      @(posedge clk); check(expected,1'b1,decay);
    end
  endtask
  task automatic gap(input [7:0] expected);
    begin
      @(negedge clk); uio_in=0;
      @(posedge clk); check(expected,1'b0,1'b0);
    end
  endtask
  task automatic setup_n(input [7:0] n);
    begin
      @(negedge clk); rst_n=0; uio_in=0;
      @(posedge clk); #1;
      if (uo_out !== 0) $fatal(1,"reset failed");
      @(negedge clk); rst_n=1; uio_in=n;
      @(posedge clk); #1;
      if (uio_oe !== 8'b00000011) $fatal(1,"config failed");
    end
  endtask
  initial begin
    $dumpfile("g07_runtime.vcd"); $dumpvars(0,g07_runtime_tb);
    setup_n(8'd2);
    sample(10,10,0); sample(1,10,0); sample(1,9,1);
    sample(20,20,0); gap(20); gap(20);
    sample(0,20,0); sample(0,19,1);
    setup_n(8'd1);
    sample(1,1,0); sample(0,0,1); sample(0,0,0);
    setup_n(8'd8);
    sample(10,10,0);
    repeat (7) sample(0,10,0);
    sample(0,9,1);
    $display("G07 RUNTIME WRAPPER PASS (%0d checks)",cases);
    $finish;
  end
endmodule
