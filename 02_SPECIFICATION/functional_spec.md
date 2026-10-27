# G07 · Đặc tả chức năng (Functional Specification)

> ⚠️ **CẢNH BÁO ĐỐI CHIẾU CHARTER — nhiều yêu cầu Charter mục 4 CHƯA THOẢ.** Đây là đề có
> khoảng cách RTL ↔ Charter **lớn nhất** trong ba đề G05/G06/G07.
>
> | # | Yêu cầu Charter mục 4 | Trạng thái | Bằng chứng |
> |---|---|:-:|---|
> | C4-1 | `uio_in[7:0]` = **N** (tham số suy giảm, nạp qua chân) | ❌ **CHƯA THOẢ — thiếu hẳn cổng** | RTL khai báo `parameter int N = 8`, tức **hằng số biên dịch**, **không phải** cổng vào. Không có cách nào đổi `N` sau khi chế tạo |
> | C4-2 | `uio_out[0]` = **"đang suy giảm"** (cờ báo trạng thái) | ❌ **CHƯA THOẢ — thiếu hẳn cổng** | RTL chỉ có `valid_out`, vốn là bản trễ một nhịp của `valid_in`, **không** mang thông tin "đang suy giảm" |
> | C4-3 | `ui_in[7:0]` = mẫu · `uo_out[7:0]` = giá trị đỉnh hiện tại | ⚠️ **có tương đương ở mức lõi** | `sample_in[W-1:0]` và `peak_out[W-1:0]` |
> | C4-4 | Xử lý vượt ngân sách chân (25 bit / 24 chân) bằng **nạp hai nhịp** | ❌ **CHƯA THOẢ** | Không có logic nạp hai nhịp. Vấn đề bị **né** chứ không được giải: vì `N` không còn là cổng nên chỉ còn 9 bit vào + 9 bit ra = 18 bit |
> | C4-5 | Lớp vỏ Tiny Tapeout `tt_um_*` | ❌ **CHƯA TỒN TẠI** | RTL không có `ui_in`/`uo_out`/`uio_in`/`uio_out`/`uio_oe`/`ena` |
>
> 📌 **Hệ quả đo được của C4-1 và C4-2 — giải thích chênh lệch số ô nhớ.**
> Charter mục 10 nêu *"Dấu hiệu làm đúng: 8 (đỉnh) + 8 (đếm N) + 8 (giữ N) ≈ 24–25 ô nhớ."*
> Thiết kế thật chỉ có **12** flip-flop. Chênh lệch **không** phải do thiếu sót ngẫu nhiên mà
> là hệ quả trực tiếp của việc `N` là **tham số** thay vì **cổng**:
>
> | Thành phần Charter dự kiến | FF dự kiến | FF thật | Vì sao |
> |---|---:|---:|---|
> | Thanh ghi đỉnh | 8 | **8** | `peak_out[7:0]` ✅ |
> | Bộ đếm suy giảm | 8 | **3** | `count_q` rộng `$clog2(N) = $clog2(8) = 3` bit, không phải 8 — vì `N` biết trước lúc tổng hợp |
> | Thanh ghi **giữ N** | 8 | **0** | ❌ Không tồn tại — `N` là hằng số, không cần nhớ |
> | Cờ | 0–1 | **1** | `valid_out` |
> | **Tổng** | **24–25** | **12** | |
>
> 📌 **Sai số trong file sinh tự động `interface.md` §3.** File đó đếm `sample_in[W-1:0]` và
> `peak_out[W-1:0]` là **0 bit** (không giải được `W`), nên kết luận "tổng 4 bit · còn dư 20
> chân" là **sai**. Con số đúng khi `W = 8` là **18 bit** dữ liệu (9 vào + 9 ra).
>
> ⚠️ **Cảnh báo thứ hai — cấu hình kiểm chứng ≠ cấu hình tổng hợp.**
> Testbench khởi tạo DUT với **`N = 2`** (`g07_tb.sv` dòng 6: `g07_peak_decay #(.W(8),.N(2))`),
> trong khi netlist được tổng hợp với **`N = 8`** (giá trị mặc định). Bằng chứng: netlist có
> `count_q[2:0]` — **3 bit** = `$clog2(8)`; nếu tổng hợp với `N = 2` thì `$clog2(2) = 1` và
> chỉ có **1** bit đếm, tổng 10 FF chứ không phải 12.
> **Hệ quả:** *mô phỏng PASS chứng minh cho `N = 2`; số liệu 83 cell · 12 FF · 754,4736 µm² ·
> 5,02 ns là của `N = 8`.* **Hai con số nói về hai mạch khác nhau.** Xem `corner_cases.md` §5.
>
> **Không tự sửa RTL.** Đặc tả dưới đây mô tả **đúng hành vi RTL đang có**.

