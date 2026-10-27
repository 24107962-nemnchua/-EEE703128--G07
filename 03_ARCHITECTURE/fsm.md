# G07 · Máy trạng thái (FSM)

---

## 1. G07 có FSM không? — Có **một bộ đếm modulo-N**, nhưng nó bị "bẻ nhịp" bởi dữ liệu

Không có `typedef enum`, không có biến tên `state`, không có `case (state)`. Nhưng
`count_q[2:0]` thoả đầy đủ định nghĩa FSM:

| Tiêu chí FSM | `count_q` có? | Bằng chứng từ RTL / netlist |
|---|:-:|---|
| Tập trạng thái hữu hạn | ✅ | `logic [CW-1:0]` với `CW = $clog2(8) = 3` ⟹ 8 trạng thái |
| Trạng thái khởi tạo xác định | ✅ | `count_q <= '0` khi `!rst_n` (dòng 41) |
| Hàm chuyển trạng thái | ✅ | dòng 22–36 |
| Hàm sinh đầu ra | ✅ | `dec_now` điều khiển nhánh suy giảm |
| Ô nhớ giữ trạng thái | ✅ | `_151_`, `_152_`, `_153_` → `\count_q[0..2]` |

Điểm phân biệt G07 với G05: ở G05, bộ đếm chạy vòng tròn **đều đặn**, chỉ phụ thuộc
`valid_in`. Ở G07, bộ đếm có thể bị **đặt lại giữa chừng** bởi **dữ liệu** (`gt = 1`). Đó là
một FSM có **nhánh phụ thuộc dữ liệu** — loại FSM "thật" hơn.

## 2. Sơ đồ trạng thái (`N = 8`, `CW = 3`)

```
              valid_in = 0  (mọi trạng thái đều tự lặp — ĐÓNG BĂNG)
           ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
           ▼   │   ▼   │   ▼   │   ▼   │   ▼   │   ▼   │   ▼   │   ▼   │
        ┌──┴───┴┐ ┌┴───┴─┐ ┌┴───┴─┐ ┌┴───┴─┐ ┌┴───┴─┐ ┌┴───┴─┐ ┌┴───┴─┐ ┌┴──┴──┐
 rst ──▶│  C0   │▶│  C1  │▶│  C2  │▶│  C3  │▶│  C4  │▶│  C5  │▶│  C6  │▶│  C7  │
        └───┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘
            ▲        │        │        │        │        │        │        │
            │        │        │        │        │        │        │        │ ③ SUY GIẢM
            │        │        │        │        │        │        │        │ peak ← peak−1
            │        │        │        │        │        │        │        │ (bão hoà 0)
            │        └────────┴────────┴────────┴────────┴────────┴────────┘
            │                    ② ĐỈNH MỚI (gt = 1) — TỪ BẤT KỲ TRẠNG THÁI NÀO
            │                       peak ← sample_in,  count ← 0
            └──────────────────────────────────────────────────────────────────

  Mũi tên ngang (Ci → Ci+1): valid_in = 1 ∧ gt = 0 ∧ i < 7   ⟹ chỉ đếm tiếp
  Mũi tên C7 → C0 (③):       valid_in = 1 ∧ gt = 0            ⟹ TỤT 1 LSB
  Mũi tên bất kỳ → C0 (②):   valid_in = 1 ∧ gt = 1            ⟹ đỉnh mới, ĐẶT LẠI ĐỒNG HỒ

  ⚠ HAI đường khác nhau cùng về C0, với HAI tác dụng khác nhau lên peak.
     Phân biệt chúng là toàn bộ nội dung Charter mục 9.
```

## 3. Bảng chuyển trạng thái đầy đủ

| Trạng thái | `count_q` | `valid_in` | `gt` | Trạng thái kế | Tác dụng lên `peak` |
|---|:-:|:-:|:-:|---|---|
| C0…C7 | bất kỳ | 0 | × | **giữ nguyên** | giữ |
| C0…C6 | 0…6 | 1 | 0 | `Ci+1` | giữ |
| C0…C6 | 0…6 | 1 | **1** | **C0** | **← `sample_in`** |
| **C7** | 7 | 1 | 0 | **C0** | **← `max(peak−1, 0)`** |
| **C7** | 7 | 1 | **1** | **C0** | **← `sample_in`** ⚔ ưu tiên thắng suy giảm |
| bất kỳ | ××× | × (`rst_n = 0`) | × | **C0** | **← 0** |

