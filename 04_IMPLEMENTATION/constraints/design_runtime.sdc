# G07 runtime Tiny Tapeout wrapper
# Clock 10 ns, IO delay 1 ns: gia dinh phan tich.

create_clock -name clk -period 10.0 [get_ports clk]

set_input_delay 1.0 -clock clk \
    [get_ports {ui_in[*] uio_in[*] ena rst_n}]

set_output_delay 1.0 -clock clk [all_outputs]
