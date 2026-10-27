# G07 · Ca biên và ca kiểm thử (Corner Cases)

> Tài liệu này **đọc testbench thật** (`05_VERIFICATION/testbench/g07_tb.sv`, 60 dòng) và
> **mô hình chuẩn thật** (`05_VERIFICATION/golden_model/reference_model.py`, 91 dòng).
>
> ⚠️ **Đọc §5 trước khi tin bất kỳ kết luận nào về độ phủ.** Testbench chạy với **`N = 2`**,
> trong khi netlist tổng hợp với **`N = 8`**. Mô phỏng PASS và số liệu vật lý nói về **hai
> cấu hình khác nhau**.

---

## 1. Ca bắt buộc của Charter mục 8 — và **vì sao** chọn từng ca

Charter mục 8 yêu cầu: *một đỉnh rồi im lặng (quan sát suy giảm) · đỉnh mới cao hơn · đỉnh
mới thấp hơn · N nhỏ và N lớn.*

| ID | Ca | **Lý do kỹ thuật** — nó tấn công lỗi nào | TB SV (`N=2`) | Golden Python |
|---|---|---|:-:|:-:|
| **CC-1** | **Một đỉnh rồi im lặng** | Ca **duy nhất** thấy được cơ chế suy giảm. Nếu quên bộ đếm (rủi ro Charter mục 10), đỉnh tụt **mỗi chu kỳ** thay vì mỗi `N` chu kỳ — sai số phát hiện được ngay ở mẫu thứ hai | ✅ dòng 37–38 (`send(1,10)` rồi `send(1,9)`) | ✅ `test_decay_N8()`, `test_lower_sample_not_immediate_update()` |
| **CC-2** | **Đỉnh mới cao hơn** | Kiểm nhánh ưu tiên ①. Nếu thứ tự `if` bị đảo, đỉnh mới có thể bị suy giảm ghi đè | ✅ dòng 34 (`send(10,10)`) và dòng 41 (`send(20,20)`) | ✅ `test_new_peak()` |
| **CC-3** | **Đỉnh mới thấp hơn** | Kiểm rằng đỉnh **không** bị kéo xuống ngay. Đây là bản chất của "peak hold": đỉnh chỉ tụt **theo lịch trình**, không theo dữ liệu | ✅ dòng 37–38 | ✅ `test_lower_sample_not_immediate_update()` |
| **CC-4** | **N nhỏ** | `N` nhỏ ⟹ tụt nhanh, VU meter "nhạy". Kiểm rằng bộ đếm hẹp vẫn đúng | ✅ **toàn bộ TB dùng `N = 2`** | ✅ `test_decay_N1()`, `test_new_peak_priority_on_decay_boundary()` (`N=2`) |
| **CC-5** | **N lớn** | `N` lớn ⟹ đỉnh giữ lâu. Kiểm rằng bộ đếm rộng hơn đếm đủ vòng | ❌ **KHÔNG CÓ trên RTL** | ✅ `test_decay_N8()`, `test_small_vs_large_N()`, `test_counter_state()` (`N` tới 16) |

> 🔎 **Phát hiện đáng chú ý thứ nhất:** Charter mục 8 bắt buộc cả "N nhỏ **và** N lớn", nhưng
> vì `N` là **tham số biên dịch** chứ không phải cổng, testbench chỉ kiểm được **một** giá trị
> trong **một** lần biên dịch. Nó chọn `N = 2`. Muốn phủ "N lớn" phải **biên dịch lại** với
> `N` khác — việc này **chưa làm**. Đây là hệ quả trực tiếp của khoảng cách RTL ↔ Charter mục 4
> đã ghi ở đầu `functional_spec.md`: nếu `N` là cổng như Charter yêu cầu, một lần chạy sẽ
> phủ được cả hai.

## 2. Ca tự xây dựng đã có trong testbench

