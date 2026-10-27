# G07 · Phần điều khiển (Control)

---

## 1. G07 có phần điều khiển **rẻ về diện tích nhưng đắt về thời gian**

Phần điều khiển gồm **bộ đếm 3 bit** (`count_q`) và **logic ưu tiên**. Điều đáng chú ý: hai
thành phần này có chi phí **trái ngược nhau**.

| Thành phần | Diện tích | Trên đường tới hạn? | Đóng góp timing |
|---|---:|:-:|---:|
| Bộ đếm `count_q[2:0]` + bộ tăng + giải mã `== N−1` | 3 FF × 20,0192 + vài cổng ≈ **75 µm²** (10 %) | ❌ **không** (slack 6,01 ns so với 4,87 ns) | 0 |
| **Logic ưu tiên** (cell `_089_` sinh `gt`) | **7,5072 µm²** (1,0 %) | ✅ **có** | **1,03 ns = 25,6 %** |

```
 ┌──────────────────── PHẦN ĐIỀU KHIỂN ────────────────────┐
 │                                                          │
 │   valid_in ──┬───────────────────────────▶ (enable 11 FF)│
 │              │                                           │
 │              ├───────────────────────────▶ (D của valid_out — KHÔNG enable)
 │              │                                           │
 │              ▼                                           │
 │   ┌──────────────────────┐    ┌──────────────┐           │
 │   │ count_q[2:0]  3 FF   │───▶│ == N−1 (= 7)?│──▶ dec_now│
 │   │  gt=1      → 0       │    └──────────────┘           │
 │   │  ==N−1     → 0       │                               │
 │   │  ngược lại → +1      │                               │
 │   └──────────────────────┘                               │
 │                                                          │
 │   ┌──────────────────────────────────────────┐           │
 │   │ LOGIC ƯU TIÊN  — cell _089_ (a21boi_0)    │──▶ gt    │
 │   │ gt = (sample_in > peak_q)                 │  fanout 9│
 │   │ ⟹ lái chân S của 8 mux + logic count     │  1,03 ns │
 │   └──────────────────────────────────────────┘           │
 └──────────┬──────────────┬────────────────┬───────────────┘
            │ gt           │ dec_now        │ enable
            ▼              ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ mux chọn     │ │ mux chọn     │ │ mux giữ      │
    │ sample_in    │ │ dec vs peak_q│ │ (valid_in)   │
    └──────────────┘ └──────────────┘ └──────────────┘
        DATAPATH         DATAPATH         DATAPATH
```

## 2. Bảng tín hiệu điều khiển và tác dụng

| Tín hiệu | Nguồn | Rộng | Tác dụng lên datapath | Dòng RTL |
|---|---|---:|---|---:|
| `rst_n` | cổng vào | 1 | **Đồng bộ**, ưu tiên cao nhất: xoá 12 FF về 0 | 40 |
| `valid_in` | cổng vào | 1 | **Enable chung** cho 11 FF (`peak_out`, `count_q`); **đồng thời** là dữ liệu `D` của `valid_out` | 46–51 |
| `gt` = (`sample_in > peak_q`) | bộ so sánh | 1 | **Tín hiệu ưu tiên**: chọn `sample_in` cho `peak_d`, ép `count_d = 0` | 24 |
| `dec_now` = (`count_q == N−1`) | giải mã | 1 | Khi `gt = 0`: chọn nhánh suy giảm và đặt `count_d = 0` | 30 |
| `is_zero` = (`peak_q == 0`) | cây NOR 8 đầu vào | 1 | **Bão hoà**: chặn `peak_q − 1` khi `peak_q = 0` | 28, 31 |
| (`N ≤ 1`) | **hằng số biên dịch** | 0 | Với `N = 8` là hằng `false` ⟹ Yosys **loại bỏ** nhánh, **0 cell** | 27 |

### Bảng chân lý đầy đủ của phần điều khiển (`N = 8`)

