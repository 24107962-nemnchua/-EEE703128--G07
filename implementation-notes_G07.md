# G07 — Bộ phát hiện đỉnh có suy giảm · Ghi chú thực hiện

> ⚠️ Đề này có **khoảng cách RTL ↔ Charter mục 4 lớn nhất** trong nhóm G: cổng `N` và cờ
> "đang suy giảm" mà Charter yêu cầu **không tồn tại** trong RTL. Xem cảnh báo đầu
> `02_SPECIFICATION/functional_spec.md`. Không tự sửa RTL.

## 1. Bài toán này thực chất là gì

Một VU meter bám sát tín hiệu thì vô dụng — mắt người không theo kịp các đỉnh dài vài
mili-giây. Một VU meter chỉ giữ đỉnh cũng vô dụng — sau vài giây nó đứng ở mức cao nhất từng
đo và không bao giờ xuống. G07 là chỗ dung hoà: **giữ đỉnh, rồi cho nó trôi xuống chậm**.

Điều này sinh ra đặc trưng kỹ thuật mà hai đề còn lại của nhóm G không có: **hai hành vi
cạnh tranh cùng muốn ghi vào một thanh ghi trong cùng một chu kỳ**. "Đỉnh mới cao hơn" và
"đã đến lúc tụt" có thể cùng đúng. Charter mục 9 hỏi thẳng về chỗ này, và toàn bộ nội dung
kỹ thuật của đề nằm ở đó.

Đề còn ẩn một câu hỏi thứ hai mà Charter mục 4 đặt ra nhưng RTL **không trả lời**: `N` nên
là hằng số lúc biên dịch hay tham số nạp lúc chạy? Lựa chọn này quyết định số ô nhớ (12 hay
~25), ngân sách chân (18 hay 27 bit), và **cách kiểm chứng**.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

### 2.1 Hai đồng hồ đếm ngược

Cách hiểu sáng nhất: mạch có **hai** đồng hồ chạy song song.

```
  ĐỒNG HỒ 1 — "bao giờ tụt?"   : count_q, 3 bit, chu kỳ N mẫu
  ĐỒNG HỒ 2 — "bao giờ về 0?"  : peak_q,  8 bit, cần 255 lần tụt

  Thời gian đỉnh 255 trôi hết = 255 × N mẫu hợp lệ = 2040 mẫu khi N = 8.
  ĐỈNH MỚI đặt lại đồng hồ 1 về 0 VÀ nạp lại đồng hồ 2 bằng sample_in.
```

Chỉ đồng hồ 1 là FSM (miền nhỏ, điều khiển nhánh). Đồng hồ 2 là **trạng thái dữ liệu** — trừ
một ngoại lệ: giá trị `0` kích hoạt nhánh bão hoà.

### 2.2 Ưu tiên là một **tín hiệu điều khiển sinh muộn, fanout cao**

Đây là cơ chế quan trọng nhất và là nơi mọi chi phí timing tập trung.

Tín hiệu `gt = (sample_in > peak_q)` **chỉ 1 bit**, nhưng:
- nó **sinh ra muộn** — phải chờ **toàn bộ** chuỗi borrow 8 tầng của bộ so sánh;
- rồi nó phải **lan ngang** ra chân chọn của **tám** mux (một cho mỗi bit `peak`) cộng logic
  đặt lại bộ đếm ⟹ **fanout 9**.

Hai đặc tính đó cộng lại tạo ra cell đắt nhất trong cả ba đề nhóm G:

```
  _089_ (a21boi_0) :  delay 1,03 ns · fanout 9 · slew đầu ra 1,26 ns
                      = 25,6 % toàn bộ 4,02 ns độ trễ cell của đường tới hạn
                      nhưng chỉ 7,5072 µm² = 1,0 % diện tích thiết kế
```

**Vì sao đắt:** `a21boi_0` có hậu tố `_0` — sức lái **thấp nhất** trong họ. Nó nạp điện cho
9 chân đầu vào, sườn tín hiệu thoải ra (slew 1,26 ns), và cell nhận sau đó chậm theo. Đây là
bài toán **lái tải**, không phải bài toán độ sâu logic — điểm này rất hay bị nhầm.

### 2.3 Chữ ký cấu trúc đọc được từ phân bố slack

