# G07 · Sơ đồ khối bên trong (Block Diagram)

> Vẽ theo **đúng** `04_IMPLEMENTATION/rtl/g07_peak_decay.sv` (55 dòng), đối chiếu với
> `06_GDSII/synthesis/netlist.v` (tổng hợp với `W = 8`, `N = 8` ⟹ `CW = 3`).

---

## 1. Sơ đồ khối — đúng cấu trúc RTL

```
                             ┌───────── VÒNG GIỮ ĐỈNH (1 chu kỳ) ──────────┐
                             │                                             │
                             ▼                                             │
  sample_in[7:0] ═════╦══════════════════════════════════════╗             │
                      ║   peak_q[7:0]                        ║             │
                ┌─────╨───────╨─────┐                        ║             │
                │  SO SÁNH KHÔNG DẤU│                        ║             │
                │  s > peak_q ?     │  ← chuỗi BORROW 8 tầng ║             │
                │  (7 × maj3_1)     │                        ║             │
                └─────────┬─────────┘                        ║             │
                          │ gt  (1 bit, FANOUT 9)            ║             │
                          │                                  ║             │
                          │      ┌───────────────────────────╨──────┐      │
                          │      │ SUY GIẢM CÓ BÃO HOÀ               │      │
                          │      │ (peak_q == 0) ? 0 : peak_q − 1    │      │
                          │      │  — bộ trừ 1 + cây NOR 8 đầu vào   │      │
                          │      └───────────────┬──────────────────┘      │
                          │                      ║ dec[7:0]                │
                          │       ┌──────────────╨───────────┐             │
                          └──────▶│  MUX ƯU TIÊN  (8 bit)    │             │
                                  │  gt=1 → sample_in        │             │
                    dec_now ─────▶│  gt=0 & dec_now → dec    │             │
                                  │  ngược lại   → peak_q    │             │
                                  └──────────────┬───────────┘             │
                                                 ║ peak_d[7:0]             │
                                      ┌──────────╨──────────┐              │
              valid_in ──────────────▶│ peak REG  8 FF      │══▶ peak_out ═┘
                                      │ (= peak_q, đã hợp   │    [7:0]
                                      │  nhất bởi Yosys)    │
                                      └─────────────────────┘

                      ┌────────────────────────────────────────┐
                      │  BỘ ĐẾM SUY GIẢM                        │
   gt ───────────────▶│  gt=1        → count ← 0                │
                      │  count=N−1   → count ← 0 , dec_now = 1  │──▶ dec_now
   valid_in ─────────▶│  ngược lại   → count ← count+1          │
                      │  count_q[2:0] — 3 FF  ($clog2(8))       │
                      └────────────────────────────────────────┘

   valid_in ─────────▶┌───────────────────┐
                      │ valid_out   1 FF  │──▶ valid_out   (KHÔNG có enable)
                      └───────────────────┘
   rst_n ─────────────────────────────────────▶ (gộp vào logic D — reset ĐỒNG BỘ)
   clk ───────────────────────────────────────▶
```

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Dòng RTL | Cấu trúc RTL | Phần cứng sinh ra | Bằng chứng netlist |
|---:|---|---|---|
| 13 | `localparam CW = (N<=1) ? 1 : $clog2(N);` | Quyết định **độ rộng bộ đếm** lúc **biên dịch**. `N = 8` ⟹ `CW = 3` | Netlist có `\count_q[0..2]` — **3 bit** |
| 15 | `logic [W-1:0] peak_q, peak_d;` | 8 `dfxtp_1` (hợp nhất với `peak_out`) | `_143_…_150_` → `.Q(peak_out[0..7])`; **không có** wire `\peak_q[…]` |
| 16 | `logic [CW-1:0] count_q, count_d;` | 3 `dfxtp_1` | `_151_`, `_152_`, `_153_` → `\count_q[0..2]` |
| 19–20 | `peak_d = peak_q; count_d = count_q;` | **Giá trị mặc định** ⟹ nhánh "giữ" của mux | mux giữ (`mux2_1 × 7`) |
| 24 | `if (sample_in > peak_q)` | **Bộ so sánh không dấu 8 bit** — chuỗi borrow nối tiếp | `maj3_1 × 7` + `nand2b_1` + `a21boi_0` |
| 25–26 | `peak_d = sample_in; count_d = '0;` | Nhánh ① của mux ưu tiên | `mux2i_1 × 8` (một cho mỗi bit) |
| 27–29 | `else if (N <= 1)` | **Hằng `false` khi `N = 8`** ⟹ Yosys **loại bỏ hoàn toàn**. **0 cell** | Không có logic tương ứng trong netlist |
| 28, 31 | `(peak_q == '0) ? '0 : peak_q - 1'b1` | **Bộ trừ 1** (8 bit) + **cây NOR 8 đầu vào** để phát hiện `peak_q == 0` | `nor2_1 × 5`, `nor3b_1`, `or4_1`, `xor2_1 × 3` |
| 30 | `else if (count_q == N-1)` | Giải mã `count_q == 7` = `AND3` | `and3_1 × 1`, `nand3_1 × 2` |
| 34 | `count_d = count_q + 1'b1;` | Bộ tăng 3 bit | `xnor2_1`, `and2_0` |
| 39 | `always_ff @(posedge clk)` | 12 `dfxtp_1` dùng chung `clk` | mọi FF có `.CLK(clk)` |
| 40–44 | `if (!rst_n)` | **Reset đồng bộ** ⟹ gộp vào logic `D` | Netlist dùng **`dfxtp_1`** (không chân reset), không phải `dfrtp_1` |
| 46 | `valid_out <= valid_in;` | **Không enable** — nạp mỗi chu kỳ | `_142_` → `.Q(valid_out)` |
| 47–51 | `if (valid_in) begin peak_q…; count_q…; peak_out…; end` | **Clock enable** cho 11 FF còn lại ⟹ mux giữ trên đường `D` | `mux2_1 × 7` + `lpflow_isobufsrc_1 × 8` |

