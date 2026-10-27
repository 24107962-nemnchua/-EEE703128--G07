# G07 · Đường dữ liệu (Datapath)

---

## 1. Đặc điểm datapath của G07: **hai nhánh cạnh tranh gặp nhau ở một mux**

Điểm phân biệt G07 với hai đề còn lại của nhóm: ở đây có **hai nguồn** cùng muốn ghi vào
**một** thanh ghi, và một tín hiệu **1 bit** phải phân xử giữa chúng — rồi lan quyết định đó
ra cả **tám** bit dữ liệu.

```
                   ┌───────── vòng giữ đỉnh (1 chu kỳ) ────────────┐
                   ▼                                               │
   sample_in[7:0] ═╦═══════════════════════════════╗               │
                   ║          peak_q[7:0]          ║               │
                   ║               ║               ║               │
          ┌────────╨───────────────╨────┐    ┌─────╨──────────┐    │
          │ SO SÁNH  s > peak_q          │    │ SUY GIẢM       │    │
          │ (chuỗi borrow 8 tầng)        │    │ peak_q − 1     │    │
          └──────────────┬───────────────┘    │ bão hoà tại 0  │    │
                         │ gt  (1 BIT)        └────────┬───────┘    │
                         │                             ║ dec[7:0]   │
                         │   ┌─────────────────────────╨──────┐     │
                         └──▶│ MUX 8 BIT — gt lái chân CHỌN   │     │
   dec_now ─────────────────▶│                                │     │
   peak_q ══════════════════▶│                                │     │
   sample_in ═══════════════▶└──────────────┬─────────────────┘     │
                                            ║ peak_d[7:0]           │
                                   ┌────────╨────────┐              │
                                   │ peak REG  8 FF  │══════════════┘
                                   └─────────────────┘

   ⚠ Chỗ đắt: gt là 1 BIT nhưng phải lái 8 MUX  ⟹  FANOUT 9, SLEW 1,26 ns, DELAY 1,03 ns
```

## 2. Bảng các đường dữ liệu

| Đường | Bit | Từ | Đến | Bản chất | Trên đường tới hạn? |
|---|---:|---|---|---|:-:|
| `sample_in[7:0]` | 8 | cổng vào | bộ so sánh **và** mux ① | Dữ liệu vào | ✅ (từ bit 0) |
| `peak_q[7:0]` = `peak_out[7:0]` | 8 | REG (chính là cổng ra) | bộ so sánh, bộ trừ, cây NOR, mux ③ | **Trạng thái hồi tiếp**, fanout ~4 nguồn | ✅ |
| `gt` (nội bộ) | **1** | bộ so sánh (`_089_/Y`) | chân **`S`** của 8 mux + logic bộ đếm | **TÍN HIỆU QUYẾT ĐỊNH ƯU TIÊN** — fanout **9** | ✅ **đắt nhất** |
| `is_zero` (nội bộ) | 1 | cây NOR 8 đầu vào của `peak_q` | mux bão hoà | Bảo vệ chống wrap | ❌ |
| `dec[7:0]` (nội bộ) | 8 | bộ trừ 1 + bão hoà | mux ② | Giá trị sau suy giảm | ❌ nhánh ngắn hơn |
| `dec_now` (nội bộ) | 1 | giải mã `count_q == N−1` | chân chọn thứ hai của mux | Điều khiển | ❌ |
| `peak_d[7:0]` | 8 | mux ưu tiên | `peak` REG | Giá trị sẽ chốt | ✅ |
| `count_q[2:0]` | 3 | REG | bộ tăng + bộ giải mã | **Điều khiển** — xem `control.md` | ❌ (slack 6,01 ns) |
| `valid_in` | 1 | cổng vào | enable 11 FF + `D` của `valid_out` | Điều khiển | ❌ |

