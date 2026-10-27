# G07 · Phân tích đánh đổi (Trade-off)

---

## 1. Số liệu nền — mọi so sánh dưới đây quy chiếu về đây

| Chỉ số | Giá trị thật | Nguồn |
|---|---:|---|
| Cấu hình đã tổng hợp | **`W = 8`, `N = 8`** (`CW = 3`) | Netlist có `\count_q[0..2]` |
| Số cell | **83** | `synth_stat.txt` |
| Flip-flop | **12** | như trên |
| Diện tích | **754,4736 µm²** | như trên |
| Diện tích 1 `dfxtp_1` | **20,0192 µm²** | `sky130_fd_sc_hd__tt_025C_1v80.lib` (chính file Liberty dùng trong flow) |
| ⟹ Diện tích thanh ghi | 12 × 20,0192 = **240,2304 µm²** = **31,8 %** | tính từ hai dòng trên |
| ⟹ Diện tích tổ hợp | 754,4736 − 240,2304 = **514,2432 µm²** = **68,2 %** (71 cell) | như trên |
| Đường tới hạn | `sample_in[0] → peak_out[0]`, **5,02 ns** (gồm 1,00 ns IO delay giả định) | `timing_report_max.txt` |
| Slack setup / hold | **4,87 ns** / 0,50 ns | `timing_report_max/min.txt` |
| Công suất ước lượng | 7,43e-05 W — tuần tự **73,2 %**, tổ hợp 26,8 % | `power_report.txt` |
| Charter ước lượng quy mô | ~200–290 cell | Charter metadata |

> Thiết kế thật **83 cell**, tức **dưới** khoảng Charter ước lượng (200–290). Lý do chính:
> không có thanh ghi giữ `N` và không có cổng `N` — xem §4.

## 2. So sánh với hai kiến trúc thay thế

| Tiêu chí | **① Bộ đếm + tụt tuyến tính** (đã chọn) | ② Bộ đếm "thời gian giữ" rồi thả tự do | ③ Suy giảm theo hàm mũ (`peak − peak/2^k`) |
|---|---|---|---|
| Ô nhớ | **12 FF** (đo) | ~12 FF | ~12 FF |
| Logic suy giảm | Bộ trừ 1 + bão hoà | Nạp lại từ mẫu hiện tại | **Bộ dịch + bộ trừ** (rộng hơn) |
| Hình dạng trôi | **Tuyến tính** — 1 LSB / `N` mẫu | Giữ rồi **rơi thẳng** | Mũ — nhanh lúc đầu, chậm về sau |
| Thời gian từ 255 về 0 | `255 × N` mẫu (2040 với `N = 8`) | `N` mẫu rồi rơi ngay | ~`k × log₂(255)` mẫu |
| Giống VU meter thật? | ✅ Chuẩn công nghiệp cho **peak hold** | ⚠️ Giật, khó nhìn | ✅ Giống bộ nhớ tương tự (tụ xả), nhưng **Charter mục 3: ngoài phạm vi** |
| Số cell | **83** (đo) | ít hơn ~10 cell | nhiều hơn ~20–30 cell (ước lượng) |
| Tính có thể điều chỉnh | Qua `N` | Qua `N` | Qua `k` |
| Khi nào nên dùng | Đồng hồ đo có thang tuyến tính — **đúng bối cảnh G07** | Khi chỉ cần "đỉnh trong cửa sổ" | Khi thang đo là dB (logarit) |

> ⚠️ **Ràng buộc phạm vi:** Charter mục 3 liệt **"suy giảm theo hàm mũ"** vào **ngoài phạm
> vi**. Cột ③ chỉ được so sánh **trên giấy**, **không** được thay vào RTL. Tương tự với
> "nhiều kênh" và "giữ đỉnh vô hạn".

## 3. Đánh đổi quan trọng nhất: `N` là **tham số biên dịch** thay vì **cổng vào**

Đây là quyết định kiến trúc có hệ quả lan rộng nhất của cả đề — và nó **lệch Charter mục 4**
(xem cảnh báo đầu `02_SPECIFICATION/functional_spec.md`).

| Hạng mục | **A. `N` là tham số** (RTL hiện tại) | **B. `N` là cổng vào** (Charter mục 4 yêu cầu) |
|---|---|---|
| Thanh ghi giữ `N` | **0 FF** | **8 FF = 160,15 µm²** |
| Độ rộng bộ đếm | `$clog2(N)` = **3 bit** = 60,06 µm² | phải đủ cho `N` bất kỳ ⟹ **8 bit** = 160,15 µm² |
| Bộ so sánh `count == N−1` | Giải mã hằng số: 1 cổng `AND3` ≈ 5 µm² | **Bộ so sánh 8 bit đầy đủ** ≈ 8 × `maj3_1` = 80,08 µm² |
| **Tổng FF** | **12** (đo) | ~**25** (khớp Charter mục 10: "24–25 ô nhớ") |
| **Tổng diện tích** | **754,4736 µm²** (đo) | ước lượng **754 + 160 + 100 + 75 ≈ 1090 µm²** (+45 %) |
| Ngân sách chân | 18 bit ✅ | **27 bit** ❌ vượt 3 chân ⟹ phải nạp hai nhịp (+ FSM 2–3 trạng thái) |
| Đổi `N` sau chế tạo | ❌ **không thể** | ✅ được |
| Kiểm chứng | ⚠️ **mỗi `N` là một mạch riêng** — phải tổng hợp và mô phỏng lại | ✅ một lần chạy phủ được nhiều `N` |