Tám endpoint `peak_out[0..7]` có slack **bằng nhau: 4,87 ns**. Không phải trùng hợp — nó nói
rằng mọi bit cùng chờ **một** tín hiệu chung. So sánh:

| Đề | Slack theo bit đầu ra | Cấu trúc suy ra |
|---|---|---|
| G06 | 8,51 → 6,18 ns, **giảm đơn điệu** | dữ liệu chảy **dọc** chuỗi carry |
| **G07** | **4,87 ns, bằng nhau cả 8** | một **quyết định chung** lan **ngang** |
| G05 | 6,22…6,32 ns, gần bằng | quyết định chung, lệch nhẹ do mux khác nhau |

Đây là kỹ thuật đọc STA đáng dạy: **hình dạng phân bố slack cho biết kiến trúc**, không cần
mở netlist.

### 2.4 Bão hoà tại 0 — chi tiết nhỏ chặn lỗi lớn nhất

`peak_q − 1` khi `peak_q = 0` sẽ wrap thành **255** ở số học 8 bit không dấu. Với VU meter,
đó là "im lặng ⟹ nhảy lên hết thang" — lỗi tệ nhất có thể có. RTL chặn bằng một cây NOR 8
đầu vào và một mux.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

Toàn bộ thiết kế là 55 dòng. Ba đoạn quyết định tất cả.

**Đoạn 1 — thứ tự ưu tiên (dòng 22–36), đây LÀ đặc tả:**

```systemverilog
if (valid_in) begin
    // New higher peak has priority over decay.
    if (sample_in > peak_q) begin          // ② ƯU TIÊN CAO NHẤT
        peak_d  = sample_in;
        count_d = '0;                      // ← đặt lại cả đồng hồ suy giảm
    end else if (N <= 1) begin …           // ③ hằng số, bị loại bỏ khi N ≥ 2
    end else if (count_q == N-1) begin     // ④ suy giảm theo lịch
        peak_d  = (peak_q == '0) ? '0 : peak_q - 1'b1;
        count_d = '0;
    end else begin
        count_d = count_q + 1'b1;          // ⑤ chỉ đếm tiếp
    end
end
```

Chú thích tiếng Anh ngay trên nhánh ② cho thấy tác giả RTL **ý thức rõ** đây là quyết định
kiến trúc, không phải thứ tự tình cờ. Nếu đảo ② và ④, khi đỉnh mới rơi đúng lúc `count = N−1`
thì `peak` sẽ **tụt** thay vì **nhảy lên** — tức VU meter **bỏ sót đỉnh**, đúng thứ nó sinh
ra để bắt.

**Đoạn 2 — hai dòng gán mặc định (dòng 19–20), chống suy ra latch:**

```systemverilog
peak_d  = peak_q;
count_d = count_q;
```

Nhờ chúng, `always_comb` luôn gán đủ mọi biến trên mọi đường, nên không sinh latch. Đồng thời
chúng **chính là** nhánh "giữ nguyên" của mux — hiện thực thành `mux2_1 × 7` trong netlist.

**Đoạn 3 — `valid_out` nằm NGOÀI enable (dòng 46):**

```systemverilog
end else begin
    valid_out <= valid_in;       // ← KHÔNG nằm trong if (valid_in)
    if (valid_in) begin
        peak_q   <= peak_d;
        count_q  <= count_d;
        peak_out <= peak_d;
    end
end
```

Vì vậy `valid_out` là thanh ghi **không có enable**, trong khi 11 FF còn lại **có**. Bằng
chứng ở báo cáo hold: `timing_report_min.txt` liệt kê 5 vòng giữ `_1xx_ → _1xx_`, và
`_142_` (= `valid_out`) **không** có trong đó — đúng như dự đoán.

Một chi tiết nữa: `localparam CW = (N <= 1) ? 1 : $clog2(N);` quyết định **độ rộng bộ đếm lúc
biên dịch**. Với `N = 8` thì `CW = 3`. Đây là dòng khiến netlist có `count_q[2:0]` — và là
bằng chứng netlist được tổng hợp với `N = 8`, **không** phải `N = 2` như testbench.

## 4. Vì sao chọn kiến trúc này