> 🔎 **So sánh fanout giữa ba đề — đây là chỗ khác biệt quyết định:**
>
> | Đề | Tín hiệu quyết định 1 bit | Fanout | Delay của cell lái nó |
> |---|---|---:|---:|
> | G05 | `lt` / `gt` (2 tín hiệu riêng cho nhánh min và max) | **7** (`_251_/Y`) | 0,37 ns (`o221ai_1`) |
> | G06 | *(không có)* — dữ liệu chảy dọc bit, không có quyết định chung | — | — |
> | **G07** | **`gt` (một tín hiệu, lái 8 mux + logic đếm)** | **9** | **1,03 ns** (`a21boi_0`) |
>
> G05 cũng có tín hiệu quyết định fanout 8, nhưng cell lái nó chỉ tốn 0,37 ns. Chênh lệch
> gần **3 lần** so với G07 nằm ở **slew**: báo cáo ghi `_089_/Y` có slew **1,26 ns**, trong
> khi `_251_/Y` của G05 có slew 0,45 ns. Slew lớn ⟹ sườn tín hiệu thoải ⟹ cell sau nhận chậm.
> Đây là vấn đề **lái tải** (drive strength), và cách chữa kinh điển là **chèn buffer** hoặc
> **nhân bản** cell quyết định — cả hai đều thuộc bước P&R, **chưa chạy**.

## 3. Đồ thị phụ thuộc và độ sâu logic

```
 mức 0    sample_in[0], peak_q[0] ────────────────────────────┐
             │                                                 │ (bypass: sample_in
 mức 1    borrow[1] = f(s[0], p[0])                            │  đi thẳng vào mux)
             │                                                 │
 mức 2–8  borrow[2] … borrow[8]  ← CHUỖI NỐI TIẾP 8 TẦNG       │
             │                                                 │
 mức 9    gt = borrow[8]  ────┬──────────────────────┐         │
                              │                      │         │
                              │ (fanout 9 — ĐẮT)     │         │
 mức 10   ┌───────────────────▼──────────┐   ┌───────▼──────┐  │
          │ MUX bit 0 ◀──────────────────┼───┤ logic count  │  │
          │ MUX bit 1                     │   │ (count ← 0)  │  │
          │  …           ◀────────────────┼───┘              │  │
          │ MUX bit 7                     │◀─────────────────┼──┘
          └───────────────┬───────────────┘                  │
 mức 11   ┌───────────────▼───────────────┐                  │
          │ D của peak REG (mux enable)    │                  │
          └────────────────────────────────┘

 NHÁNH SONG SONG (ngắn hơn, KHÔNG tới hạn):
 mức 0    peak_q[7:0] ──▶ cây NOR 8 đầu vào (is_zero)  ──┐  mức ~3
                      └──▶ bộ trừ 1 (chuỗi borrow ngắn) ─┴──▶ dec[7:0]  mức ~8
```

| Đích | Độ sâu lý thuyết | Slack thật (STA) | Nhận xét |
|---|---|---:|---|
| `peak_out[0]` … `peak_out[7]` | ~11 | **4,87 ns — cả tám BẰNG NHAU** | Mọi bit cùng chờ `gt` |
| `count_q[2]` (`_153_`) | ~10 | 5,03 ns | Cũng chờ `gt`, nhưng ít tầng mux hơn |
| `count_q[0]` (`_151_`) | ~3 | **6,01 ns** | Nông nhất |
| `valid_out` (`_142_`) | 1 | — (không nằm trong 10 đường tệ nhất) | Chỉ là dây từ `valid_in` |

> **Slack của tám bit `peak_out` BẰNG NHAU** là chữ ký cấu trúc quan trọng nhất của G07.
> Nó nói rằng nút thắt **không** nằm ở đường dữ liệu 8 bit mà ở một **quyết định chung** phía
> trước. Đối chiếu: ở G06 slack giảm đơn điệu theo bit (8,51 → 6,18 ns) vì mỗi bit phụ thuộc
> một số tầng carry khác nhau. Hai hình dạng số liệu khác hẳn nhau ⟹ hai kiến trúc khác hẳn nhau.

**Dự đoán trước khi mở STA:** đường tới hạn phải là
`sample_in[LSB] → chuỗi borrow 8 tầng → gt → mux → peak REG`, và **mọi bit của `peak_out`
phải có slack gần bằng nhau**.

## 4. Đối chiếu với STA thật — và trả lời Charter mục 9

| Hạng mục | Giá trị thật |
|---|---|
| Startpoint | `sample_in[0]` — **bit thấp nhất** ✅ đúng dự đoán |
| Endpoint | `_143_` = **`peak_out[0]`** ✅ (và 7 bit còn lại cùng slack) |
| Data arrival | **5,02 ns** (gồm **1,00 ns** `input external delay` giả định) |
| Độ trễ cell thật | 5,02 − 1,00 = **4,02 ns** |
| Slack | **4,87 ns** — **chặt nhất** trong ba đề G05/G06/G07 |
| Số cell | 12 |
| WNS / TNS | 0,00 / 0,00 |

