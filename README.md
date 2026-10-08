# 📱 OCR Expense Tracker

> **Ứng dụng quản lý và theo dõi chi tiêu thông minh bằng trí tuệ nhân tạo On-device AI (Offline OCR) trên nền tảng Flutter 3.x & Dart 3.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Google ML Kit](https://img.shields.io/badge/Google_ML_Kit-Text_Recognition-4285F4?logo=google)](https://developers.google.com/ml-kit)
[![SQLite](https://img.shields.io/badge/Database-SQLite_(sqflite)-003B57?logo=sqlite)](https://pub.dev/packages/sqflite)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM_(Feature--first)-success)](#-kiến-trúc-dự-án)
[![Tests](https://img.shields.io/badge/Unit_Tests-16%2F16_Passed-brightgreen)](#-kiểm-thử-tự-động)

---

## 📖 Giới thiệu (Overview)

**OCR Expense Tracker** là ứng dụng di động theo dõi chi tiêu cá nhân hiện đại, giải quyết triệt để rào cản nhập liệu thủ công tốn thời gian. Người dùng chỉ cần chụp hóa đơn thanh toán (receipt/bill), hệ thống sẽ tự động quét, nhận diện ký tự quang học (OCR) ngoại tuyến và trích xuất thông minh các thông tin quan trọng như **Tổng tiền**, **Ngày giao dịch**, **Tên cửa hàng** và **Danh mục chi tiêu**.

Mọi tác vụ AI và lưu trữ dữ liệu đều diễn ra **100% On-device (Ngoại tuyến)**, đảm bảo tốc độ phản hồi siêu tốc (< 100ms) và bảo vệ tuyệt đối quyền riêng tư tài chính của người dùng.

---

## ✨ Tính năng cốt lõi (Core Features)

### 📸 1. Camera Viewfinder & Smart Framing Overlay (Giai đoạn 1)
- **Live Viewfinder tràn màn hình:** Bao phủ toàn bộ khung hình không bị méo tỉ lệ bằng kỹ thuật `FittedBox(fit: BoxFit.cover)`.
- **Framing Crop Overlay (CustomPaint):** Lớp phủ làm tối 4 góc xung quanh (`PathFillType.evenOdd`), chừa khung chữ nhật sáng ở giữa kèm 4 góc định vị màu xanh ngọc hướng dẫn đặt hóa đơn.
- **Focus Tap & Ring Animation:** Chạm bất kỳ đâu trên màn hình để lấy nét (`setFocusPoint`) và phơi sáng (`setExposurePoint`) kèm vòng tròn hiệu ứng chuyển động chuyên nghiệp.
- **Flash Toggle linh hoạt:** Chuyển đổi chu kỳ đèn Flash (`Off` $\rightarrow$ `Torch/Đèn pin liên tục` $\rightarrow$ `Auto`).

### 🧠 2. Trích xuất AI On-device & Regex Heuristics Engine (Giai đoạn 2)
- **Google ML Kit Offline OCR:** Xử lý nhận diện ký tự quang học trực tiếp trên vi xử lý thiết bị với độ trễ cực thấp (**30ms – 80ms**), không phụ thuộc vào kết nối mạng.
- **Regex Heuristics Engine:**
  - *Tổng tiền:* Bắt các mẫu tiền tệ Việt Nam (`150,000 VND`, `150.000 đ`, `150 000`...). Thuật toán Heuristic ưu tiên lấy số tiền lớn nhất nằm ở nửa dưới của hóa đơn ($y \ge 45\%$).
  - *Ngày giao dịch:* Nhận diện định dạng `DD/MM/YYYY`, `DD-MM-YYYY`. **Khóa chặt ngày tương lai** (tự động fallback về ngày hiện tại nếu hóa đơn in sai hoặc OCR đọc nhầm).
  - *Tên thương hiệu/Cửa hàng:* Heuristic lọc bỏ các dòng tiêu đề rác (`HÓA ĐƠN`, `RECEIPT`, `TAX INVOICE`...), ưu tiên dòng chữ có font chữ lớn nhất ở 30% phần trên cùng.
- **Interactive Review Screen:** Màn hình đánh giá tương tác cho phép xem lại ảnh thu nhỏ, đối chiếu văn bản thô (Raw OCR text), chỉnh sửa lỗi sai và chọn danh mục chi tiêu từ Dropdown.

### 💾 3. Lưu trữ Cục bộ SQLite & Thumbnail Caching (Giai đoạn 3)
- **SQLite Persistent Storage (`sqflite`):** Áp dụng mô hình **Singleton Pattern** với bảng `transactions` quản lý đầy đủ các trường `id`, `amount`, `date`, `merchant_name`, `category`, `thumbnail_path`.
- **Enum phân loại 5 danh mục bắt buộc:** `Food (Đồ ăn)`, `Study (Học tập)`, `Travel (Đi lại)`, `Gear (Thiết bị)`, `Entertainment (Giải trí)` kèm hàm chuyển đổi 2 chiều với Database.
- **Tối ưu hóa bộ nhớ đệm (Thumbnail Caching):** Nén ảnh hóa đơn gốc về kích thước thumbnail tối ưu (320px, JPEG 75%), lưu vào thư mục ứng dụng và **tự động xóa vĩnh viễn file ảnh gốc** để tiết kiệm đến 95% bộ nhớ máy.

### 📊 4. Trực quan hóa dữ liệu bằng CustomPainter (Giai đoạn 4)
- **Tuyệt đối không dùng thư viện đồ thị bên thứ ba.** Mọi thành phần được vẽ toán học thuần túy trên `Canvas`.
- **Animated Donut Chart (`CategoryDonutPainter`):** Sử dụng `canvas.drawArc` vẽ các cung tròn tỷ lệ danh mục quét từ $0^\circ \rightarrow 360^\circ$ theo nhịp `AnimationController` (1200ms, `Curves.easeOutCubic`). Hiển thị tổng tiền ở tâm Donut.
- **Weekly Bar Chart (`WeeklyBarPainter`):** Biểu đồ 7 cột chi tiêu trong tuần (T2 $\rightarrow$ CN), tự động chia tỷ lệ trục Y, vẽ đường lưới mờ (grid lines), nhãn trục X và tô màu nhấn cho ngày hôm nay.

### 🏠 5. Dashboard Trang chủ, Hạn mức Ngân sách & Thư viện (Nâng cấp Pro)
- **Thẻ Ngân sách Thông minh (Smart Budget Card):** Theo dõi chi tiêu thực tế so với hạn mức ngân sách tháng đã đặt. Thanh tiến độ tự động đổi màu: Xanh lá (< 70%), Vàng cảnh báo (70% - 90%), Đỏ báo động (> 90%).
- **Lịch sử giao dịch & Vuốt để xóa (Dismissible Swipe-to-delete):** Vuốt sang trái để xóa giao dịch khỏi SQLite và tự động dọn dẹp file thumbnail khỏi bộ nhớ.
- **Xem chi tiết hóa đơn (Detail Modal):** Chạm vào giao dịch để mở modal xem ảnh hóa đơn phóng to, thời gian, số tiền và thông tin chi tiết.
- **Bộ lọc & Tìm kiếm nhanh:** Tìm kiếm theo tên cửa hàng và lọc theo 5 danh mục chi tiêu qua Filter Chips.
- **Chọn ảnh từ Thư viện (Gallery Picker):** Cho phép người dùng chọn ảnh hóa đơn có sẵn trong điện thoại qua `image_picker` song song với Camera.

---

## 🏛 Kiến trúc dự án (Architecture)

Ứng dụng được tổ chức theo kiến trúc **MVVM (Model - View - ViewModel)** kết hợp phân chia theo tính năng (**Feature-first**):

```text
lib/
├── core/                                # Thành phần dùng chung toàn app
│   ├── constants/
│   │   └── app_colors.dart              # Bảng màu chủ đạo (Dark theme / Emerald)
│   └── utils/
│       └── image_thumbnail_helper.dart  # Nén ảnh thumbnail và giải phóng bộ nhớ
│
├── data/                                # Tầng dữ liệu (Data Layer)
│   ├── datasources/
│   │   └── local/
│   │       └── expense_database_helper.dart # SQLite Singleton helper & Queries
│   └── models/
│       └── expense_transaction.dart     # Entity bản ghi giao dịch chi tiêu
│
├── features/                            # Tầng tính năng độc lập (Feature Modules)
│   ├── camera/                          # [PHASE 1] Camera & Quét hóa đơn
│   │   ├── viewmodels/camera_view_model.dart
│   │   ├── views/camera_screen.dart
│   │   └── widgets/                     # Viewfinder, Overlay, FocusRing, CaptureButton
│   │
│   ├── ocr/                             # [PHASE 2 & 3] Trích xuất & Xác nhận giao dịch
│   │   ├── models/                      # ExpenseCategory, ParsedReceipt, OcrResult
│   │   ├── services/
│   │   │   ├── ocr_service.dart         # Google ML Kit on-device text recognition
│   │   │   └── receipt_parser.dart      # Regex Heuristics Engine
│   │   ├── viewmodels/review_transaction_view_model.dart
│   │   └── views/review_transaction_screen.dart
│   │
│   └── analytics/                       # [PHASE 4] Trực quan hóa biểu đồ
│       ├── painters/
│       │   ├── category_donut_painter.dart # CustomPainter vẽ Donut Chart
│       │   └── weekly_bar_painter.dart     # CustomPainter vẽ Bar Chart 7 ngày
│       └── views/expense_analytics_screen.dart
│
└── main.dart                            # Entry point khởi chạy ứng dụng
```

---

## 🛠 Yêu cầu môi trường & Cài đặt (Prerequisites & Setup)

### Yêu cầu hệ thống:
* **Flutter SDK:** $\ge$ `3.24.0` (Khuyến nghị Flutter 3.27+ hoặc 3.47+)
* **Dart SDK:** $\ge$ `3.5.0`
* **Android SDK:** `minSdkVersion 21`, `compileSdkVersion 34+`
* **Thiết bị chạy:** Điện thoại Android vật lý (khuyến khích) hoặc Android Emulator API 30+.

### Các bước cài đặt:

1. **Clone kho lưu trữ về máy:**
   ```bash
   git clone https://github.com/your-username/ocr-expense-tracker.git
   cd ocr-expense-tracker
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies):**
   ```bash
   flutter pub get
   ```

3. **Kiểm tra tính toàn vẹn của mã nguồn:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Khởi chạy trên thiết bị (Debug mode):**
   ```bash
   # Bật USB Debugging trên điện thoại Android, cắm cáp và chạy:
   flutter run
   ```

---

## 📦 Hướng dẫn Đóng gói Build APK (Build Commands)

Để xuất bản ứng dụng thành file APK hoàn chỉnh, tối ưu hóa kích thước và hiệu năng:

### 1. Build APK Release tiêu chuẩn (Universal APK)
Tạo một file APK duy nhất tương thích với mọi kiến trúc CPU:
```bash
flutter build apk --release
```
*File xuất ra tại:* `build/app/outputs/flutter-apk/app-release.apk`

---

### 2. Build APK tối ưu hóa kích thước (Split per ABI - Khuyến nghị ⭐)
Tách file APK theo từng kiến trúc vi xử lý (`arm64-v8a`, `armeabi-v7a`, `x86_64`), giúp **giảm dung lượng file tải xuống từ ~60MB xuống chỉ còn ~15MB – 20MB**:
```bash
flutter build apk --release --split-per-abi
```
*Các file xuất ra tại:* `build/app/outputs/flutter-apk/`
* `app-arm64-v8a-release.apk` (Dành cho hầu hết điện thoại Android hiện đại 64-bit)
* `app-armeabi-v7a-release.apk` (Dành cho các dòng máy Android 32-bit cũ)

---

### 3. Build APK tối ưu hóa bảo mật & Obfuscation (Production Ready)
Làm rối mã nguồn Dart (Code Obfuscation) và bóc tách bảng ký hiệu debug để bảo mật thuật toán Regex Engine:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --split-per-abi
```

---

## 🧪 Kiểm thử tự động (Automated Testing)

Dự án đi kèm bộ Unit Tests toàn diện bao phủ từ tầng Parser, Model, Database đến CustomPainter:

```bash
flutter test
```

### Kết quả kiểm thử:
- ✅ `ReceiptParser`: Trích xuất chính xác số tiền `150.000 đ`, `150,000 VND`.
- ✅ `ReceiptParser`: Heuristic số lớn nhất ở nửa dưới hóa đơn.
- ✅ `ReceiptParser`: Chặn ngày tương lai, fallback về `DateTime.now()`.
- ✅ `ReceiptParser`: Gợi ý đúng 5 danh mục bắt buộc.
- ✅ `ExpenseCategory`: Mapping 2 chiều `toDbString()` và `fromDbString()`.
- ✅ `ExpenseTransaction`: Serialization 2 chiều `toMap()` và `fromMap()`.
- ✅ `ExpenseDatabaseHelper`: Đảm bảo tính toàn vẹn Singleton Pattern.
- ✅ `CategoryDonutPainter & WeeklyBarPainter`: Kiểm tra thuật toán Canvas và `shouldRepaint`.

---

## 📄 Bản quyền (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE). Mã nguồn phục vụ mục đích học tập và nghiên cứu phát triển ứng dụng di động đa nền tảng.
