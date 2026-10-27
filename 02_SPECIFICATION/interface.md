# G07 · Giao diện (Interface)

---

## 1. Ánh xạ chân theo Charter (mục 4)

> Theo danh mục đề: ui_in[7:0]=mẫu · uio_in[7:0]=N · uo_out[7:0]=giá trị đỉnh hiện tại · uio_out[0]=đang suy giảm
> Ngân sách chân: 16 bit vào + 9 bit ra = 25 trên 24 chân.
> Vượt ngân sách chân: thiết kế cần 25 bit trong khi ô chỉ có 24 chân. Khối này là mạch tuần tự nên nạp hai nhịp là cách xử lý thông thường: một nhịp nạp toán hạng thứ nhất, nhịp sau nạp toán hạng thứ hai.
> Một ô Tiny Tapeout có đúng 24 chân: ui_in 8 chỉ vào, uo_out 8 chỉ ra, uio 8 chọn chiều từng chân. uio_in và uio_out là cùng một bộ chân vật lý.

## 2. Bảng giao diện đã CHỐT — module `g07_peak_decay`

Bảng dưới đây **đọc trực tiếp từ RTL** (`04_IMPLEMENTATION/rtl/`), không phải chép tay,
nên luôn nhất quán với mã nguồn.

| Tín hiệu | Chiều | Độ rộng (bit) | Vai trò | Mức tích cực / giả định |
|---|---|---:|---|---|
| `clk` | input | 1 | clock | |
| `rst_n` | input | 1 | reset (đồng bộ hoá trạng thái) | |
| `valid_in` | input | 1 | trạng thái / bắt tay | |
| `sample_in[W-1:0]` | input | ? | dữ liệu vào | |
| `peak_out[W-1:0]` | output | ? | kết quả ra | |
| `valid_out` | output | 1 | trạng thái / bắt tay | |

**Tổng hợp:** 4 cổng vào (3 bit) · 2 cổng ra (1 bit).

**Clock:** `clk`

**Reset:** `rst_n`

## 3. Ngân sách chân Tiny Tapeout

| Hạng mục | Số bit |
|---|---:|
| Tổng bit vào | **3** |
| Tổng bit ra | **1** |
| **Tổng cộng** | **4** |
| Ô Tiny Tapeout có | **24** |
| **Chênh lệch** | **20 chân còn dư** |

> Nhắc lại cấu trúc chân Tiny Tapeout: một ô có đúng 24 chân — `ui_in` 8 chỉ vào,
> `uo_out` 8 chỉ ra, `uio` 8 chọn chiều từng chân; **`uio_in` và `uio_out` là cùng một bộ
> chân vật lý**.

> ✅ Ngân sách chân **đủ**: tổng số bit logic nằm trong 24 chân vật lý, không cần
> nạp nhiều nhịp và không phải hy sinh tín hiệu nào.

## 4. Điều kiện hợp lệ của đầu vào

| Điều kiện | Ai bảo đảm |
|---|---|
| Các cổng vào không chứa `X`/`Z` khi lấy mẫu | Tầng ngoài |
| Tín hiệu vào đồng bộ với `clk` hoặc đã qua bộ đồng bộ | Tầng ngoài |
| Chuỗi reset được giữ đủ dài trước khi bắt đầu hoạt động | Tầng ngoài |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-G07-002, AC-1.*
