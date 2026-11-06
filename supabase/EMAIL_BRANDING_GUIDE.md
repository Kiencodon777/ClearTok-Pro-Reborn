# Hướng dẫn Đổi Tên Bot Gửi Mã từ "Supabase Auth" sang "LapinTokk"

Mặc định Supabase sử dụng dịch vụ gửi mail miễn phí (`noreply@mail.app.supabase.io`) với tên người gửi `Supabase Auth` và nội dung tiếng Anh có dòng chữ `powered by Supabase`. Anh có 2 cách xử lý cực nhanh trên **Supabase Dashboard** (`https://supabase.com/dashboard/project/jsxxxbspjmpbaomotgcj`):

---

## Cách 1: Đổi giao diện Email sang thương hiệu LapinTokk (1 phút)

1. Mở [Supabase Email Templates](https://supabase.com/dashboard/project/jsxxxbspjmpbaomotgcj/auth/templates).
2. Chọn tab **Confirm signup**:
   - **Subject heading (Tiêu đề thư):**
     ```text
     [LapinTokk] Xác nhận tài khoản ứng dụng của bạn
     ```
   - **Message body (Source HTML):** Copy toàn bộ nội dung file [`supabase/email_templates/confirm_signup.html`](email_templates/confirm_signup.html) dán đè vào ô Source rồi bấm **Save**.
3. Chọn tab **Reset password**:
   - **Subject heading:**
     ```text
     [LapinTokk] Đặt lại mật khẩu tài khoản của bạn
     ```
   - **Message body:** Copy toàn bộ nội dung file [`supabase/email_templates/recovery.html`](email_templates/recovery.html) dán vào rồi bấm **Save**.

---

## Cách 2: Đổi tên Người gửi (Sender Name) thành "LapinTokk" qua Gmail SMTP

Để tên hiển thị trong hộp thư đến là **LapinTokk** (thay vì `Supabase Auth`) và không bị giới hạn 2 email/giờ:

1. Mở [Supabase Auth SMTP Settings](https://supabase.com/dashboard/project/jsxxxbspjmpbaomotgcj/settings/auth).
2. Bật **Enable Custom SMTP**:
   - **Sender email:** Email của anh (ví dụ `lapintokk@gmail.com`)
   - **Sender name:** `LapinTokk`
   - **Host:** `smtp.gmail.com`
   - **Port number:** `465`
   - **Username:** Email Gmail của anh
   - **Password:** Mật khẩu ứng dụng 16 ký tự của Gmail (tạo tại `myaccount.google.com/apppasswords`).
3. Bấm **Save**.

---

## Cách 3 (Tùy chọn): Tắt bước xác nhận Email để User Đăng ký xong vào thẳng luôn

Nếu anh muốn người dùng đăng ký tài khoản trên app xong là **đăng nhập tự động luôn không cần mở mail bấm link**:
1. Mở [Supabase Email Provider](https://supabase.com/dashboard/project/jsxxxbspjmpbaomotgcj/auth/providers).
2. Bấm vào **Email** -> Tắt nút **Confirm email** -> Bấm **Save**.