### Dự đoán ĐÚNG cả ba mặt

| Dự đoán | STA thật | Khớp? |
|---|---|:-:|
| Startpoint là bit **thấp** | `sample_in[0]` | ✅ |
| Nút thắt là **chuỗi so sánh nối tiếp** | 7 × `maj3_1` = 2,62 ns = **65,2 %** của 4,02 ns | ✅ |
| Tám bit `peak_out` có slack **bằng nhau** | cả 8 đều **4,87 ns** | ✅ |

### Chỗ dự đoán **thiếu** — và đây mới là phát hiện

Dự đoán từ RTL coi `gt → mux` là "một tầng mux, rẻ". Thực tế nó là **tầng đắt nhất**:

```
  _089_ (a21boi_0):  delay 1,03 ns · fanout 9 · slew đầu ra 1,26 ns
  _097_ (mux2i_1) :  delay 0,27 ns  (nhận tín hiệu có slew 1,26 ns ở chân S)
  ────────────────────────────────────────────────────────────────────
  TỔNG tầng "lan quyết định":  1,30 ns  =  32,3 %  của 4,02 ns
```

**Vì sao đắt:** `gt` là **một** tín hiệu phải lái **chín** tải. Cell `a21boi_0` là cell
**sức lái yếu** (hậu tố `_0` trong sky130 nghĩa là drive strength thấp nhất, diện tích
7,5072 µm²). Nó nạp điện cho 9 chân đầu vào ⟹ sườn tín hiệu thoải ⟹ slew 1,26 ns ⟹ cell sau
nhận chậm. Đây là **bài toán lái tải**, không phải bài toán độ sâu logic.

### Trả lời trực tiếp Charter mục 9

> *"Thiết kế có hai hành vi cạnh tranh: cập nhật đỉnh và suy giảm. Nêu rõ cách mình xử lý khi
> cả hai xảy ra cùng chu kỳ, và chỉ ra phần logic quyết định thứ tự ưu tiên."*

**(a) Xử lý thế nào khi cả hai xảy ra cùng chu kỳ:** **cập nhật đỉnh thắng tuyệt đối**. Cơ
chế là thứ tự `if` / `else if` trong `always_comb`: nhánh `sample_in > peak_q` nằm **trước**,
nên trình tổng hợp dựng nó thành nhánh **ưu tiên cao hơn** của cây mux. Khi `gt = 1`, hai
nhánh suy giảm **không bao giờ** được chọn, bất kể `count_q` bằng bao nhiêu. Bộ đếm cũng bị
đặt về 0 trong cùng nhịp (`count_d = '0`), nên "đồng hồ suy giảm" khởi động lại từ đầu.

**(b) Phần logic nào quyết định thứ tự ưu tiên — chỉ đích danh bằng số:**

| Hạng mục | Giá trị |
|---|---|
| Instance | **`_089_`** |
| Loại cell | `sky130_fd_sc_hd__a21boi_0` |
| Diện tích cell | 7,5072 µm² (từ Liberty) = **1,0 %** diện tích thiết kế |
| Vai trò | Sinh tín hiệu `gt` — kết quả cuối của chuỗi so sánh |
| Đi tới đâu | Chân **`S`** (select) của `_097_ (mux2i_1)` và 8 tải khác |
| Fanout | **9** |
| Slew đầu ra | **1,26 ns** |
| Delay | **1,03 ns** = **25,6 %** toàn bộ độ trễ cell của đường tới hạn |

**Kết luận bằng số:** *phần logic quyết định ưu tiên chiếm **1,0 %** diện tích nhưng **25,6 %**
đường tới hạn.* Đây là một đánh đổi đáng chú ý: ưu tiên **rẻ về diện tích, đắt về thời gian**,
vì nó bản chất là một tín hiệu điều khiển fanout cao.

**Cách cải thiện** (chưa áp dụng, thuộc bước P&R):