| Quyết định | Lý do | Cái giá |
|---|---|---|
| Suy giảm **tuyến tính** 1 LSB / `N` mẫu | Đúng chuẩn peak-hold cho thang tuyến tính; logic rẻ nhất (bộ trừ 1) | Không giống bộ nhớ tương tự (tụ xả) — nhưng "hàm mũ" **ngoài phạm vi** |
| **Đỉnh mới ưu tiên tuyệt đối** | Chức năng cốt lõi: không được bỏ sót đỉnh ngắn | 1,03 ns (25,6 % đường tới hạn) cho tín hiệu `gt` fanout 9 |
| So sánh **ngặt** `>` | Đơn giản hơn `≥` một chút | Đầu vào hằng tạo **răng cưa 1 LSB chu kỳ `N+1`** — xem §9 |
| **Bão hoà tại 0** | Chặn wrap 0 → 255 | Một cây NOR 8 đầu vào |
| `N` là **tham số biên dịch** | Tiết kiệm ~8 FF giữ `N` + bộ so sánh 8 bit; giữ ngân sách chân ở 18/24 | ❌ **Lệch Charter mục 4**; không đổi `N` sau chế tạo; **nhân đôi công sức kiểm chứng** |

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| # | Bước | Trạng thái | Bằng chứng |
|---|---|:-:|---|
| 1 | Suy bảng hành vi và **bảng ưu tiên** từ Charter mục 1, 8, 9 | ✅ | `functional_spec.md` §3 |
| 2 | Viết mô hình chuẩn Python độc lập | ✅ **PASS** (10 test, `N` từ 1 tới 16) | `python_reference_run.log` |
| 3 | Viết RTL, chốt thứ tự ưu tiên bằng `if`/`else if` | ✅ | `g07_peak_decay.sv`, 55 dòng |
| 4 | Viết testbench tự kiểm | ⚠️ **PASS nhưng với `N = 2`** ≠ cấu hình tổng hợp | `simulation.log`, `$finish @ 136` |
| 5 | Tổng hợp ra standard cell sky130 (**`N = 8`**) | ✅ | 83 cell · 12 FF · 754,4736 µm² |
| 6 | STA với SDC (10 ns, IO delay 1 ns) | ✅ | 5,02 ns · slack 4,87 ns · WNS/TNS 0,00 |
| 7 | Ước lượng công suất | ✅ | 7,43e-05 W (tuần tự 73,2 %) |
| 8 | Place & route → DRC/LVS → GDSII | ⬜ **chưa chạy** | cần LibreLane + PDK sky130A |

**Hai việc còn thiếu nằm giữa 4 và 5**, và chúng là điểm yếu lớn nhất của hồ sơ: (a) đồng bộ
cấu hình `N` giữa mô phỏng và tổng hợp; (b) bổ sung ca **cạnh tranh thật** (đỉnh mới đúng lúc
`count = N−1`) — ca này chỉ có ở golden model.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Số | Giá trị | **Chứng minh** điều gì | **KHÔNG** chứng minh điều gì |
|---|---:|---|---|
| Số cell | 83 | Tổng hợp được; **dưới** ước lượng Charter (200–290) vì không có thanh ghi giữ `N` | Không nói gì về chức năng |
| Flip-flop | **12** | 8 (`peak_out`, đã hợp nhất `peak_q`) + 3 (`count_q`) + 1 (`valid_out`) ⟹ **có bộ đếm**, không phạm rủi ro Charter mục 10 | **Không** khớp dự kiến Charter 24–25 — vì `N` là tham số, không phải cổng. Và con số này **chỉ đúng cho `N = 8`** (với `N = 2` sẽ là 10) |
| Diện tích | 754,4736 µm² | Vừa ô 1×1 | Chưa gồm dây, chưa gồm lớp vỏ `tt_um_*` |
| Thanh ghi / tổ hợp | 240,23 µm² (31,8 %) / 514,24 µm² (68,2 %) | Tỷ lệ tổ hợp **cao nhất** trong ba đề — vì có **hai** khối tính (so sánh + trừ) chứ không phải một | Tính từ `dfxtp_1 = 20,0192 µm²` trong Liberty |
| Đường tới hạn | `sample_in[0] → peak_out[0]`, 5,02 ns | Nút thắt gồm **hai** phần: chuỗi so sánh **2,62 ns (65,2 %)** và tầng lan quyết định **1,30 ns (32,3 %)** | **Không** nghĩa là "chạy được ở 199 MHz". Gồm 1,00 ns IO delay **giả định**, chưa có dây, 1 góc PVT, và là của `N = 8` |
| Slack setup | **4,87 ns** — chặt nhất trong ba đề | Vẫn còn biên rộng với chu kỳ giả định 10 ns | Sẽ co lại sau P&R và ở góc `ss` |
| Slack 8 bit `peak_out` | **bằng nhau** | Chữ ký của "một quyết định chung lan ngang" | — |
| Slack hold | 0,50 ns (`count_q[1]`) | Không vi phạm hold sau tổng hợp | **Clock lý tưởng, skew = 0** |
| Công suất | 7,43e-05 W (tuần tự 73,2 %) | FF vẫn là nhóm tốn nhất | **Ước lượng** với hoạt động mặc định. VU meter thật phần lớn thời gian "im lặng" ⟹ có thể thấp hơn nhiều |
| Mô phỏng RTL | PASS, `$finish @ 136` | Chạy hết testbench, không assertion nào vi phạm; phủ 5 nhánh hành vi | **Chỉ đúng cho `N = 2`**, mạch **chưa bao giờ được tổng hợp**. Thiếu ca cạnh tranh, ca `N` lớn, ca `N = 1` |

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**(1) Bộ đếm suy giảm `N` chu kỳ chiếm bao nhiêu ô nhớ so với thanh ghi giữ đỉnh?**