| `rst_n` | `valid_in` | `gt` | `dec_now` | `is_zero` | `peak` kế tiếp | `count` kế tiếp | `valid_out` |
|:-:|:-:|:-:|:-:|:-:|---|---|:-:|
| 0 | × | × | × | × | **0** | **0** | 0 |
| 1 | 0 | × | × | × | giữ | giữ | **0** |
| 1 | 1 | **1** | × | × | **`sample_in`** | **0** | 1 |
| 1 | 1 | 0 | 0 | × | giữ | `count+1` | 1 |
| 1 | 1 | 0 | 1 | 0 | `peak − 1` | **0** | 1 |
| 1 | 1 | 0 | 1 | **1** | **0** (bão hoà) | **0** | 1 |

Hàng thứ ba là **ưu tiên tuyệt đối**: cột `dec_now` là `×` — nghĩa là khi có đỉnh mới,
**không quan trọng** bộ đếm đang ở đâu.

## 3. Quan hệ điều khiển ↔ datapath: ba mức ưu tiên lồng nhau

RTL thể hiện ưu tiên bằng chuỗi `if` / `else if`, và **thứ tự này là đặc tả**, không phải
chi tiết cú pháp:

```systemverilog
always_comb begin
    peak_d  = peak_q;                      // ⓪ MẶC ĐỊNH: giữ nguyên
    count_d = count_q;

    if (valid_in) begin                    // ① enable bao trùm
        if (sample_in > peak_q) begin      // ② ƯU TIÊN CAO NHẤT: đỉnh mới
            peak_d  = sample_in;
            count_d = '0;
        end else if (N <= 1) begin         // ③ hằng số — bị loại bỏ khi N ≥ 2
            …
        end else if (count_q == N-1) begin // ④ suy giảm theo lịch
            peak_d  = (peak_q == '0) ? '0 : peak_q - 1'b1;
            count_d = '0;
        end else begin                     // ⑤ chỉ đếm tiếp
            count_d = count_q + 1'b1;
        end
    end
end
```

| Mức | Cơ chế | Vì sao phải theo thứ tự này |
|---|---|---|
| ⓪ **gán mặc định** | Hai dòng đầu | Bảo đảm `always_comb` **không suy ra latch**. Nếu thiếu, mọi nhánh phải gán đủ cả hai biến — dễ sót |
| ① `valid_in` | Bao toàn bộ | Bảo đảm INV-6: khe trống **không** làm bộ đếm nhích ⟹ "suy giảm theo **số mẫu**, không theo **thời gian**" |
| ② **đỉnh mới** | Nhánh đầu | **Đây là toàn bộ nội dung Charter mục 9.** Đỉnh mới phải thắng, nếu không VU meter sẽ bỏ sót đỉnh ngắn — đúng thứ nó sinh ra để bắt |
| ③ `N ≤ 1` | Hằng số | Mã phòng thủ cho cấu hình `N = 1`. Với `N = 8` là mã chết, **0 cell** |
| ④ **suy giảm** | Nhánh ba | Chỉ chạy khi **không** có đỉnh mới |
| ⑤ **đếm tiếp** | `else` | `count` chỉ tăng khi **không** làm gì khác ⟹ chu kỳ suy giảm đúng `N` |

> 🔎 **Nếu đảo thứ tự ② và ④ thì sao?** Với `gt = 1` và `count_q = N−1` cùng lúc, đỉnh mới sẽ
> **bị nuốt**: `peak` tụt 1 thay vì nhảy lên `sample_in`. Với VU meter, đó là "bỏ sót đỉnh"
> — sai lầm nghiêm trọng nhất của loại mạch này. Golden model có ca bắt đúng lỗi này
> (`test_new_peak_priority_on_decay_boundary()`), nhưng **testbench RTL thì không** — ca ở
> dòng 41 rơi vào `count_q = 0`, không phải `N−1`. Xem `corner_cases.md` CC-13.

## 4. Vì sao bộ đếm **không** nằm trên đường tới hạn

Đây là một quan sát phản trực giác đáng dạy: bộ đếm **nhận** tín hiệu `gt` (vì `gt = 1` ép
`count_d = 0`), nên có vẻ nó phải chịu cùng độ trễ. Nhưng STA cho thấy khác:

| Endpoint | Là gì | Slack |
|---|---|---:|
| `_143_` … `_150_` | `peak_out[0..7]` | **4,87 ns** |
| `_153_` | `count_q[2]` | 5,03 ns |
| `_151_` | `count_q[0]` | **6,01 ns** |

**Lý do:** đường tới `peak_out` đi qua **hai** tầng sau `gt` (mux ưu tiên `_097_` rồi buffer
`_098_` = 0,27 + 0,06 = 0,33 ns), còn đường tới `count_q` chỉ qua **một** tầng logic đơn
giản hơn (chỉ cần ép về 0, không cần chọn giữa 8 bit dữ liệu). Chênh lệch 4,87 → 5,03 ns
đúng bằng phần chênh đó.

Và `count_q[0]` còn nhanh hơn nữa (6,01 ns) vì bit thấp nhất của bộ tăng chỉ là một phép đảo.

## 5. So sánh phần điều khiển ba đề G05 · G06 · G07

| | G05 | G06 | **G07** |
|---|---|---|---|
| Bộ đếm | `count_q[2:0]` (cửa sổ 8 mẫu) | **không có** | `count_q[2:0]` (chu kỳ suy giảm) |
| Số hành vi cạnh tranh | 3 (seed / tích luỹ / công bố) — **loại trừ nhau theo bộ đếm** | 1 | **2 — cạnh tranh thật** (đỉnh mới vs suy giảm) |
| Điều khiển trên đường tới hạn? | ✅ nhưng nhẹ (`nand3_1`, 0,15 ns) | ❌ (0 ns) | ✅ **nặng** (`a21boi_0`, **1,03 ns**) |
| Chi phí diện tích của điều khiển | ~4 % | ~9 % | ~11 % |
| Chi phí timing của điều khiển | 4 % của đường | 0 % | **26 %** của đường |

> **Quy luật rút ra:** điều khiển **loại trừ nhau** (G05: bộ đếm quyết định nhánh nào chạy)
> rẻ về timing, vì tín hiệu điều khiển sẵn sàng **từ đầu chu kỳ** (nó là đầu ra flip-flop).
> Điều khiển **cạnh tranh phụ thuộc dữ liệu** (G07: `gt` phải so sánh 8 bit xong mới biết)
> đắt, vì tín hiệu điều khiển chỉ sẵn sàng ở **cuối** đường dữ liệu rồi mới lan ngược ra
> toàn bộ bề rộng datapath.

## 6. Nghĩa vụ của tầng ngoài

| Nghĩa vụ | Vì sao G07 không tự làm | Hậu quả nếu vi phạm |
|---|---|---|
| `valid_in` là **xung một chu kỳ** mỗi mẫu | Khối đếm **cạnh lên có `valid_in = 1`**, không đếm mẫu | Đỉnh tụt nhanh gấp k lần đặc tả |
| Đưa vào **biên độ không dấu** (đã chỉnh lưu) | So sánh `>` không dấu | Mẫu "âm" (bit 7 = 1) sẽ bị coi là đỉnh rất lớn |
| Giữ `rst_n = 0` qua ≥ 1 cạnh lên | Reset **đồng bộ** | `peak_q` giữ `X` cho tới khi có mẫu lớn hơn |
| **Tự biết `N`** | `N` là tham số biên dịch, không có cổng — **lệch Charter mục 4** | Không đọc được tốc độ trôi từ phần cứng |
| **Tự suy ra "đang suy giảm"** | Cổng này không tồn tại — **lệch Charter mục 4** | Tầng ngoài phải so `peak_out` giữa hai chu kỳ có `valid_out = 1` |
| Hiểu rằng suy giảm theo **số mẫu**, không theo **thời gian** | Bộ đếm chỉ nhích khi `valid_in = 1` | Nếu tốc độ mẫu đổi, tốc độ trôi VU meter đổi theo — người dùng thấy lạ |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