### Đối chiếu số lượng flip-flop

| Nguồn | Số FF | Ghi chú |
|---|---:|---|
| Đọc RTL bằng tay (`N = 8`) | 8 (`peak_q`) + 3 (`count_q`) + 8 (`peak_out`) + 1 (`valid_out`) = **20** | |
| Netlist thật | **12** | `synth_stat.txt`: `dfxtp_1 × 12` |
| Chênh lệch | **8** | Yosys **hợp nhất `peak_q` vào `peak_out`** (cùng `D`, cùng enable, cùng reset) |
| Charter mục 10 dự kiến | 24–25 | ❌ **lệch**, nhưng có lý do cấu trúc — xem `functional_spec.md` cảnh báo đầu file |
| Nếu tổng hợp với `N = 2` (cấu hình của testbench) | **10** | `$clog2(2) = 1` ⟹ `count_q` chỉ 1 bit |

> 🔎 **Hai điều rút ra từ bảng này:**
>
> 1. `peak_q` và `peak_out` bị hợp nhất **giống hệt** trường hợp `y_q`/`y` ở G06. Ngược lại,
>    ở G05 thì `min_q` và `min_out` **không** hợp nhất được, vì chúng có **enable khác nhau**
>    (`valid_in` so với `valid_in && count==7`). Ba đề cho ba kết quả khác nhau từ **cùng một
>    quy tắc tối ưu** — đây là ví dụ tốt để dạy `opt_dff`/`opt_merge`.
> 2. Số flip-flop **phụ thuộc giá trị `N`**. Mọi con số trong hồ sơ này là của `N = 8`.

## 3. Khối con nào nằm trên **đường tới hạn**

Đối chiếu `06_GDSII/sta/timing_report_max.txt`, đường xấu nhất:

```
 sample_in[0]  (t = 1,00 ns — toàn bộ là input external delay GIẢ ĐỊNH)
   └─▶ _081_ nand2b_1  +0,04 → 1,04 ns
       └─▶ _082_ maj3_1 +0,35 → 1,38 ns ┐
           └─▶ _083_ maj3_1 +0,35 → 1,74 │
               └─▶ _084_ maj3_1 +0,35 → 2,09 │
                   └─▶ _085_ maj3_1 +0,35 → 2,44 ├ CHUỖI BORROW của BỘ SO SÁNH
                       └─▶ _086_ maj3_1 +0,35 → 2,80 │  (7 tầng, 2,62 ns)
                           └─▶ _087_ maj3_1 +0,37 → 3,17 │
                               └─▶ _088_ maj3_1 +0,50 → 3,67 ┘  ← fanout 11
                                   └─▶ _089_ a21boi_0 +1,03 → 4,69 ns  ⚠ CELL ĐẮT NHẤT
                                       │                    (fanout 9, slew 1,26 ns)
                                       │   ← ĐÂY LÀ TÍN HIỆU "gt": LOGIC QUYẾT ĐỊNH ƯU TIÊN
                                       └─▶ _097_ mux2i_1 (chân S!) +0,27 → 4,96 ns
                                           └─▶ _098_ lpflow_isobufsrc_1 (chân SLEEP) +0,06 → 5,02
                                               └─▶ _143_/D dfxtp_1 = peak_out[0]
```

