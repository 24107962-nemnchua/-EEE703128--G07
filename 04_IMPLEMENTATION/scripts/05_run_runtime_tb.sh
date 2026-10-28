#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p 05_VERIFICATION/waveforms
iverilog -g2012 -s g07_runtime_tb -o /tmp/g07_runtime_tb.vvp \
  04_IMPLEMENTATION/rtl/g07_peak_decay_runtime.sv \
  04_IMPLEMENTATION/rtl/tt_um_eee703128_g07.sv \
  05_VERIFICATION/testbench/g07_runtime_tb.sv
vvp /tmp/g07_runtime_tb.vvp | tee 05_VERIFICATION/runtime_simulation.log
mv -f g07_runtime.vcd 05_VERIFICATION/waveforms/g07_runtime.vcd