Đo được (`N = 8`): bộ đếm **3 FF** = 60,06 µm²; thanh ghi đỉnh **8 FF** = 160,15 µm². Tỷ lệ
**3 : 8**, tức bộ đếm chiếm **27 %** số ô nhớ dùng cho hai khối này, hay **25 %** tổng 12 FF.

Điểm quan trọng: con số 3 có được vì `CW = $clog2(N)` **biết `N` lúc biên dịch**. Nếu `N` là
cổng vào như Charter mục 4 yêu cầu, bộ đếm phải rộng **8 bit** và còn cần **8 FF** nữa để giữ
`N` ⟹ tỷ lệ thành **16 : 8**, tức bộ đếm **gấp đôi** thanh ghi đỉnh. Đây chính là cách
Charter mục 10 ước lượng ra "24–25 ô nhớ".

**(2) Đỉnh mới thấp hơn đỉnh đang giữ — mạch phản ứng thế nào, và vì sao không cập nhật ngay?**

Mạch **không làm gì với `peak`** — nó chỉ tăng `count_q`. Bằng chứng waveform: cạnh lên 4
(`t = 35 ns`), `sample_in = 1` nhưng `peak_out` **giữ 10**; chỉ `count_q` đi 0 → 1
(`timing_diagram.md` §3).

Vì sao không cập nhật ngay: nếu `peak` bám mẫu thấp, nó không còn là "peak hold" mà thành
"bám tức thời" — và các đỉnh ngắn sẽ biến mất trước khi mắt kịp thấy. Đỉnh **chỉ được** giảm
theo lịch trình `N`, mỗi lần đúng **1 LSB** — đó là thứ làm chuyển động của VU meter mượt và
đọc được.

**(3) `N` nhỏ và `N` lớn cho hành vi khác nhau ra sao trên waveform?**

| | `N` nhỏ (= 2, cấu hình testbench) | `N` lớn (= 8, cấu hình tổng hợp) |
|---|---|---|
| Nhịp tụt | 1 LSB mỗi **2** mẫu | 1 LSB mỗi **8** mẫu |
| Từ 255 về 0 | 510 mẫu | **2040** mẫu |
| Bộ đếm | `CW = 1` ⟹ 1 FF | `CW = 3` ⟹ 3 FF |
| Tổng FF | **10** | **12** |
| Cảm nhận | đỉnh trôi nhanh, meter "nhạy" | đỉnh treo lâu, dễ đọc |

Trên waveform (`timing_diagram.md` §3, `N = 2`): đỉnh 10 đặt ở cạnh 3, tụt còn 9 ở **cạnh 5**
— chỉ sau **2** mẫu. Với `N = 8`, cùng chuỗi đó sẽ phải chờ tới **cạnh 11**.