| ID | Ca | Vị trí | Lý do kỹ thuật |
|---|---|---|---|
| **CC-6** | **Ca biên bão hoà 0** | TB dòng 44–50: reset, `send(1,1)`, `send(0,1)`, `send(0,0)`, `send(0,0)` | Kiểm rằng `peak = 0` khi đến lúc tụt thì **giữ 0**, không wrap thành 255. Đây là ca biên **quan trọng nhất** của đề — lỗi wrap sẽ làm VU meter nhảy từ im lặng lên hết thang |
| **CC-7** | **Reset giữa dòng** | TB dòng 44–46 (`rst_n = 0` một chu kỳ rồi lên lại) | Ca duy nhất kiểm reset **khi mạch đang có trạng thái** (`peak = 20`, `count = 0`). Xác nhận reset đồng bộ xoá được cả `peak` lẫn `count` |
| **CC-8** | **Ưu tiên đỉnh mới đúng ranh giới suy giảm** | TB dòng 41 — tại đó `count_q = 0`… **xem ghi chú dưới** | Golden có ca này đúng ranh giới (`test_new_peak_priority_on_decay_boundary()`: `[10,1,20]` với `N=2` ⟹ ở mẫu 3, `count = 0` sau khi vừa tụt) |
| **CC-9** | **Khe `valid_in` thấp 3 chu kỳ** | TB dòng 53–55 | Kiểm INV-6: đỉnh **đóng băng**, bộ đếm **không** nhích, `valid_out = 0`. Quan trọng vì nó chốt ngữ nghĩa "suy giảm theo **số mẫu**, không theo **thời gian**" |

> ⚠️ **Về CC-8:** đọc kỹ chuỗi TB với `N = 2` thì tại `send(8'd20, 8'd20)` (dòng 41), bộ đếm
> **vừa** được đặt lại về 0 ở chu kỳ trước (vì chu kỳ trước đã tụt). Nghĩa là ca này kiểm
> "đỉnh mới khi `count = 0`", **không** phải "đỉnh mới **đúng lúc** `count = N−1`". Ca ranh
> giới thật sự chỉ có ở golden model. Xem CC-13 ở §5.

## 3. Phân loại ca theo tiêu chí kỹ thuật riêng của G07

Tiêu chí tự nhiên của đề này là **hai hành vi cạnh tranh** (Charter mục 9) và **vị trí của
bộ đếm**:

```
                            count_q
              0 … N−2  (chưa tới lúc tụt)   │   N−1  (ĐẾN LÚC TỤT)
            ┌────────────────────────────────┼──────────────────────────────┐
 s > peak   │  ① đỉnh mới thắng              │  ① đỉnh mới thắng            │
 (đỉnh mới) │  (không có cạnh tranh)         │  ⚔ CẠNH TRANH — ô quan trọng │
            │  CC-2 ✅                       │  nhất của đề. CC-13 ❌ RTL    │
            ├────────────────────────────────┼──────────────────────────────┤
 s ≤ peak   │  ④ chỉ đếm tiếp                │  ③ tụt 1 LSB, count ← 0      │
            │  CC-3 ✅                       │  CC-1 ✅                     │
            ├────────────────────────────────┼──────────────────────────────┤
 s ≤ peak   │  ④ đếm tiếp                    │  ③ BÃO HOÀ: giữ 0            │
 và peak=0  │  CC-6 ✅                       │  CC-6 ✅                     │
            └────────────────────────────────┴──────────────────────────────┘
```

| Lớp | Đặc trưng | Ca đại diện | Đã chạy trên RTL? |
|---|---|---|:-:|
| **L-A · đỉnh mới, không cạnh tranh** | `s > peak`, `count < N−1` | CC-2 | ✅ |
| **L-B · CẠNH TRANH** | `s > peak` **và** `count = N−1` | CC-13 | ❌ **chỉ golden** |
| **L-C · giữ đỉnh** | `s ≤ peak`, `count < N−1` | CC-3 | ✅ |
| **L-D · suy giảm** | `s ≤ peak`, `count = N−1`, `peak > 0` | CC-1 | ✅ |
| **L-E · bão hoà** | như L-D nhưng `peak = 0` | CC-6 | ✅ |
| **L-F · bằng nhau** | `s = peak` (không phải đỉnh mới) | CC-14 | ❌ **chỉ golden** |
| **L-G · giao thức** | `valid_in`, reset | CC-7, CC-9 | ✅ |

## 4. Ca **KHÔNG** áp dụng cho đề này — và vì sao

