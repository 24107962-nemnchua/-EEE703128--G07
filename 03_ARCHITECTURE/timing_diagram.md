# G07 · Giản đồ thời gian (Timing Diagram)

---

## 1. Điều phải nói trước mọi giản đồ

Waveform dưới đây dựng lại từ **chính** `05_VERIFICATION/testbench/g07_tb.sv` (60 dòng) và
ngữ nghĩa của `g07_peak_decay.sv`, đối chiếu với `05_VERIFICATION/simulation.log`
(`G07 TB completed`, `$finish` tại **136**).

> ⚠️ **Waveform này là của cấu hình `N = 2`**, vì testbench khởi tạo
> `g07_peak_decay #(.W(8),.N(2))` (dòng 6). Netlist, STA và mọi số liệu diện tích/timing
> trong hồ sơ là của **`N = 8`**. Xem `corner_cases.md` §5.1. Với `N = 8`, hình dạng waveform
> giống nhau nhưng mỗi lần tụt cần **8** mẫu thay vì **2**.

> ❗ Đây là mô phỏng **hành vi (behavioural, zero-delay)**. Mọi tín hiệu đổi mức **đúng tại**
> cạnh lên clock. Giản đồ **không** minh hoạ được: `clk→Q` của `dfxtp_1`, 4,02 ns lan truyền
> qua chuỗi borrow + tầng ưu tiên, **đặc biệt là 1,03 ns của cell `_089_` với slew 1,26 ns**,
> glitch trên `peak_d` khi 8 bit `sample_in` đổi lệch nhau, hay vi phạm setup. Muốn thấy phải
> mô phỏng **gate-level** trên `netlist.v` — bước này **chưa chạy**.

**Quy ước đánh số:** `always #5 clk = ~clk` ⟹ chu kỳ 10 ns, cạnh lên thứ `n` tại
`t = 5 + 10(n−1)` ns. Testbench lấy mẫu tại cạnh lên **+1 ns**.

## 2. Bản đồ toàn bộ lần chạy thật (`N = 2`)

| Cạnh lên | `t` (ns) | Dòng TB | `sample_in` | Nhánh kích hoạt | `peak_out` sau | `count_q` sau | Kết quả |
|---:|---:|---:|---:|---|---:|---:|:-:|
| 1–2 | 5, 15 | 29–31 | 0 | reset | 0 | 0 | — |
| 3 | 25 | 34 | **10** | ② đỉnh mới (10 > 0) | **10** | 0 | ✅ |
| 4 | 35 | 37 | 1 | ⑤ đếm tiếp | 10 | **1** | ✅ |
| 5 | 45 | 38 | 1 | ③ **SUY GIẢM** (`count = N−1 = 1`) | **9** | 0 | ✅ |
| 6 | 55 | 41 | **20** | ② đỉnh mới (20 > 9) | **20** | 0 | ✅ |
| 7 | 65 | 44–46 | — | **reset giữa dòng** | **0** | 0 | — |
| 8 | 75 | 47 | 1 | ② đỉnh mới (1 > 0) | **1** | 0 | ✅ |
| 9 | 85 | 48 | 0 | ⑤ đếm tiếp | 1 | **1** | ✅ |
| 10 | 95 | 49 | 0 | ③ suy giảm | **0** | 0 | ✅ |
| 11 | 105 | 50 | 0 | ⑤ đếm tiếp | 0 | **1** | ✅ |
| 12–14 | 115…135 | 53–55 | — | `valid_in = 0` ⟹ **đóng băng** | 0 | **1** | ✅ `!valid_out` |

**Kiểm tra số học:** cạnh lên 14 tại `t = 5 + 10 × 13 = 135`, cộng `#1` = **136 ns**. Khớp
chính xác dòng cuối `simulation.log`: `$finish called at 136`.

## 3. Giao dịch điển hình — một đỉnh, suy giảm, rồi đỉnh mới cao hơn (cạnh lên 1 → 7)

