# 📱 FlowCare AI - Smart Obstetrics & Gynecology Mobile App

> **Ứng dụng di động Bệnh Viện Phụ Sản Thông Minh FlowCare AI**  
> Giải pháp điều phối luồng khám thông minh, đặt lịch hẹn trực tuyến, theo dõi lộ trình khám thời gian thực và quản lý hồ sơ sức khỏe thai sản toàn diện cho Mẹ & Bé.

---

## 🌟 Tính Năng Nổi Bật

* **📅 Đặt Lịch Khám Trực Tuyến (Online Booking):**
  * Đặt hẹn khám chuyên khoa Sản, Phụ khoa, Cận lâm sàng (Siêu âm 2D/4D, Xét nghiệm).
  * Khóa khung giờ thực tế, chống trùng lịch, chọn ca khám linh hoạt (có ca ngoài giờ).
* **🗺️ Lộ Trình Khám Thời Gian Thực (Real-Time AI Route Tracker):**
  * Tự động đồng bộ với hệ thống Tiếp đón & Điều phối AI của bệnh viện sau khi check-in.
  * Hiển thị số thứ tự (STT), phòng khám cụ thể (Ví dụ: `Phòng khám Sản VIP 1 - P.301`).
  * Đo đếm thời gian chờ ước tính (ETA) và tiến trình khám từng bước.
* **🎫 Tra Cứu Phiếu Khám Nhanh (Quick Ticket Lookup):**
  * Tra cứu lượt khám, số thứ tự và mã xác nhận theo Số điện thoại.
  * Hỗ trợ chuyển đổi nhanh tài khoản thử nghiệm trên cùng thiết bị.
* **🤰 Theo Dõi Thai Kỳ & Sức Khỏe Mẹ Bé (Pregnancy Tracker):**
  * Tính toán tuần thai, ngày dự sinh (EDD), mốc khám thai quan trọng.
  * Hồ sơ tiền sử sản khoa chuẩn quốc tế PARA (G P A L).
* **📑 Hồ Sơ Bệnh Án Điện Tử (EMR Profile):**
  * Quản lý thông tin định danh, nhóm máu (Rh), tiền sử dị ứng và chu kỳ phụ khoa.

---

## 🛠️ Công Nghệ Sử Dụng

* **Framework:** [Flutter](https://flutter.dev/) (Dart SDK >= 3.0)
* **Quản lý State:** [Provider](https://pub.dev/packages/provider)
* **Kiến trúc:** Clean Layered Architecture (Models, Services, Providers, Screens, Widgets)
* **Giao diện:** Material 3, Custom Healthcare Medical Design System (Vibrant Colors, Responsive, Dark/Light friendly)
* **Network & API:** RESTful API Client (HTTP, JSON Serialization, Timeout & Error Interceptor)
* **Đồng bộ:** Tương thích trực tiếp với Backend .NET 10 WebAPI (`FlowCare-AI_BE`)

---

## 📂 Cấu Trúc Dự Án

```text
flowcare_mobile/
├── android/                 # Cấu hình dự án Android & Gradle
├── windows/                 # Cấu hình desktop Windows
├── lib/
│   ├── core/
│   │   ├── constants/       # API endpoints, app constants
│   │   ├── network/         # ApiClient, Exception handling, BaseResponse
│   │   └── theme/           # Palette màu y tế, Typography, Theme system
│   ├── models/              # Data models (Patient, Encounter, Appointment, Ticket, Milestone)
│   ├── providers/           # State Management (Home, Booking, History, Profile)
│   ├── screens/
│   │   ├── home/            # Trang chủ, Dashboard thai kỳ, Banner tra cứu
│   │   ├── booking/         # Màn hình đặt lịch khám online
│   │   ├── route/           # Lộ trình khám & Tiến trình thời gian thực
│   │   ├── history/         # Lịch sử phiếu khám & kết quả EMR
│   │   ├── profile/         # Hồ sơ sức khỏe cá nhân & thai sản
│   │   └── main_shell_screen.dart # Thanh điều hướng 5 tab
│   ├── services/            # API Services (Patient, Appointment, Encounter, Queue, Session)
│   └── widgets/             # Reusable UI components (Loading, Error, Empty states)
├── pubspec.yaml             # Dependencies & Assets
└── README.md
```

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### 1. Yêu cầu môi trường:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (phiên bản 3.24+ khuyến nghị)
* Android Studio / VS Code với extension Flutter & Dart
* Máy ảo Android Emulator (API 33+) hoặc thiết bị thật

### 2. Cấu hình Backend:
Đảm bảo Backend `FlowCare-AI_BE` đang chạy trên máy chủ:
* **Android Emulator:** Ứng dụng trỏ mặc định về `http://10.0.2.2:5062/api/v1`
* **Thiết bị thật (Cùng WiFi):** Cập nhật IP máy tính trong `lib/core/constants/api_endpoints.dart`:
  ```dart
  static const String defaultBaseUrl = 'http://<IP_MAY_TINH>:5062/api/v1';
  ```

### 3. Khởi chạy ứng dụng:
```bash
# 1. Di chuyển vào thư mục dự án
cd flowcare_mobile

# 2. Tải các thư viện phụ thuộc
flutter pub get

# 3. Kiểm tra thiết bị & biên dịch
flutter analyze

# 4. Chạy ứng dụng trên Emulator / Thiết bị
flutter run
```

---

## 👥 Nhóm Phát Triển - Dự Án FlowCare AI
* **Hệ thống Quản lý Bệnh Viện Thông Minh & Tiếp Đón Thai Sản 1-Chạm**
* GitHub Organization: [NguyenQuocBaoILY](https://github.com/NguyenQuocBaoILY)
