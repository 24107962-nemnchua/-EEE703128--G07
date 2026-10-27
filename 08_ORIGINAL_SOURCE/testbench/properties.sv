`ifdef G07_SVA

assert new_peak_never_decays_same_event:
    assert property (@(posedge clk)
        valid_in && sample_in > $past(peak_out)
        |-> valid_out);

`endif
