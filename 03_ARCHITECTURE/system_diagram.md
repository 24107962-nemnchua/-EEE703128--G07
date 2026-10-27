# G07 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng — khối này nằm ở đâu

Charter mục 1: *"Khối giữ mức đỉnh trên đồng hồ đo âm thanh (VU meter), tự tụt dần để người
xem thấy đỉnh rồi thấy mức hiện tại."*

```
  THẾ GIỚI ANALOG                    │            MIỀN SỐ (digital)
                                     │
 ┌────────┐ ┌────────┐ ┌─────────────┴┐ ┌──────────┐ ┌─────────────┐ ┌──────────┐
 │ Micro  │ │ Tiền   │ │     ADC      │ │ Trị tuyệt│ │ ██ G07 ██   │ │ Giải mã  │
 │ (analog│▶│ khuếch │▶│   8 bit      │▶│ đối /    │▶│ peak hold   │▶│ thang    │─▶ LED /
 │  )     │ │ đại +  │ │  fs vài kHz  │ │ chỉnh lưu│ │ + suy giảm  │ │ (bar     │   màn hình
 └────────┘ │ lọc    │ └──────┬───────┘ └──────────┘ └──────┬──────┘ │  graph)  │
            └────────┘        │                             │        └──────────┘
                         ┌────┴─────┐                       │
                         │ valid_in │───────────────────────┘
                         │ 1 xung   │
                         │ / mẫu    │
                         └──────────┘
```

**Phân loại:** G07 là khối **thuần số (digital)**, đồng bộ. Ranh giới analog/digital ở **ADC**.

**Vì sao cần suy giảm:** nếu chỉ giữ đỉnh (peak hold thuần), sau vài giây VU meter sẽ đứng
ở mức cao nhất từng đo và **không bao giờ xuống** — vô dụng. Nếu bám mẫu tức thời, người xem
**không kịp thấy** các đỉnh ngắn. Suy giảm 1 LSB mỗi `N` mẫu là chỗ dung hoà: đỉnh hiện ra
rõ, rồi **trôi xuống** đủ chậm để mắt theo kịp. `N` chính là núm chỉnh tốc độ trôi đó.

**Ngữ nghĩa quan trọng cần nói với người tích hợp:** suy giảm tính theo **số mẫu hợp lệ**,
**không** theo thời gian. Nếu tốc độ mẫu đổi, tốc độ trôi đổi theo. Muốn trôi theo thời gian
thật, `valid_in` phải đến từ bộ chia clock cố định, không từ cờ `data_ready` của ADC.

## 2. Ranh giới khối — cái gì **trong**, cái gì **ngoài**

| Chức năng | Trong G07? | Nếu ngoài thì ai làm |
|---|:-:|---|
| So sánh mẫu với đỉnh đang giữ | ✅ | `sample_in > peak_q` |
| Giữ đỉnh | ✅ | `peak_q` (hợp nhất với `peak_out`), 8 FF |
| Đếm `N` mẫu giữa hai lần tụt | ✅ | `count_q`, 3 FF (`$clog2(8)`) |
| Tụt 1 LSB, có **bão hoà tại 0** | ✅ | `(peak_q == '0) ? '0 : peak_q - 1'b1` |
| Quyết định **ưu tiên** khi đỉnh mới và lúc tụt trùng nhau | ✅ | Thứ tự `if`/`else if` trong `always_comb` |
| **Chỉnh lưu / trị tuyệt đối** tín hiệu âm thanh | ❌ | Tầng ngoài — G07 so sánh **không dấu** |
| **Chọn `N` lúc chạy** | ❌ **và cũng không có ở đâu** | `N` là **tham số biên dịch**. Charter mục 4 yêu cầu nạp qua `uio_in[7:0]` — **CHƯA THOẢ** |
| **Cờ "đang suy giảm"** | ❌ **và cũng không có ở đâu** | Charter mục 4 yêu cầu `uio_out[0]` — **CHƯA THOẢ** |
| Giải mã thang LED / bar graph | ❌ | Tầng ngoài |
| Suy giảm theo **hàm mũ** | ❌ | Charter mục 3: ngoài phạm vi |
| Nhiều kênh (trái/phải) | ❌ | Charter mục 3: ngoài phạm vi. Cần **nhân bản** khối |