```
 cạnh lên     │  1  │  2  │  3  │  4  │  5  │  6  │  7  │
 t (ns)       5    15    25    35    45    55    65    75
              ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
 clk     ─────┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └────
              ▲     ▲     ▲     ▲     ▲     ▲     ▲
                    ┌─────────────────────────────┐
 rst_n   ───────────┘  (=1 từ t=15)                └───────  (=0 tại cạnh 7!)
         (=0)
                    ┌───────────────────────────┐
 valid_in ──────────┘  (=1 liền mạch từ t=15 —   └──────────    (=0 từ t=56)
                        mỗi send() nhả 1 ns rồi bật lại ngay)
                     ①     ②     ③     ④   ← bốn mẫu, bốn cạnh lên

 sample_in ═══ 0 ═══╪═ 10 ═╪══ 1 ═╪══ 1 ═╪═ 20 ═╪═════ 20 ══════

 ┌─ SO SÁNH (tổ hợp, KHÔNG phải thanh ghi) ────────────────────────┐
 │ gt = s > peak_q ──╪══ 1 ══╪══ 0 ══╪══ 0 ══╪══ 1 ══╪            │
 └──────────────────────────────────────────────────────────────────┘

 count_q  ══ x ═╪══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 1 ══╪══ 0 ══╪══ 0 ══╪══ 0
                                  ▲       ▲       ▲       ▲
                        gt=1 ⟹ 0 ─┘       │       │       └─ gt=1 ⟹ 0 lần nữa
                                  ⑤ đếm ──┘       └─ ③ count=N−1 ⟹ tụt, về 0

 peak_out ══ x ═╪══ 0 ══╪══ 0 ══╪═ 10 ═╪═ 10 ═╪══ 9 ══╪═ 20 ═╪══ 0 ══
                                  ▲▲▲▲   giữ    ▲▲▲     ▲▲▲     ▲▲▲
                    ② ĐỈNH MỚI ───┘             │       │       └─ reset (cạnh 7)
                       peak ← 10                 │       └─ ② ĐỈNH MỚI THẮNG
                                                 └─ ③ SUY GIẢM: 10 → 9
                                                    (KHÔNG phải 10 → 1!)
                        ┌──┐  ┌──┐  ┌──┐  ┌──┐
 valid_out ─────────────┘  └──┘  └──┘  └──┘  └────────────  (trễ valid_in 1 nhịp)
```

### Đọc gì từ giản đồ này

| Quan sát | Ý nghĩa |
|---|---|
| Cạnh 4: `sample_in = 1` nhưng `peak_out` **giữ 10** | Đây là bản chất "peak hold": mẫu **thấp hơn không kéo đỉnh xuống ngay**. Nếu peak bám mẫu, cạnh 4 sẽ cho `peak_out = 1` — đó là lỗi, và ca CC-3 bắt được |
| Cạnh 5: `peak_out` đi **10 → 9**, không phải 10 → 1 | Suy giảm là **1 LSB**, không phải "nhảy về mức hiện tại". Đây là điều làm VU meter dễ nhìn |
| Cạnh 5 xảy ra khi `count_q = 1 = N−1` | Với `N = 2`, phải chờ **2** mẫu mới tụt một lần. Nếu quên bộ đếm (rủi ro Charter mục 10), cạnh 4 đã tụt rồi — ca CC-1 bắt được |
| Cạnh 6: `peak_out` **nhảy 9 → 20** ngay lập tức | Ưu tiên ②: đỉnh mới **không** chờ lịch trình. Đây là chức năng cốt lõi — VU meter phải bắt được đỉnh ngắn |
| `count_q` về 0 ở **cả** cạnh 5 (③) và cạnh 6 (②) | **Hai đường khác nhau cùng về C0** — xem `fsm.md` §2. Phân biệt chúng là nội dung Charter mục 9 |
| `gt` là **tổ hợp**, đổi giữa chu kỳ | `gt` không phải thanh ghi. Ở mô phỏng hành vi nó đổi tức thời; thực tế nó cần **2,62 ns chuỗi borrow + 1,03 ns tầng lái** mới ổn định |
| `valid_out` trễ `valid_in` đúng 1 nhịp, **kể cả** khi đang reset | Vì `valid_out <= valid_in` nằm **ngoài** `if (valid_in)`. Tại cạnh 7 (`rst_n = 0`) thì `valid_out <= 0` theo nhánh reset |

## 4. Ca biên: **bão hoà tại 0** (cạnh lên 7 → 12)

```
 cạnh lên     │  7  │  8  │  9  │ 10  │ 11  │ 12  │
 t (ns)      65    75    85    95   105   115
              ▲     ▲     ▲     ▲     ▲     ▲
 rst_n   ─────┐     ┌─────────────────────────────
              └─────┘  (=0 CHỈ tại cạnh 7 — reset giữa dòng)

 valid_in ─────┐     ┌─────────────────────────┐
               └─────┘ (=0 từ t=56 tới t=66,   └──────  (=0 từ t=106)
                        rồi =1 liền mạch qua 4 mẫu)

 sample_in ══ 20 ══╪══ 1 ══╪══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 0 ═

 count_q  ══ 0 ═══╪══ 0 ══╪══ 0 ══╪══ 1 ══╪══ 0 ══╪══ 1 ══╪══ 1 (ĐÓNG BĂNG)

 peak_out ══ 20 ══╪══ 0 ══╪══ 1 ══╪══ 1 ══╪══ 0 ══╪══ 0 ══╪══ 0
                    ▲▲▲     ▲▲▲     giữ     ▲▲▲     ▲▲▲
          reset ────┘       │               │       └─ ⑤ đếm tiếp, peak GIỮ 0
          xoá cả peak       │               └─ ③ SUY GIẢM: 1 → 0
          lẫn count         └─ ② đỉnh mới (1 > 0)
                                                  ┌─────────────────────────
          ⚠ Nếu THIẾU bão hoà: chu kỳ tiếp theo   │ peak sẽ là 0 − 1 = 255
            khi count lại tới N−1, peak = 0       │ ⟹ VU meter NHẢY LÊN HẾT
            sẽ wrap thành 255                     │    THANG khi đang IM LẶNG
                                                  └─────────────────────────
```