Hàng áp chót là ô **cạnh tranh** — hai điều kiện cùng đúng, và nhánh đỉnh mới thắng. Đây là
ô mà `corner_cases.md` CC-13 chỉ ra là **chưa được kiểm trên RTL** (chỉ có ở golden model).

## 4. Mealy hay Moore? — **Mealy**, và bằng chứng mạnh hơn G05

Đầu ra (giá trị `peak_d`) phụ thuộc **cả** trạng thái (`count_q`) **và** đầu vào
(`sample_in`, `valid_in`) — và phụ thuộc vào **giá trị dữ liệu**, không chỉ vào cờ:

```systemverilog
if (sample_in > peak_q) begin   // ← ĐẦU VÀO DỮ LIỆU quyết định nhánh
    peak_d  = sample_in;
    count_d = '0;               // ← và nó còn ĐỔI TRẠNG THÁI
```

| Câu hỏi | Trả lời |
|---|---|
| Nếu là Moore thì sao? | `peak_d` sẽ chỉ phụ thuộc `count_q`. Không thể — vì "đỉnh mới" là sự kiện **dữ liệu**, không có lịch trình |
| Có phải Mealy cổ điển không? | **Không hoàn toàn** — `peak_out` và `valid_out` đều **được đăng ký** (registered Mealy). Bằng chứng netlist: `_143_…_150_` là `dfxtp_1` với `.Q(peak_out[…])` |
| Hệ quả thực tế | (a) `peak_out` **không glitch**; (b) STA phân loại đường này là in→reg, không phải in→out; (c) nhưng **giá phải trả** là tín hiệu `gt` phải lan qua toàn bộ bề rộng datapath **trong cùng một chu kỳ** — đó là 1,30 ns / 4,02 ns đã đo được |
| So với G05 | G05 cũng là registered Mealy, nhưng ở đó điều kiện phụ thuộc đầu vào chỉ là **cờ `valid_in`** (1 bit, sẵn sàng ngay). Ở G07 điều kiện là **kết quả so sánh 8 bit** (sẵn sàng muộn). Cùng loại FSM, chi phí timing khác hẳn |

## 5. Mã hoá trạng thái và **trạng thái bất hợp lệ** — phụ thuộc `N`

| Hạng mục | Giá trị |
|---|---|
| Kiểu mã hoá | **Nhị phân**, tự nhiên từ `count_q + 1` |
| Số bit | `CW = $clog2(N)` — **quyết định lúc biên dịch** |
| Với `N = 8` (cấu hình đã tổng hợp) | `CW = 3`, dùng 0…7, biểu diễn được 0…7 ⟹ **phủ kín, KHÔNG có trạng thái bất hợp lệ** |
| Với `N = 2` (cấu hình của testbench) | `CW = 1`, dùng 0…1 ⟹ **phủ kín** |
| Với `N = 5` (chưa ai thử) | `CW = 3`, dùng 0…4, biểu diễn được 0…7 ⟹ **BA trạng thái bất hợp lệ: 5, 6, 7** |

### Điều gì xảy ra nếu bộ đếm rơi vào trạng thái bất hợp lệ (`N = 5`)?

Đọc RTL: điều kiện tụt là `count_q == N-1`, tức `count_q == 4`. Nếu `count_q = 6`:

```
  count_q = 6  →  không phải 4  →  nhánh ⑤:  count_d = 6 + 1 = 7
  count_q = 7  →  không phải 4  →  nhánh ⑤:  count_d = 7 + 1 = 0   (tràn 3 bit)
  count_q = 0  →  quay về miền hợp lệ ✅
```

**May mắn: máy TỰ PHỤC HỒI** sau tối đa 3 mẫu, nhờ bộ đếm tràn về 0. Nhưng trong 3 mẫu đó
đồng hồ suy giảm bị **lệch nhịp** — đỉnh giữ lâu hơn bình thường. Và nếu điều kiện được viết
là `count_q >= N-1` thay vì `==`, máy sẽ tụt **sớm** thay vì lệch nhịp — hành vi khác hẳn.