> **Nghĩa vụ hợp đồng của tầng ngoài, năm điều:**
> 1. Đưa vào **biên độ không dấu** (đã chỉnh lưu), không phải mẫu có dấu.
> 2. `valid_in` là **xung một chu kỳ** cho mỗi mẫu mới.
> 3. Giữ `rst_n = 0` qua **ít nhất một** cạnh lên (reset đồng bộ).
> 4. **Tự biết `N`** — khối không báo ra, và không nhận vào.
> 5. **Tự suy ra "đang suy giảm"** nếu cần — ví dụ bằng cách phát hiện `peak_out` giảm giữa
>    hai chu kỳ có `valid_out = 1`.

## 3. Hai hành vi cạnh tranh — sơ đồ ưu tiên (Charter mục 9)

Đây là điểm đặc trưng của G07 so với G05 và G06: **hai hành vi có thể yêu cầu ghi cùng một
thanh ghi trong cùng một chu kỳ.**

```
                          ┌─────────────────────────┐
     sample_in[7:0] ─────▶│  SO SÁNH:  s > peak_q ? │────┐
     peak_q[7:0]   ─────▶│  (8 bit, không dấu)     │    │ gt
                          └─────────────────────────┘    │
                                                          ▼
     count_q[2:0] ──────▶┌─────────────────────────┐   ┌─────┐
                          │  count_q == N−1 ?       │──▶│ ƯU  │──▶ chọn 1 trong 3:
                          └─────────────────────────┘   │ TIÊN│      ① peak ← s
                                                         │     │      ② peak ← peak−1
                          (N ≤ 1 ?  → hằng số, bị       │ gt  │      ③ peak giữ
                           Yosys loại bỏ khi N = 8)     │ THẮNG│
                                                         └─────┘
     ┌──────────────────────────────────────────────────────────────────┐
     │  BẢNG ƯU TIÊN — đọc thẳng từ thứ tự if/else if trong always_comb │
     ├──────────┬──────────────┬───────────────────────────────────────┤
     │   gt     │ count = N−1  │  Kết quả                              │
     ├──────────┼──────────────┼───────────────────────────────────────┤
     │    1     │      0       │  ① peak ← s,  count ← 0               │
     │    1     │      1       │  ① peak ← s,  count ← 0   ⚔ CẠNH TRANH│
     │    0     │      0       │  ④ count ← count+1                    │
     │    0     │      1       │  ③ peak ← max(peak−1,0), count ← 0    │
     └──────────┴──────────────┴───────────────────────────────────────┘
```

**Phần cứng nào quyết định thứ tự ưu tiên?** Không phải một khối "trọng tài" riêng — nó là
**tín hiệu `gt` lái chân chọn của mux**. Trên đường tới hạn thật (`timing_report_max.txt`),
tín hiệu đó là đầu ra của cell **`_089_` (`a21boi_0`)**, và nó đi thẳng vào chân **`S`** của
`_097_ (mux2i_1)`. Chi tiết và số liệu: `datapath.md` §4 và `control.md` §3.

## 4. Vị trí trong một ô Tiny Tapeout 1×1

```
 ┌───────────────── ô Tiny Tapeout 1×1 (24 chân) ─────────────────┐
 │                                                                 │
 │   ui_in[7:0] ──▶┌───────────────────────────────────────┐       │
 │                 │  ⬜ LỚP VỎ tt_um_* — CHƯA TỒN TẠI      │       │
 │  uio_in[7:0] ──▶│  Charter yêu cầu uio_in[7:0] = N       │      │
 │                 │  ❌ RTL KHÔNG CÓ cổng N               │       │
 │       ena ─────▶│  Charter yêu cầu uio_out[0]="đang suy  │      │
 │                 │  giảm" ❌ RTL KHÔNG CÓ cổng này        │      │
 │                 │   ┌────────────────────────────────┐  │       │
 │                 │   │ ✅ g07_peak_decay (module lõi)  │  │      │
 │                 │   │    N = 8 CỐ ĐỊNH lúc tổng hợp   │  │      │
 │                 │   │    83 cell · 12 FF · 754,47 µm² │  │      │
 │                 │   └────────────────────────────────┘  │       │
 │                 └───────────────────────────────────────┘       │
 │  uo_out[7:0] ◀──                                                │
 └─────────────────────────────────────────────────────────────────┘
```