| Ca thường gặp | Vì sao **không** áp dụng cho G07 |
|---|---|
| **Tràn lên (overflow) của `peak`** | Không thể. `peak` chỉ nhận giá trị **bằng một mẫu đã có** (nhánh ①) hoặc **giảm 1** (nhánh ②③). Cả hai đều nằm trong `[0, 255]`. Không có phép cộng nào |
| **Tràn xuống (underflow)** | Được chặn tường minh bởi bão hoà `(peak_q == '0) ? '0 : peak_q - 1'b1` |
| Số có dấu / bù 2 | `sample_in` là **biên độ** (VU meter), luôn không âm. So sánh `>` không dấu là đúng |
| Làm tròn | Không có phép chia nào. Khác hẳn G06, nơi làm tròn là toàn bộ nội dung đề |
| Glitch tổ hợp trên đầu ra | `peak_out` và `valid_out` đều là chân `Q` của `dfxtp_1` ⟹ glitch bị thanh ghi lọc |
| **Suy giảm theo hàm mũ** | Charter mục 3: **ngoài phạm vi**. RTL tụt **tuyến tính** 1 LSB mỗi `N` mẫu |
| **Nhiều kênh** | Charter mục 3: ngoài phạm vi. Khối đơn kênh |
| **Giữ đỉnh vô hạn** | Charter mục 3: ngoài phạm vi. (Đạt được bằng `N` rất lớn, nhưng không phải chế độ riêng) |
| Trạng thái bất hợp lệ của bộ đếm | **Không tồn tại khi `N` là luỹ thừa của 2** (`N = 8` ⟹ 3 bit phủ kín 0…7). **Có tồn tại khi `N` không phải luỹ thừa của 2** — xem `fsm.md` §5 và CC-16 |

## 5. Ca còn **THIẾU** — khoảng trống kiểm chứng

### 5.1 Khoảng trống nghiêm trọng nhất: cấu hình kiểm chứng ≠ cấu hình tổng hợp

| Hạng mục | Giá trị | Bằng chứng |
|---|---|---|
| `N` dùng trong **mô phỏng** | **2** | `g07_tb.sv` dòng 6: `g07_peak_decay #(.W(8),.N(2)) dut(…)` |
| `N` dùng trong **tổng hợp / STA / công suất** | **8** (mặc định) | Netlist có `\count_q[0]`, `\count_q[1]`, `\count_q[2]` — **3 bit** = `$clog2(8)`. Với `N = 2` thì `$clog2(2) = 1` ⟹ chỉ 1 bit đếm ⟹ tổng **10** FF, không phải 12 |

**Hệ quả phải nói rõ trong mọi kết luận:**

```
  "Mô phỏng PASS"        →  đúng cho mạch  N = 2  (10 FF, chưa từng được tổng hợp)
  "83 cell · 12 FF ·
   754,4736 µm² ·
   5,02 ns"              →  đúng cho mạch  N = 8  (chưa từng được mô phỏng)
```

Hai khẳng định này **không** hỗ trợ lẫn nhau. Đây là khoảng trống kiểm chứng đáng kể, và nó
tồn tại **chỉ vì** `N` là tham số biên dịch thay vì cổng vào như Charter mục 4 yêu cầu.

**Cách khép kín** (chưa làm), chọn một trong hai:
- (a) Đổi testbench sang `N = 8` để khớp cấu hình tổng hợp — nhưng phải viết lại toàn bộ giá
  trị kỳ vọng (mỗi lần tụt cần 8 mẫu thay vì 2).
- (b) Chạy **hai** lần tổng hợp + STA, một cho `N = 2` và một cho `N = 8`, rồi báo cáo cả hai.
  Cách này còn trả lời luôn Charter mục 8 ("N nhỏ và N lớn") **bằng số liệu vật lý**.

### 5.2 Các ca thiếu khác