> 🔎 **Bài học:** tính an toàn của FSM này **không phải** là thuộc tính của RTL — nó phụ
> thuộc **giá trị tham số**. Với `N` là luỹ thừa của 2 thì phủ kín và an toàn tuyệt đối; với
> `N` khác thì có trạng thái bất hợp lệ nhưng tự phục hồi nhờ tràn. Một hồ sơ nghiêm túc
> **phải nói rõ với giá trị `N` nào** thì kết luận an toàn mới đúng. Ca kiểm thử tương ứng:
> `corner_cases.md` CC-16 — **chưa có**.

## 6. Hai "đồng hồ" trong một mạch — cách nghĩ đúng về G07

Cách hiểu sáng nhất về G07: có **hai đồng hồ đếm ngược** chạy song song.

```
 ┌──────────────────────────────────────────────────────────────────┐
 │ ĐỒNG HỒ 1 — "bao giờ tụt?"        : count_q, chu kỳ N mẫu        │
 │ ĐỒNG HỒ 2 — "bao giờ về 0?"       : peak_q, cần 255 lần tụt      │
 └──────────────────────────────────────────────────────────────────┘

   Thời gian đỉnh 255 trôi hết  =  255 × N  mẫu hợp lệ
                                =  2040 mẫu  (N = 8)
                                =   510 mẫu  (N = 2, cấu hình testbench)

   ĐỈNH MỚI đặt lại ĐỒNG HỒ 1 về 0 VÀ nạp lại ĐỒNG HỒ 2 bằng sample_in.
```

Chỉ đồng hồ 1 là **FSM** (miền hữu hạn nhỏ, điều khiển nhánh). Đồng hồ 2 (`peak_q`) là
**trạng thái dữ liệu** — 256 giá trị, nhưng mọi giá trị dẫn tới cùng một hành động, **trừ
một ngoại lệ**: giá trị `0` kích hoạt nhánh bão hoà. Nói chặt, `peak_q` là trạng thái dữ liệu
có **một** điểm đặc biệt, chứ không thuần tuý dữ liệu như `y_q` của G06.

## 7. Khi nào FSM `enum` sẽ xuất hiện ở đề này

| Mở rộng giả định | Cần FSM `enum`? | Số trạng thái |
|---|:-:|---|
| **Nạp `N` qua `uio_in[7:0]` như Charter mục 4 yêu cầu** | ⚠️ **có thể** — nếu phải nạp hai nhịp vì thiếu chân | 2–3: `LOAD_HI`, `LOAD_LO`, `RUN` |
| Thêm cờ **"đang suy giảm"** như Charter yêu cầu | ❌ không — chỉ cần đưa biểu thức có sẵn ra một FF | — |
| **Suy giảm theo hàm mũ** | ✅ có thể cần | phụ thuộc thuật toán |
| **Chế độ giữ đỉnh vô hạn** (bật/tắt) | ✅ **có** | 2: `HOLD`, `DECAY` |
| Nhiều kênh dùng chung một bộ so sánh | ✅ **có** | `k` trạng thái cho `k` kênh |

Bốn dòng dưới đều **ngoài phạm vi** (Charter mục 3). Dòng đầu thì **trong** phạm vi và
**chưa làm** — đó chính là khoảng cách RTL ↔ Charter mục 4 đã ghi ở đầu `functional_spec.md`.

> **Quy tắc rút ra, áp dụng cho cả nhóm G:** FSM `enum` xuất hiện khi mạch phải làm **những
> việc khác nhau ở những giai đoạn khác nhau**. G06 luôn làm một việc ⟹ không FSM. G05 làm ba
> việc loại trừ nhau theo lịch ⟹ FSM dạng bộ đếm. G07 làm hai việc **cạnh tranh theo dữ liệu**
> ⟹ FSM dạng bộ đếm **cộng** logic ưu tiên — và chính logic ưu tiên đó, chứ không phải bộ
> đếm, mới là thứ tốn 25,6 % đường tới hạn.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