> 🔎 **Đây là lý do con số 12 FF lệch dự kiến 24–25 của Charter mục 10.** Chênh lệch **không**
> phải sơ suất mà là hệ quả trực tiếp của phương án A. Hồ sơ phải nói rõ điều này, nếu không
> người chấm sẽ nghĩ thiết kế "quên bộ đếm" — đúng cái rủi ro Charter mục 10 nêu tên.

**Và cái giá thật sự của phương án A là ở kiểm chứng, không ở phần cứng:**

```
  Testbench chạy với  N = 2   →  10 FF, chưa bao giờ được tổng hợp
  Netlist/STA/công suất với N = 8  →  12 FF, chưa bao giờ được mô phỏng
  ⟹ "Mô phỏng PASS" và "83 cell · 5,02 ns" nói về HAI MẠCH KHÁC NHAU.
```

Xem `corner_cases.md` §5.1 để biết hai cách khép kín. Nếu `N` là cổng như Charter yêu cầu,
khoảng trống này **không tồn tại**.

## 4. Đánh đổi thứ hai: **ưu tiên rẻ về diện tích, đắt về thời gian**

Charter mục 9 hỏi về hai hành vi cạnh tranh. Số liệu trả lời:

| Thành phần | Diện tích | % diện tích | Đóng góp timing | % đường tới hạn |
|---|---:|---:|---:|---:|
| Chuỗi so sánh (7 × `maj3_1`) | 7 × 10,0096 = **70,07 µm²** | 9,3 % | **2,62 ns** | **65,2 %** |
| **Cell quyết định ưu tiên `_089_`** (`a21boi_0`) | **7,5072 µm²** | **1,0 %** | **1,03 ns** | **25,6 %** |
| Mux ưu tiên (8 × `mux2i_1`) | 8 × 10,0096 = 80,08 µm² | 10,6 % | 0,27 ns | 6,7 % |
| Bộ đếm (3 FF + logic) | ~75 µm² | ~10 % | **0 ns** (không trên đường) | 0 % |
| Thanh ghi `peak` (8 FF) | 160,15 µm² | 21,2 % | — (là đích) | — |

> **Câu một dòng cho Charter mục 9:** *logic quyết định ưu tiên chiếm **1,0 %** diện tích
> nhưng **25,6 %** đường tới hạn* — vì nó là một tín hiệu **1 bit fanout 9** với sức lái yếu
> (`a21boi_0`, hậu tố `_0` = drive strength thấp nhất), slew đầu ra **1,26 ns**.

| Phương án cải thiện (chưa chạy) | Hiệu quả ước lượng | Chi phí ước lượng |
|---|---|---|
| Dùng biến thể sức lái mạnh (`a21boi_1`…) | Giảm slew ⟹ giảm cả 1,03 lẫn 0,27 ns | +vài µm² |
| Chèn buffer chia tải 2 nhóm | Fanout 9 → ~5 mỗi nhánh | +1–2 cell |
| Nhân bản cell `_089_` | Mỗi bản lái ít tải hơn | +7,5 µm²/bản |
| Thay chuỗi borrow bằng bộ so sánh nhanh | Giảm 2,62 ns; **không** giảm 1,30 ns tầng lan | +diện tích tổ hợp |

⚠️ Cả bốn là **ước lượng định tính**. Với slack **4,87 ns / 10 ns**, tối ưu này **không cần
thiết**. Và Charter mục 3 liệt "tự tối ưu netlist bằng tay" vào **ngoài phạm vi**.

## 5. So sánh ba đề cùng nhóm G — cùng thư viện, cùng tổ hợp công cụ

| Chỉ số | G05 (min/max 8 mẫu) | G06 (IIR 1/2) | **G07 (peak decay)** |
|---|---:|---:|---:|
| Số cell | 202 | 54 | **83** |
| Flip-flop | 36 | 9 | **12** |
| Diện tích | 1681,6128 µm² | 482,9632 µm² | **754,4736 µm²** |
| Thanh ghi / tổ hợp | 42,9 % / 57,1 % | 37,3 % / 62,7 % | **31,8 % / 68,2 %** |
| Độ trễ đường tới hạn | 3,66 ns | 3,75 ns | **5,02 ns** ← lớn nhất |
| Slack setup | 6,22 ns | 6,18 ns | **4,87 ns** ← chặt nhất |
| Cell đắt nhất trên đường | 0,37 ns | 0,40 ns | **1,03 ns** |
| Slack theo bit đầu ra | 6,22…6,32 ns (gần bằng) | **8,51 → 6,18 ns** (giảm đơn điệu) | **4,87 ns (bằng nhau cả 8)** |
| Công suất | 1,90e-04 W | 6,04e-05 W | **7,43e-05 W** |
| Công suất tuần tự | 82,1 % | 71,2 % | 73,2 % |

