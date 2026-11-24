# Nhật Ký Lỗi & Bài Học Kinh Nghiệm (Error Log)

| Ngày | Mô tả lỗi | Nguyên nhân | Cách khắc phục & Phòng tránh |
| :--- | :--- | :--- | :--- |
| 2026-11-24 | Bấm vào học phần đã đăng ký ở `StudentHomeScreen` mở ra form thêm mới trống rỗng, phải bấm lại lần nữa trong danh sách mới vào chế độ sửa. | `StudentHomeScreen` gọi `context.push('/registrations')` mà không truyền `ProgramRegistration` qua `extra`, và `CourseRegistrationScreen` chưa nhận `initialRegistration`. | Truyền `extra: r` qua `GoRouter` và xử lý `widget.initialRegistration` trong `initState()` của `CourseRegistrationScreen` để nạp sẵn form sửa ngay lập tức. |
| 2026-11-24 | Giao diện Web bị kéo giãn toàn màn hình (`LoginScreen`, `RegisterScreen`, `ProfileScreen`, `StudentHomeScreen`). | Thiếu `ConstrainedBox(maxWidth: ...)` và dùng `GridView.count` với `childAspectRatio` cố định. | Dùng `ResponsiveContainer` giới hạn `maxWidth` theo từng loại màn hình (440–480px cho Auth, 560px cho Profile, 960px cho Dashboard/Registration) và `SliverGridDelegateWithMaxCrossAxisExtent`. |
| 2026-11-24 | Chỉnh sửa/xóa đăng ký học phần chưa kiểm tra ràng buộc với phòng học (`ck_study_rooms`) và lời mời (`ck_room_invitations`). | Xử lý `ck_program_registrations` độc lập, thiếu kiểm tra cross-module. | Bổ sung `BR-11`, `BR-12` trong `BUSINESS_RULES.md` và `getRegistrationLockStatus()` trong `RegistrationRepository`. |