---

## 1. Khối này làm gì — phát biểu một câu

G07 giữ **mức đỉnh** của một dòng mẫu 8 bit không dấu, và **tự tụt xuống 1 LSB sau mỗi `N`
mẫu** không có đỉnh mới, có **bão hoà tại 0**. Khi một mẫu **lớn hơn hẳn** đỉnh đang giữ
xuất hiện, đỉnh **nhảy lên ngay lập tức** và bộ đếm suy giảm bị **đặt lại**.

Bối cảnh (Charter mục 1): đồng hồ đo âm thanh (VU meter) — người xem thấy **đỉnh** rồi thấy
nó **tụt dần** về mức hiện tại. Nếu không có suy giảm, đỉnh sẽ đứng mãi và vô dụng; nếu suy
giảm **mỗi chu kỳ**, đỉnh tụt ngay và cũng vô dụng. `N` là núm điều chỉnh giữa hai thái cực.

## 2. Bảng giao diện chuẩn (giải tham số `W = 8`, `N = 8`)

| Tín hiệu | Chiều | Bit | Tính vào ngân sách chân? | Ý nghĩa |
|---|---|---:|:-:|---|
| `clk` | in | 1 | ❌ (hạ tầng TT) | Clock, cạnh lên |
| `rst_n` | in | 1 | ❌ (hạ tầng TT) | Reset **đồng bộ**, tích cực thấp |
| `valid_in` | in | 1 | ✅ | Mẫu hợp lệ tại cạnh lên này |
| `sample_in[7:0]` | in | 8 | ✅ | Mẫu, **không dấu**, 0…255 |
| `peak_out[7:0]` | out | 8 | ✅ | Mức đỉnh hiện tại |
| `valid_out` | out | 1 | ✅ | `valid_in` trễ một nhịp |
| | | **18** | | dư 6 chân — **nhưng thiếu 2 cổng Charter yêu cầu** |
| ~~`N[7:0]`~~ | ~~in~~ | ~~8~~ | ❌ **THIẾU** | Charter mục 4 yêu cầu — RTL dùng tham số |
| ~~`decaying`~~ | ~~out~~ | ~~1~~ | ❌ **THIẾU** | Charter mục 4 yêu cầu |

> Nếu bổ sung đủ hai cổng thiếu: 17 bit vào + 10 bit ra = **27 bit** > 24 chân — lúc đó bài
> toán "nạp hai nhịp" của Charter mục 4 mới thật sự phát sinh. Hiện tại nó bị **né**, không
> phải **giải**.

## 3. Định nghĩa hình thức

Gọi `s[k]` là dãy mẫu **đã lọc theo `valid_in`**. Trạng thái: `peak`, `count ∈ [0, N−1]`.

Tại mỗi mẫu hợp lệ, **theo đúng thứ tự ưu tiên này**:

```
 ① NẾU  s[k] > peak          →  peak ← s[k] ;  count ← 0        ⟵ ƯU TIÊN CAO NHẤT
 ② NGƯỢC LẠI NẾU  N ≤ 1      →  peak ← max(peak−1, 0) ;  count ← 0
 ③ NGƯỢC LẠI NẾU  count = N−1 →  peak ← max(peak−1, 0) ;  count ← 0
 ④ NGƯỢC LẠI                  →  count ← count + 1 ;  peak giữ nguyên
```

Khi `valid_in = 0`: **mọi trạng thái giữ nguyên** (kể cả `count`).

### Bảng hành vi

| `rst_n` | `valid_in` | So sánh | `count_q` | `peak` kế tiếp | `count` kế tiếp | `valid_out` |
|:-:|:-:|---|:-:|---|---|:-:|
| 0 | × | — | — | **0** | **0** | 0 |
| 1 | 0 | — | — | giữ | giữ | **0** |
| 1 | 1 | `s > peak` | bất kỳ | **`s`** | **0** | 1 |
| 1 | 1 | `s ≤ peak` | `< N−1` | giữ | `count+1` | 1 |
| 1 | 1 | `s ≤ peak` | `= N−1` | `max(peak−1, 0)` | **0** | 1 |

