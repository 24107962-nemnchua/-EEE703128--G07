# G07 · Bối cảnh ứng dụng



| | |
|---|---|
| Mã đề | **G07** |
| Tên đề | Bộ phát hiện đỉnh có suy giảm |
| Nhóm đề | G · Xử lý tín hiệu số đơn giản |
| Độ khó | Trung bình |
| Loại mạch | **Tuần tự** |
| Quy mô ước lượng (Charter) | ~200–290 cell · 1×1 tile |
| Nguồn gốc | Project Charter — G07, mục 1 |

---

## 1. Mục tiêu và bối cảnh ứng dụng

Trích nguyên văn Charter mục 1:

> Phân tích khối số “Bộ phát hiện đỉnh có suy giảm” ở mức khối. Bối cảnh ứng dụng: Khối giữ mức đỉnh trên đồng hồ đo âm thanh (VU meter), tự tụt dần để người xem thấy đỉnh rồi thấy mức hiện tại.

## 2. Vị trí khối G07 trong hệ thống

```
   ┌──────────────┐      ┌──────────────────────────────┐      ┌──────────────┐
   │  Nguồn tín   │─────▶│      ►►► KHỐI G07 ◄◄◄        │─────▶│  Tầng tiêu   │
   │  hiệu / dữ   │      │  Bộ phát hiện đỉnh có suy giả │      │  thụ kết quả │
   │  liệu vào    │      │  Loại mạch: Tuần tự          │      │              │
   └──────────────┘      └──────────────────────────────┘      └──────────────┘
```

> Sơ đồ chi tiết có chú thích: `03_ARCHITECTURE/system_diagram.md`.

## 3. Phân loại analog / digital / mixed

| Khối | Phân loại | Ghi chú |
|---|---|---|
| Cảm biến / nguồn tín hiệu vật lý (nếu có) | Analog | Đại lượng liên tục |
| Chuyển đổi ADC/DAC (nếu có) | Mixed-signal | Ranh giới analog–số |
| **G07 — Bộ phát hiện đỉnh có suy giảm** | **Digital, tuần tự** | Có ô nhớ, hoạt động theo cạnh clock |
| Tầng xử lý phía sau | Digital | Tiêu thụ kết quả của G07 |

Bằng chứng cho dòng phân loại của G07: tổng hợp thật cho **12 flip-flop**
(`06_GDSII/synthesis/synth_stat.txt`).

---

**Truy vết:** yêu cầu sinh từ tài liệu này được đánh số `REQ-G07-0xx` trong
`01_REQUIREMENT/requirements.md`, và truy vết đến bằng chứng trong `07_TRACEABILITY/RTM.csv`.

*Phiên bản: v1.0 · Ngày: 2026-09-24*