| Khối con | Trên đường tới hạn? | Đóng góp | % của 4,02 ns độ trễ cell |
|---|:-:|---:|---:|
| **Chuỗi borrow của bộ so sánh** (7 × `maj3_1`) | ✅ | **2,62 ns** | **65,2 %** |
| **Cell quyết định ưu tiên `_089_`** (`a21boi_0`) | ✅ | **1,03 ns** | **25,6 %** |
| Mux ưu tiên `_097_` (chân **`S`**) | ✅ | 0,27 ns | 6,7 % |
| Buffer `_098_` | ✅ | 0,06 ns | 1,5 % |
| Cổng đầu `_081_` | ✅ | 0,04 ns | 1,0 % |
| **Bộ trừ 1 + cây NOR (suy giảm)** | ❌ | — | nhánh song song, ngắn hơn |
| **Bộ đếm `count_q`** | ❌ | — | endpoint `_151_` có slack 6,01 ns so với 4,87 ns |
| Logic `valid_out` | ❌ | — | 1 cell, slack lớn |

> 🔎 **Ba điều đáng nói nhất trong toàn bộ hồ sơ G07:**
>
> 1. **Logic quyết định ưu tiên NẰM TRÊN đường tới hạn, và nó là cell đắt nhất.** Cell
>    `_089_` tốn **1,03 ns** — **gấp gần ba lần** một `maj3_1` (0,35 ns) và chiếm **25,6 %**
>    toàn bộ độ trễ cell. Lý do đọc thẳng từ báo cáo: **fanout 9** và **slew 1,26 ns**. Tín
>    hiệu `gt` phải lái chân chọn của **tám** mux (một cho mỗi bit `peak`) cộng logic bộ đếm.
>    Đây là câu trả lời **bằng số** cho Charter mục 9. Chi tiết: `datapath.md` §4.
> 2. **Đích là `peak_out[0]` — bit THẤP nhất, và cả 8 bit có slack BẰNG NHAU (4,87 ns).**
>    Vì mọi bit `peak_out` cùng chờ **một** tín hiệu `gt`, chúng ổn định gần như đồng thời.
>    Tương phản rõ với G06, nơi slack giảm đơn điệu theo bit. Chữ ký khác nhau ⟹ cấu trúc
>    khác nhau: ở G06 dữ liệu chảy dọc bit, ở G07 một quyết định chung lan ngang.
> 3. **`lpflow_isobufsrc_1` xuất hiện 8 lần và nằm trên đường tới hạn.** Đây là cell **cách
>    ly nguồn** (power isolation) của sky130, nhưng `abc` dùng nó làm **cổng logic thường**
>    (chân `SLEEP` như một đầu vào enable) vì nó rẻ. Hoàn toàn hợp lệ, nhưng cần biết khi đọc
>    netlist — đừng tưởng thiết kế có power gating. Cần kiểm ở gate-level (`corner_cases.md` GL-6).

## 4. So sánh ba đề G05 · G06 · G07 — cùng thư viện, cùng tổ hợp công cụ

| Chỉ số | G05 (min/max 8 mẫu) | G06 (IIR 1/2) | **G07 (peak decay)** |
|---|---:|---:|---:|
| Số cell | 202 | 54 | **83** |
| Flip-flop | 36 | 9 | **12** |
| Diện tích | 1681,6128 µm² | 482,9632 µm² | **754,4736 µm²** |
| Độ trễ đường tới hạn | 3,66 ns | 3,75 ns | **5,02 ns** ← **lớn nhất** |
| Slack | 6,22 ns | 6,18 ns | **4,87 ns** ← **chặt nhất** |
| Số cell trên đường tới hạn | 10 | 10 | **12** |
| Cell đắt nhất trên đường | 0,37 ns | 0,40 ns | **1,03 ns** |
| Công suất tuần tự | 82,1 % | 71,2 % | 73,2 % |

**G07 chậm nhất dù không phải lớn nhất.** Lý do không nằm ở quy mô mà ở **hình dạng**: G05 và
G06 có **một** chuỗi lan truyền rồi ghi thẳng vào thanh ghi; G07 có chuỗi so sánh **rồi còn
phải** lan một quyết định 1 bit ra **tám** mux. Tầng "lan ngang" đó là 1,03 + 0,27 = **1,30 ns**,
tức **32 %** đường — chi phí của việc có **hai hành vi cạnh tranh**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