> ⚠️ **Nhưng đây là câu trả lời chưa khép kín:** RTL **chỉ được mô phỏng với `N = 2`**. Hành
> vi `N = 8` suy ra từ mã và từ golden model, **không** từ mô phỏng RTL. Charter mục 8 bắt
> buộc cả "N nhỏ **và** N lớn" — yêu cầu này **CHƯA THOẢ** ở mức RTL. Xem `corner_cases.md` §5.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"Thiết kế có hai hành vi cạnh tranh: cập nhật đỉnh và suy giảm. Nêu rõ cách mình xử lý khi
> cả hai xảy ra cùng chu kỳ, và chỉ ra phần logic quyết định thứ tự ưu tiên."*

**(a) Xử lý khi cả hai xảy ra cùng chu kỳ:** **cập nhật đỉnh thắng tuyệt đối.** Cơ chế là thứ
tự `if` / `else if` (RTL dòng 24 nằm **trước** dòng 30), mà trình tổng hợp dựng thành nhánh
ưu tiên cao hơn của cây mux. Khi `gt = 1`, nhánh suy giảm **không bao giờ** được chọn, bất kể
`count_q` bằng bao nhiêu. Bộ đếm cũng bị ép về 0 trong cùng nhịp, nên đồng hồ suy giảm khởi
động lại từ đầu — đúng ngữ nghĩa "đỉnh mới thì tính lại thời gian giữ".

**(b) Phần logic quyết định ưu tiên — chỉ đích danh bằng số:**

| Hạng mục | Giá trị | Nguồn |
|---|---|---|
| Instance | **`_089_`** | `timing_report_max.txt` |
| Cell | `sky130_fd_sc_hd__a21boi_0` | như trên |
| Đi tới | chân **`S`** (select) của `_097_ (mux2i_1)` + 8 tải khác | như trên |
| Fanout | **9** | như trên |
| Slew đầu ra | **1,26 ns** | như trên |
| Delay | **1,03 ns** | như trên |
| % đường tới hạn | **25,6 %** của 4,02 ns độ trễ cell | tính |
| Diện tích cell | **7,5072 µm²** | Liberty |
| % diện tích thiết kế | **1,0 %** | tính |

**Câu kết bằng số:** *logic quyết định ưu tiên chiếm **1,0 % diện tích** nhưng **25,6 % đường
tới hạn**.* Nguyên nhân là **lái tải**: một cell sức lái thấp nhất (`_0`) phải lái 9 chân.
Cộng thêm mux nó điều khiển, tầng "lan quyết định" tốn **1,30 ns = 32,3 %** toàn đường — đó
chính là cái giá của việc có hai hành vi cạnh tranh, đo được bằng ns.