## 4. Bốn quyết định thiết kế cần chốt rõ

### 4.1 So sánh **ngặt** `>` — mẫu bằng đỉnh **không** làm mới

RTL dùng `sample_in > peak_q`, không phải `≥`. Hệ quả **quan sát được**: với đầu vào **hằng**
bằng đúng đỉnh, mạch tạo ra một **răng cưa 1 LSB chu kỳ `N+1`**:

```
  N = 8, mọi mẫu = 10, peak khởi đầu = 10:
  mẫu   1  2  3  4  5  6  7  8  9  10 11 …
  count 1  2  3  4  5  6  7  0  0  1  2 …
  peak 10 10 10 10 10 10 10  9 10  10 10 …
                              ▲  ▲
               count=N−1 ⟹ tụt │  └─ 10 > 9 ⟹ nhảy lại lên 10 (ưu tiên ①)
```

Golden model xác nhận nhánh này: `test_equal_peak_is_not_new_peak()` — `peak_decay([10,10])`
cho `[10, 10]` (chưa tới lúc tụt). Nhưng **dao động răng cưa chu kỳ `N+1` thì chưa ca nào
kiểm** — xem `corner_cases.md` §5.

> Với ứng dụng VU meter, răng cưa 1 LSB là **vô hại** (mắt không thấy). Nhưng nếu `peak_out`
> được dùng làm ngưỡng so sánh ở tầng ngoài thì nó sẽ gây **nhấp nháy quyết định**. Đây là
> điều đặc tả phải nói ra.

### 4.2 Bão hoà tại 0 — không cho phép tràn ngược

```systemverilog
peak_d = (peak_q == '0) ? '0 : peak_q - 1'b1;
```

Không có phép này thì `peak = 0` sẽ tụt thành `255` (wrap-around 8 bit không dấu) — lỗi
nghiêm trọng nhất có thể xảy ra ở một VU meter. Golden: `test_zero_saturation()`.

### 4.3 `valid_out` **không** mang thông tin "đang suy giảm"

```systemverilog
valid_out <= valid_in;        // ← vô điều kiện, KHÔNG nằm trong if (valid_in)
```

`valid_out` là bản trễ một nhịp của `valid_in`, không hơn. Nó **không** cho biết đỉnh vừa
được làm mới hay vừa bị tụt. Cổng `uio_out[0] = "đang suy giảm"` mà Charter mục 4 yêu cầu
**không tồn tại**. Muốn có, cần thêm khoảng 1 FF và vài cổng (biểu thức đã có sẵn trong
`always_comb`, chỉ cần đưa ra cổng).

### 4.4 Nhánh `N ≤ 1` là **mã chết** khi `N ≥ 2`

```systemverilog
end else if (N <= 1) begin …
```

`N` là tham số **biên dịch**, nên với `N = 8` điều kiện này là hằng `false` và Yosys **loại
bỏ hoàn toàn** nhánh đó. Nhánh này tồn tại để module đúng cả khi `N = 1` (suy giảm mỗi mẫu).
Nó **không** tốn cell nào trong netlist hiện tại — nhưng nó cũng **chưa bao giờ được mô phỏng**,
vì testbench dùng `N = 2`. Golden model có (`test_decay_N1()`), RTL thì chưa.

## 5. Tính chất bất biến (Invariants)

| ID | Phát biểu | Ghi chú |
|---|---|---|
| **INV-1** | `valid_out[n] = valid_in[n−1]` khi `rst_n = 1` | Vô điều kiện (dòng 46) |
| **INV-2** | `0 ≤ count_q ≤ N−1` **luôn đúng** | Golden `test_counter_state()` kiểm với `N ∈ {2,3,4,8,16}`. Với `N = 8`, miền 3 bit phủ kín ⟹ **không có trạng thái bất hợp lệ**. Với `N = 5` thì **có** — xem `fsm.md` §5 |
| **INV-3** | `peak_out ≥ 0` — **không bao giờ wrap** | Nhờ bão hoà §4.2 |
| **INV-4** | `peak_out` chỉ **tăng** khi có mẫu lớn hơn; chỉ **giảm** đúng 1 LSB mỗi lần | Không có đường nào đổi `peak` quá 1 đơn vị xuống |
| **INV-5** | `s[k] > peak` ⟹ chu kỳ sau `peak_out = s[k]` **và** `count = 0` | Ưu tiên ① tuyệt đối |
| **INV-6** | Khi `valid_in = 0`: `peak_q`, `count_q`, `peak_out` **đều** giữ nguyên | Dòng 47 |
| **INV-7** | Tốc độ tụt tối đa = **1 LSB mỗi `N` mẫu hợp lệ** | Suy từ ③ |
| **INV-8** | Từ đỉnh 255, thời gian về 0 = `255 × N` mẫu hợp lệ | Hệ quả của INV-7. Với `N = 8`: **2040** mẫu |