**Ba chữ ký cấu trúc khác nhau, đọc được từ cột "slack theo bit":**

| Hình dạng slack | Cấu trúc suy ra | Đề |
|---|---|---|
| Giảm **đơn điệu** theo bit | Dữ liệu chảy **dọc** chuỗi carry, mỗi bit phụ thuộc số tầng khác nhau | **G06** |
| **Bằng nhau** cả 8 bit | Một **quyết định chung** lan **ngang** ra toàn bộ bề rộng | **G07** |
| Gần bằng nhau, lệch nhẹ (0,09 ns) | Cũng là quyết định chung, nhưng mỗi bit có cell mux khác nhau | **G05** |

> 🔎 Đây là kỹ thuật đọc STA đáng dạy: **hình dạng phân bố slack theo bit cho biết kiến trúc**,
> mà không cần mở netlist.

## 6. Đánh đổi công suất

| Quan sát | Số | Hệ quả |
|---|---|---|
| Tuần tự chiếm **73,2 %** (5,44e-05 W / 7,43e-05 W) | `power_report.txt` | 12 FF vẫn là nhóm tốn nhất |
| Tỷ lệ tổ hợp **cao nhất** trong ba đề về diện tích (68,2 %) nhưng chỉ 26,8 % công suất | so `synth_stat` và `power_report` | Logic tổ hợp của G07 **lớn nhưng ít chuyển mạch**: bộ so sánh và bộ trừ chỉ đổi khi dữ liệu đổi |
| Hoạt động thật rất khác nhau theo tình huống | — | **Lúc im lặng**: chỉ `count_q` (3 FF) chuyển mạch ⟹ công suất rất thấp. **Lúc có tín hiệu**: cả 8 bit `peak` + chuỗi so sánh chuyển mạch ⟹ cao hơn nhiều |
| Con số hiện tại dùng **hoạt động mặc định** | `power_report.txt` | Không phải VCD thật ⟹ không phản ánh được chênh lệch trên. Cần `corner_cases.md` GL-5 |

> Ý nghĩa thực tế: VU meter phần lớn thời gian ở chế độ "im lặng hoặc mức thấp", nên công
> suất **thực tế** có thể **thấp hơn đáng kể** 7,43e-05 W. Nhưng đó là **suy đoán**, chưa đo.

## 7. Những đánh đổi **KHÔNG được phép** trong đề này

| Việc | Vì sao cấm | Nguồn |
|---|---|---|
| Đổi sang **suy giảm theo hàm mũ** | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| Thêm **nhiều kênh** | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| Thêm chế độ **giữ đỉnh vô hạn** | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| **Bỏ bộ đếm**, tụt mỗi chu kỳ | Đúng rủi ro Charter mục 10 nêu tên: *"Suy giảm mỗi chu kỳ thay vì mỗi N chu kỳ — quên bộ đếm, đỉnh tụt ngay lập tức"* | Charter mục 10 |
| **Đảo thứ tự ưu tiên** (suy giảm thắng đỉnh mới) | Phá chức năng cốt lõi: VU meter sẽ **bỏ sót đỉnh ngắn** | Charter mục 9 |
| Bỏ **bão hoà tại 0** | `peak = 0` sẽ wrap thành 255 — lỗi nghiêm trọng nhất có thể của VU meter | `functional_spec.md` §4.2 |
| Tự **tối ưu netlist bằng tay** | Ngoài phạm vi với mọi đề | Charter mục 3 |
| **Sửa RTL của thầy** để thêm cổng `N` và cờ "đang suy giảm" | Hồ sơ này chỉ phân tích và cảnh báo | Quy tắc hồ sơ |
| Nói "G07 chạy được ở 199 MHz" | 5,02 ns gồm IO delay giả định, chưa có dây, 1 góc PVT, và là của `N = 8` | `timing.md` §3 |
| Báo cáo "ngân sách chân đủ (18/24)" mà **không** nói rõ thiếu 2 cổng Charter yêu cầu | Đủ chân **vì đã bỏ chức năng**, không phải vì giải được bài toán | `functional_spec.md` cảnh báo C4-4 |

## 8. Tóm tắt một câu

> Kiến trúc "bộ đếm + tụt tuyến tính 1 LSB, đỉnh mới ưu tiên tuyệt đối" của G07 là **đúng
> bản chất VU meter** và rẻ hơn dự kiến Charter (**12 FF** thay vì 24–25, **83 cell** thay vì
> 200–290) — nhưng khoản tiết kiệm đó **mua bằng hai thứ**: `N` **không đổi được sau chế
> tạo** (lệch Charter mục 4) và **cấu hình kiểm chứng `N = 2` khác cấu hình tổng hợp `N = 8`**;
> về timing, thiết kế **chậm nhất trong ba đề nhóm G** (5,02 ns, slack 4,87 ns) vì logic
> quyết định ưu tiên — tuy chỉ chiếm **1,0 %** diện tích — lại chiếm **25,6 %** đường tới hạn
> do phải lái **9 tải** từ một cell sức lái yếu.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
