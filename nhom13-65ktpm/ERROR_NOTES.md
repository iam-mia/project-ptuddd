# Error Notes — Danh Sách Lỗi Cần Tránh Cho AI Agent

> Khi gặp lỗi trong quá trình code hoặc test, ghi ngắn gọn vào đây để các AI Agent khác tự kiểm tra trước khi commit.

- **[Validation] Thiếu validate từng trường input:** Phải kiểm tra validate đầy đủ mọi trường bắt buộc và định dạng (VD: Mã sinh viên `^\d{10}$`, Email, SĐT, Điểm `0..10`, dung lượng file $\le 5\text{MB}$), không bỏ sót trường nào.
- **[Env / Supabase] `DotEnv` & `Supabase.instance` chưa khởi tạo:** Luôn xử lý fallback `dotenv.loadFromString(envString: '', isOptional: true)` khi thiếu `.env`, và kiểm tra `Supabase.instance` đã được `initialize` trước khi gọi API.
- **[Git] Quên `git fetch` trước khi push:** Luôn chạy `git fetch origin` và `git pull --rebase origin nhom/nhom13-65ktpm` trước khi làm việc và trước khi push.
- **[Widget Test] Lỗi tap/scroll ngoài viewport:** Với form dài hoặc `ListView`, luôn dùng `ensureVisible` hoặc `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)` trước khi `tap` / `expect`.