| ID | Ca thiếu | Vì sao cần | Chi phí |
|---|---|---|---|
| **CC-10** | **N lớn trên RTL** (ví dụ `N = 8` hoặc 16) | Charter mục 8 **bắt buộc**. Hiện chỉ có ở golden Python | biên dịch lại + ~20 dòng |
| **CC-11** | **`N = 1`** trên RTL | Nhánh `else if (N <= 1)` trong RTL là **mã chết** với `N ≥ 2` và **chưa bao giờ được mô phỏng**. Golden có (`test_decay_N1()`) | biên dịch lại + 5 dòng |
| **CC-12** | **Suy giảm dài**: đỉnh 255 rồi im lặng `255 × N` mẫu | Kiểm INV-8 và kiểm rằng bộ đếm **quay vòng đúng** hàng trăm lần liên tiếp. Ca hiện tại chỉ tụt **một** lần | ~10 dòng (vòng lặp) |
| **CC-13** | **CẠNH TRANH thật**: đỉnh mới **đúng lúc** `count = N−1` | Đây là ô quan trọng nhất trong bảng §3 và là **trọng tâm câu hỏi Charter mục 9**. Golden có; TB thì ca ở dòng 41 rơi vào `count = 0`, không phải `N−1` | 4 dòng |
| **CC-14** | **Mẫu bằng đỉnh** kéo dài ⟹ răng cưa chu kỳ `N+1` | Hành vi suy ra từ RTL ở `functional_spec.md` §4.1, **chưa ca nào kiểm**. Đáng kiểm vì nó gây nhấp nháy nếu `peak_out` dùng làm ngưỡng | 12 dòng |
| **CC-15** | **Khe `valid_in` ngay trước lúc tụt** (`count = N−1`) | CC-9 hiện đặt khe **sau** khi `count` vừa về 0 — trạng thái dễ nhất. Khe ở `count = N−1` kiểm rằng "đếm theo mẫu, không theo thời gian" ở đúng chỗ nhạy cảm | 4 dòng |
| **CC-16** | **`N` không là luỹ thừa của 2** (ví dụ `N = 5`) | `CW = 3` nhưng chỉ dùng 0…4 ⟹ **3 trạng thái bất hợp lệ**. RTL **không có** logic phục hồi. Nếu một bit lật, bộ đếm có thể kẹt | biên dịch lại + 6 dòng |
| **CC-17** | Chuỗi ngẫu nhiên có scoreboard trên RTL | Golden có `test_randomized()` 5000 chuỗi × 30 mẫu, **không chạy trên RTL** | ~25 dòng |
| **CC-18** | Bật `` `define G07_SVA `` **và** mở rộng property | `properties.sv` chỉ kiểm cờ `valid_out`, **không** kiểm `peak_out == sample_in` sau đỉnh mới — tức nó **không** kiểm INV-5 ở phần quan trọng | 1 cờ + 3 dòng |

### Độ phủ **thực tế** của lần chạy đã ghi log

`simulation.log`: `G07 TB completed`, `$finish` tại **136** — testbench chạy **hết**, không
assertion nào vi phạm.

**Cách nói trung thực:** *"Mô phỏng RTL chạy hết testbench với cấu hình `N = 2`, phủ 8 mẫu
qua 5 nhánh hành vi (đỉnh mới, giữ đỉnh, suy giảm, bão hoà 0, khe `valid_in`) và một lần
reset giữa dòng. Chưa kiểm: `N` lớn, `N = 1`, ca cạnh tranh đúng ranh giới, suy giảm dài, và
cấu hình `N = 8` vốn là cấu hình đã được tổng hợp."*

## 6. Ca cần **bổ sung** khi chuyển sang gate-level / post-layout

| ID | Ca | Vì sao chỉ xuất hiện ở tầng sau | Bằng chứng cần |
|---|---|---|---|
| **GL-1** | Chạy lại TB trên `netlist.v` — **nhưng phải đổi TB sang `N = 8`** | Netlist là mạch `N = 8`; testbench `N = 2` **không thể** dùng lại nguyên trạng. `test_matrix.csv`: `L4-GATE = CHUA CHAY` | Thư viện mô phỏng sky130 + TB sửa |
| **GL-2** | Ca **setup** trên đường `sample_in[0] → peak_out[0]` | STA: 5,02 ns, slack **4,87 ns** — **chặt nhất trong ba đề G05/G06/G07**. Chỉ mô phỏng có SDF mới thấy vi phạm khi chu kỳ co lại | SDF sau P&R |
| **GL-3** | Ca **fanout/slew** trên cell `_089_` | `timing_report_max.txt` ghi `_089_/Y`: **fanout 9**, **slew 1,26 ns**, delay **1,03 ns** — **hơn gấp đôi** mọi cell khác trên đường. Đây là tín hiệu ưu tiên lái 9 mux. Sau P&R, dây dài sẽ làm nó tệ hơn nữa | Trích xuất RC + STA sau routing |
| **GL-4** | Ca **hold** trên vòng giữ `count_q → count_q` | `timing_report_min.txt`: đường ngắn nhất `_152_ → _152_`, slack **0,50 ns**, tính với clock **lý tưởng** | Báo cáo CTS + SDF |
| **GL-5** | Ca công suất với VCD thật | Ước lượng 7,43e-05 W (tuần tự 73,2 %) dùng hoạt động mặc định. VU meter thật có hoạt động rất khác giữa lúc im lặng (chỉ `count` chạy) và lúc có tín hiệu (cả 8 bit `peak` chuyển mạch) | VCD từ GL-1 |
| **GL-6** | Kiểm cell `lpflow_isobufsrc_1` và `lpflow_inputiso1p_1` trong netlist | Yosys dùng **cell cách ly nguồn** (isolation) làm cổng logic thường. Cần xác nhận chúng hoạt động đúng khi **không** có power gating — thường là có, nhưng phải kiểm ở gate-level | Mô phỏng gate-level |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