**Ca này kiểm hai thứ cùng lúc:**

1. **Reset giữa dòng** (cạnh 7): `peak_out` từ 20 về 0 **và** `count_q` về 0. Reset **đồng
   bộ** — nó chỉ có tác dụng vì có cạnh lên. Bằng chứng netlist: 12 flip-flop đều là
   `dfxtp_1`, loại **không có** chân reset.
2. **Bão hoà tại 0** (cạnh 10 và 11): `peak` xuống 0 rồi **giữ 0**. Biểu thức bảo vệ là
   `(peak_q == '0) ? '0 : peak_q - 1'b1` — một cây NOR 8 đầu vào và một mux.

> 🔎 Testbench dừng sau **một** chu kỳ đếm ở mức 0 (cạnh 11, `count_q = 1`). Nó **chưa** chạy
> tới lần tụt tiếp theo khi `peak` đã bằng 0 — tức chưa **thật sự** kích hoạt nhánh bão hoà
> lần thứ hai. Golden model có ca đầy đủ (`test_zero_saturation()`: `[1] + [0]*8` với `N=1`).
> Xem `corner_cases.md` CC-12.

## 5. Khe `valid_in` thấp — đóng băng, **không** tụt theo thời gian (cạnh lên 12–14)

```
 cạnh lên     │ 12  │ 13  │ 14  │
 t (ns)     115   125   135
              ▲     ▲     ▲
 valid_in ────────────────────────  (=0 suốt, từ t=106)
 count_q  ══ 1 ═══╪══ 1 ══╪══ 1 ══╪══ 1     ← ĐÓNG BĂNG ở 1, KHÔNG nhích
 peak_out ══ 0 ═══╪══ 0 ══╪══ 0 ══╪══ 0     ← ĐÓNG BĂNG
 valid_out ───────────────────────          ← 0 (trễ 1 nhịp của valid_in = 0)
                    ▲     ▲     ▲
           TB assert(!valid_out) tại t = 136 ✅
```

Đây là bằng chứng waveform cho **INV-6** và cho ngữ nghĩa quan trọng nhất về mặt tích hợp:

> **Suy giảm đếm theo SỐ MẪU HỢP LỆ, không theo THỜI GIAN.** Nếu nguồn mẫu dừng, VU meter
> **đứng yên** thay vì trôi về 0. Với ứng dụng thật, đây có thể là hành vi mong muốn (không
> có tín hiệu ⟹ không cập nhật) hoặc không mong muốn (người dùng thấy đỉnh treo mãi). Tầng
> ngoài phải quyết định: nếu muốn trôi theo thời gian, `valid_in` phải đến từ bộ chia clock
> cố định chứ không từ cờ `data_ready` của ADC.

## 6. Ba thứ waveform hành vi này **không** cho thấy

| Không thấy được | Vì sao | Số thật có ở đâu |
|---|---|---|
| Tín hiệu `gt` lan **chậm** tới 8 mux | Mô phỏng zero-delay cho `gt` ngay lập tức | `timing_report_max.txt`: `_089_/Y` có **fanout 9, slew 1,26 ns, delay 1,03 ns** — **25,6 %** của 4,02 ns |
| Chuỗi borrow lan dần qua 7 tầng `maj3_1` | như trên | 2,62 ns = 65,2 % của đường |
| Glitch trên `peak_d` khi `sample_in` đổi | `always_comb` cho kết quả cuối ngay | Chỉ thấy ở gate-level có SDF. Glitch **không** ảnh hưởng chức năng (bị thanh ghi lọc) nhưng ảnh hưởng **công suất** |
| Vi phạm setup khi chu kỳ co lại | Cần mô hình độ trễ | Slack 4,87 ns với chu kỳ **giả định** 10 ns, clock **lý tưởng**, chưa có dây, một góc PVT |

> ❗ Không được kết luận "G07 chạy được ở 199 MHz" từ 5,02 ns. Con số đó gồm 1,00 ns IO delay
> **giả định**, chưa có ký sinh dây, mới một góc PVT — và nó là của cấu hình **`N = 8`**, trong
> khi waveform trên là của **`N = 2`**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