**(c) Khoảng trống cần nói thẳng:** ca **cạnh tranh thật** (đỉnh mới **đúng lúc**
`count = N−1`) **chưa được mô phỏng trên RTL**. Ca ở testbench dòng 41 rơi vào `count_q = 0`.
Golden model có (`test_new_peak_priority_on_decay_boundary()`). Xem `corner_cases.md` CC-13.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | **Phát hiện bằng bằng chứng nào** |
|---|---|---|---|
| 1 | **Quên bộ đếm** — tụt mỗi chu kỳ | Đỉnh tụt ngay, VU meter vô dụng. Đây là rủi ro Charter mục 10 nêu tên | Waveform: với `N = 2`, `peak` phải giữ 10 ở cạnh 4 rồi mới còn 9 ở cạnh 5. Nếu tụt ngay cạnh 4 ⟹ dính lỗi. Và netlist phải có `count_q` (3 FF) |
| 2 | **Đảo thứ tự ưu tiên** (suy giảm trước đỉnh mới) | Đỉnh mới bị nuốt khi rơi đúng lúc tụt ⟹ **bỏ sót đỉnh** | Ca cạnh tranh: `N = 2`, chuỗi `[10, 1, 20]`. Golden `test_new_peak_priority_on_decay_boundary()` bắt được. **Testbench RTL thì không** |
| 3 | **Quên bão hoà tại 0** | `peak = 0` wrap thành 255 ⟹ meter nhảy hết thang khi im lặng | Ca `send(0,0)` hai lần liên tiếp sau khi `peak` về 0. TB dòng 49–50 có, nhưng chưa chạy tới lần tụt **thứ hai** ở mức 0 |
| 4 | Dùng `≥` thay `>` khi so sánh | Mẫu bằng đỉnh sẽ đặt lại bộ đếm ⟹ đầu vào hằng **không bao giờ tụt** ⟹ thành peak-hold vĩnh viễn | Ca đầu vào hằng dài (`N + 5` mẫu bằng nhau). Với `>` sẽ thấy răng cưa chu kỳ `N+1`; với `≥` sẽ thấy đường phẳng. **Ca này chưa có ở đâu** |
| 5 | Tưởng suy giảm theo **thời gian** | Khi nguồn mẫu dừng, đỉnh **treo** thay vì trôi | Ca khe `valid_in` (TB dòng 53–55): `count_q` **đóng băng** ở 1, không nhích. Đây là bằng chứng "đếm theo mẫu" |
| 6 | Mô phỏng với `N` này, tổng hợp với `N` khác | Hai kết luận nói về hai mạch khác nhau | **Đã xảy ra thật**: TB dùng `N = 2`, netlist có `count_q[2:0]` = 3 bit = `$clog2(8)`. Đếm số FF trong netlist là cách phát hiện |
| 7 | Tưởng đếm được 20 FF từ RTL | Nhầm khi đối chiếu Charter mục 10 | `synth_stat.txt` cho **12**. Yosys hợp nhất `peak_q` vào `peak_out` (cùng `D`, enable, reset) — giống `y_q`/`y` ở G06, **khác** `min_q`/`min_out` ở G05 (enable khác nhau) |
| 8 | Tưởng bộ đếm nằm trên đường tới hạn | Tối ưu nhầm chỗ | STA: `count_q[0]` có slack **6,01 ns**, `peak_out[*]` chỉ **4,87 ns**. Bộ đếm **rộng rãi** về timing |
| 9 | Tưởng `lpflow_isobufsrc_1` nghĩa là thiết kế có power gating | Hiểu sai netlist | Cell cách ly nguồn bị `abc` dùng làm **cổng logic thường** (chân `SLEEP` như enable) vì rẻ. Xuất hiện 8 lần trong netlist, 1 lần trên đường tới hạn |
| 10 | Kết luận "`N` không là luỹ thừa của 2 vẫn an toàn" | Bỏ sót trạng thái bất hợp lệ | Với `N = 5`: `CW = 3` nhưng chỉ dùng 0…4 ⟹ **3 trạng thái bất hợp lệ**. Máy tự phục hồi sau ≤ 3 mẫu nhờ tràn, nhưng nhịp suy giảm bị lệch. Xem `fsm.md` §5 |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Đỉnh mới và lúc tụt trùng nhau — ai thắng, và phần cứng nào quyết định? | Đỉnh mới thắng. Cơ chế là thứ tự `if`/`else if`; phần cứng là cell **`_089_` (`a21boi_0`)** lái chân **`S`** của 8 mux |
| 2 | Logic ưu tiên đó tốn bao nhiêu? | **1,0 % diện tích** (7,5072 µm²) nhưng **25,6 % đường tới hạn** (1,03 ns / 4,02 ns). Vì fanout 9 và sức lái thấp ⟹ slew 1,26 ns |
| 3 | Netlist có 12 FF nhưng Charter nói 24–25. Vi phạm đề chứ? | Không vi phạm chức năng, nhưng **lệch Charter mục 4**: `N` là tham số biên dịch nên không cần 8 FF giữ `N`, và bộ đếm chỉ `$clog2(8) = 3` bit thay vì 8 |
| 4 | Testbench dùng `N` bằng mấy? Netlist dùng `N` bằng mấy? | **2** và **8**. Bằng chứng: netlist có `count_q[2:0]` = 3 bit = `$clog2(8)`. Đây là khoảng trống kiểm chứng phải nói rõ |
| 5 | Tám bit `peak_out` có slack bằng nhau (4,87 ns). Điều đó nói lên cấu trúc gì? | Mọi bit chờ **cùng một** tín hiệu quyết định lan **ngang**. Tương phản với G06, nơi slack giảm đơn điệu vì dữ liệu chảy **dọc** chuỗi carry |
| 6 | Nếu bỏ biểu thức `(peak_q == '0) ? '0 : …` thì sao? | `peak = 0` sẽ wrap thành **255** ⟹ VU meter nhảy hết thang khi im lặng. Lỗi tệ nhất có thể của loại mạch này |
| 7 | Nguồn mẫu dừng 10 giây — đỉnh có trôi về 0 không? | **Không.** Bộ đếm chỉ nhích khi `valid_in = 1` ⟹ suy giảm tính theo **số mẫu**, không theo **thời gian**. Bằng chứng: TB dòng 53–55, `count_q` đóng băng ở 1 |
| 8 | Đầu vào là hằng số bằng đúng đỉnh — waveform ra sao? | **Răng cưa 1 LSB chu kỳ `N+1`**: giữ `N−1` mẫu, tụt 1, rồi mẫu kế lớn hơn ⟹ nhảy lại lên. Vì so sánh là `>` ngặt. **Chưa ca nào kiểm điều này** |
| 9 | Vì sao bộ đếm **không** nằm trên đường tới hạn dù nó cũng nhận `gt`? | Đường tới `peak_out` còn qua mux 8 bit + buffer (0,33 ns); đường tới `count_q` chỉ cần ép về 0. Slack: 4,87 so với 5,03 và 6,01 ns |
| 10 | Đỉnh 255 mất bao lâu để về 0? | `255 × N` mẫu hợp lệ = **2040** mẫu với `N = 8`, 510 mẫu với `N = 2` |
| 11 | Hồ sơ đã thoả Charter mục 4 chưa? | **Chưa** — thiếu **hai cổng**: `uio_in[7:0] = N` và `uio_out[0] = "đang suy giảm"`. Vì thiếu chúng mà ngân sách chân mới "đủ" (18/24); nếu bổ sung sẽ là 27 bit, **vượt 3 chân** |
| 12 | Nếu `N = 5` thì bộ đếm có trạng thái bất hợp lệ không? | **Có** — `CW = 3` biểu diễn 0…7 nhưng chỉ dùng 0…4. Máy **tự phục hồi** sau ≤ 3 mẫu nhờ bộ đếm tràn về 0, nhưng nhịp suy giảm bị lệch. Với `N = 8` thì phủ kín, an toàn tuyệt đối |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh:**
- Thiết kế **có bộ đếm suy giảm** thật (3 FF `count_q`), **không** phạm rủi ro Charter mục 10.
- **Ưu tiên đỉnh mới** được hiện thực đúng, và đã chỉ đích danh phần cứng (`_089_`) kèm số
  liệu timing và diện tích — trả lời Charter mục 9 bằng số.