| Cách | Hiệu quả ước lượng | Chi phí |
|---|---|---|
| Thay `a21boi_0` bằng biến thể sức lái mạnh hơn (`_1`, `_2`, `_4`) | Giảm slew ⟹ giảm cả 1,03 ns lẫn 0,27 ns | +vài µm² |
| Chèn buffer, chia tải làm 2 nhóm | Giảm fanout mỗi nhánh còn ~4–5 | +1–2 cell |
| Nhân bản cell `_089_` (logic replication) | Mỗi bản lái ít tải hơn | +7,5 µm²/bản |
| Tính `gt` **sớm hơn** bằng bộ so sánh nhanh (thay chuỗi borrow) | Giảm 2,62 ns nhưng **không** giảm 1,30 ns của tầng lan | +diện tích tổ hợp |

> ⚠️ Cả bốn đều là **ước lượng định tính** — chưa chạy tool nào để xác nhận. Và với slack
> hiện tại **4,87 ns / 10 ns**, việc tối ưu này là **không cần thiết**. Ghi ở đây để trả lời
> "nếu cần nhanh hơn thì làm gì", và vì Charter mục 3 liệt "tự tối ưu netlist bằng tay" vào
> **ngoài phạm vi**.

## 5. Vòng giữ và đường hold

`06_GDSII/sta/timing_report_min.txt` cho 5 đường ngắn nhất, **tất cả** đều dạng `_1xx_ → _1xx_`:

| Startpoint = Endpoint | Là thanh ghi nào | Slack hold |
|---|---|---:|
| `_152_` | `count_q[1]` | **0,50 ns** |
| `_151_` | `count_q[0]` | 0,51 ns |
| `_145_` | `peak_out[2]` | 0,52 ns |
| `_149_` | `peak_out[6]` | 0,52 ns |
| `_146_` | `peak_out[3]` | 0,52 ns |

Đây là **mux giữ** sinh ra từ `if (valid_in)` (dòng 47): khi enable không tích cực, thanh
ghi phải nạp lại chính giá trị cũ của nó. Ba điều rút ra:

1. Vòng này tồn tại ở **mọi** thanh ghi có enable, vì `sky130_fd_sc_hd` **không có**
   flip-flop kèm chân enable — tool phải dựng bằng mux (`mux2_1 × 7` trong netlist).
2. `valid_out` **không** xuất hiện trong danh sách, đúng như dự đoán: nó **không có enable**
   (dòng 46 nằm ngoài `if (valid_in)`), nên không có vòng giữ.
3. Biên hold **0,50 ns** tính với **clock lý tưởng, skew = 0**. Sau CTS, skew thật trừ thẳng
   vào con số này.

## 6. Vì sao datapath **không** cần thanh ghi lưu `N`

| Câu hỏi | Trả lời | Bằng chứng |
|---|---|---|
| `N` được lưu ở đâu? | **Không ở đâu cả.** Nó là hằng số biên dịch, "đông cứng" vào các cổng giải mã | Netlist chỉ có `peak_out`, `count_q`, `valid_out`. Không có wire nào tên `N` |
| Charter dự kiến 8 FF để "giữ N" — vì sao không có? | Vì Charter giả định `N` nạp qua `uio_in[7:0]` lúc chạy. RTL chọn cách khác | `functional_spec.md` cảnh báo C4-1 |
| Lợi gì? | Tiết kiệm **8 FF = 160,15 µm²** (21 % diện tích) **và** bộ so sánh `count_q == N−1` rút từ 8 bit xuống 3 bit | `dfxtp_1` = 20,0192 µm² |
| Mất gì? | **Không đổi được `N` sau khi chế tạo.** Một VU meter thương mại thường cần chỉnh tốc độ trôi | — |
| Và mất gì nữa về kiểm chứng? | Mỗi giá trị `N` là **một mạch khác**, phải tổng hợp và mô phỏng riêng. Hiện mô phỏng dùng `N = 2`, tổng hợp dùng `N = 8` | `corner_cases.md` §5.1 |

> 🔎 Đây là đánh đổi **tham số hoá lúc biên dịch** (compile-time) so với **cấu hình lúc chạy**
> (run-time). Nó rẻ hơn nhiều về phần cứng, nhưng **nhân đôi công sức kiểm chứng** và mất
> tính linh hoạt. Với một ô Tiny Tapeout chỉ nạp được một lần, đây có thể là lựa chọn hợp lý —
> nhưng nó **lệch Charter**, và hồ sơ phải nói rõ.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