| Kịch bản | Bit dữ liệu | So với 24 chân |
|---|---:|---|
| RTL hiện tại (không có `N`, không có cờ suy giảm) | 9 vào + 9 ra = **18** | ✅ dư 6 — **nhưng thiếu chức năng** |
| Nếu bổ sung đủ theo Charter mục 4 | 17 vào + 10 ra = **27** | ❌ **thiếu 3 chân** — lúc đó "nạp hai nhịp" mới thật sự cần |

> 🔎 **Điểm đáng nói khi bảo vệ:** bài toán "vượt ngân sách chân" mà Charter mục 4 đặt ra đã
> bị **né**, không phải **giải** — bằng cách bỏ hẳn hai cổng. Đây không nhất thiết là sai (có
> thể là quyết định có ý thức để giữ đề đơn giản), nhưng **phải được ghi nhận**, không được
> báo cáo là "ngân sách chân đủ".

## 5. Vòng đời RTL → GDSII — trạng thái **thật**

Lấy từ `06_GDSII/physical_report.md` §1. ✅ đã chạy · ⚠️ có lưu ý · ⬜ chưa · ⬛ không áp dụng.

```
 ┌───────────────┐
 │ Charter G07   │  ✅
 └───────┬───────┘
 ┌───────▼───────┐
 │ Đặc tả        │  ✅  02_SPECIFICATION/  (có cảnh báo Charter mục 4 CHƯA THOẢ)
 └───────┬───────┘
 ┌───────▼───────┐
 │ RTL           │  ✅  g07_peak_decay.sv (55 dòng), parameter W=8, N=8
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô hình chuẩn │  ✅  reference_model.py — PASS (10 test, N từ 1 tới 16)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô phỏng RTL  │  ⚠️  PASS — nhưng với cấu hình N = 2, KHÁC cấu hình tổng hợp (N = 8)
 │               │     $finish @ 136 · xem corner_cases.md §5.1
 └───────┬───────┘
 ┌───────▼───────┐
 │ Tổng hợp      │  ✅  Yosys 0.33 → 83 cell · 12 FF · 754,4736 µm²   [N = 8]
 └───────┬───────┘
 ┌───────▼───────┐
 │ STA           │  ✅  OpenSTA 3.1.0 → 5,02 ns · slack 4,87 ns · WNS/TNS = 0,00
 └───────┬───────┘
 ┌───────▼───────┐
 │ Công suất     │  ✅  ước lượng 7,43e-05 W (tổ hợp 26,8 % · tuần tự 73,2 %)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô phỏng gate │  ⬜  test_matrix.csv: L4-GATE = CHUA CHAY
 ├───────────────┤       (và cần sửa TB sang N = 8 trước khi chạy được)
 │ Floorplan …   │  ⬜  cần LibreLane + PDK sky130A
 │ GDSII         │  ⬜  (Charter mục 3: phần MỞ RỘNG, tự nguyện)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Sign-off      │  ⬛  Charter mục 3: NGOÀI PHẠM VI
 │ Tape-out      │  ⬛
 │ Chế tạo · test│  ⬛
 └───────────────┘
```

> ❗ Ô "Mô phỏng RTL" được đánh ⚠️ chứ không phải ✅ **dù log ghi PASS**, vì nó kiểm một mạch
> (`N = 2`) khác với mạch đã được tổng hợp (`N = 8`). Đây là lý do `README.md` của hồ sơ ghi
> "PASS" nhưng kết luận ở `07_TRACEABILITY/limitations.md` phải nói rõ phạm vi.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