- **Bão hoà tại 0** hoạt động — mô phỏng xác nhận `peak` xuống 0 rồi giữ 0.
- Mô phỏng RTL chạy hết testbench (cấu hình `N = 2`), phủ 5 nhánh hành vi và một lần reset
  giữa dòng.
- Số liệu cấu trúc và thời gian thật ở mức **sau tổng hợp** cho cấu hình `N = 8`: 83 cell ·
  12 FF · 754,4736 µm² · 5,02 ns · slack 4,87 ns · 7,43e-05 W.
- Chữ ký cấu trúc "slack bằng nhau trên 8 bit" xác nhận kiến trúc "một quyết định chung lan
  ngang".

**Chưa chứng minh:**
- **Mạch đã tổng hợp (`N = 8`) chưa bao giờ được mô phỏng**; mạch đã mô phỏng (`N = 2`) chưa
  bao giờ được tổng hợp. Đây là khoảng trống nghiêm trọng nhất.
- Ca **cạnh tranh thật** (đỉnh mới đúng lúc `count = N−1`) — chỉ có ở golden model.
- Charter mục 8 yêu cầu cả "`N` nhỏ **và** `N` lớn" — mới phủ được `N = 2` ở mức RTL.
- Nhánh `N ≤ 1` trong RTL **chưa bao giờ được mô phỏng**.
- Hành vi răng cưa với đầu vào hằng — suy ra từ mã, chưa ca nào kiểm.
- Netlist tương đương chức năng với RTL — chưa mô phỏng gate-level.
- Độ trễ thật sau routing; biên an toàn qua các góc PVT; công suất từ VCD thật.
- **Tuân thủ Charter mục 4** — thiếu cổng `N`, thiếu cờ "đang suy giảm", chưa có lớp vỏ
  `tt_um_*`, và bài toán "vượt ngân sách chân" bị **né** chứ không **giải**.

**Không được khẳng định** (Charter mục 3): sign-off, tape-out, chế tạo, kiểm tra sau chế tạo,
"chạy được ở XXX MHz", "đã tối ưu netlist", "đã kiểm chứng đầy đủ mọi giá trị `N`".

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