> `05_VERIFICATION/testbench/properties.sv` hiện có một dạng **yếu** của INV-5:
> `valid_in && sample_in > $past(peak_out) |-> valid_out` — nó chỉ kiểm cờ, **không** kiểm
> giá trị đỉnh. Và khối nằm sau `` `ifdef G07_SVA ``, **chưa được bật**.

## 6. Trạng thái sau reset và độ trễ

| Câu hỏi | Trả lời từ RTL |
|---|---|
| Reset đồng bộ hay bất đồng bộ? | **Đồng bộ** — `always_ff @(posedge clk)` không có `or negedge rst_n`. Netlist dùng `dfxtp_1` (không chân reset) |
| Trạng thái sau reset | `peak_q = 0`, `count_q = 0`, `peak_out = 0`, `valid_out = 0` |
| Độ trễ mẫu → `peak_out` | **1 chu kỳ** — `peak_out` nhận `peak_d` (giá trị tổ hợp của **chính** mẫu này) tại cạnh lên nhận mẫu |
| Thông lượng | 1 mẫu/chu kỳ |
| `peak_out` có giữ giá trị khi `valid_in = 0`? | **Có** — nó là thanh ghi có enable |
| Bao lâu để đỉnh 255 về 0? | `255 × N` mẫu hợp lệ. `N = 8` ⟹ 2040 mẫu; `N = 2` ⟹ 510 mẫu |

## 7. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi RTL | Được bảo đảm? |
|---|---|---|
| `peak = 0`, mẫu = 0, đến lúc tụt | Bão hoà: giữ 0 | ✅ TB dòng 49–50; golden `test_zero_saturation()` |
| Mẫu mới **bằng** đỉnh | **Không** làm mới, count vẫn chạy | ✅ golden `test_equal_peak_is_not_new_peak()`; ⚠️ RTL chưa kiểm ca răng cưa |
| Đỉnh mới **và** đến lúc tụt **trong cùng chu kỳ** | Đỉnh mới **thắng** (ưu tiên ①) | ✅ golden `test_new_peak_priority_on_decay_boundary()`; ✅ TB dòng 41 (`N = 2`, count = 1 = N−1, mẫu 20 > 9) |
| `N = 1` | Tụt **mỗi** mẫu | ⚠️ golden có, **RTL chưa mô phỏng bao giờ** |
| `N = 0` | `CW = 1`; nhánh `N ≤ 1` chạy ⟹ hành vi giống `N = 1` | ⚠️ Không có ca nào. `$clog2(0) = 0` nên `localparam CW` dùng nhánh `(N <= 1) ? 1` để tránh độ rộng 0 |
| `N` **không** là luỹ thừa của 2 (ví dụ 5) | `CW = 3`, miền 0…7 nhưng chỉ dùng 0…4 ⟹ **3 trạng thái bất hợp lệ** | ⚠️ Không có logic phục hồi. Xem `fsm.md` §5 |
| `valid_in = 0` kéo dài | Đỉnh **đóng băng** — không tụt | ✅ TB dòng 53–55. **Lưu ý ngữ nghĩa**: suy giảm tính theo **số mẫu**, không theo **thời gian** |
| `sample_in` chứa `X`/`Z` | `X` lan vào `peak_q` và ở lại tới khi có mẫu lớn hơn hoặc reset | ❌ Nghĩa vụ tầng ngoài |
| Mẫu có dấu? | RTL dùng `logic [W-1:0]` và `>` **không dấu** — đúng cho biên độ VU meter | ✅ nhưng cần tầng ngoài đưa **trị tuyệt đối** vào |

> 🔎 Hàng "suy giảm tính theo **số mẫu**, không theo **thời gian**" là một đặc tính cần nói
> rõ với người dùng: nếu tốc độ mẫu thay đổi, **tốc độ tụt của VU meter thay đổi theo**. Muốn
> tụt theo thời gian thật thì `valid_in` phải đến từ một bộ chia clock cố định, không phải
> từ cờ `data_ready` của ADC.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
