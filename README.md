# vnstock_insider_kickstart
 Hướng dẫn cài đặt và tài liệu sử dụng dành riêng cho thành viên tài trợ dự án Vnstock

# Hướng dẫn cài đặt

> Hiện tại, bạn có thể cài đặt các gói phần mềm dành riêng cho thành viên thông qua file cài đặt tiện lợi và đây là cách cài đặt chính thức được hướng dẫn. Chi tiết cách cài đặt trên từng nền tảng máy tính và dịch vụ.

**Đối với Github Codespace**

1. Mở Notebook với nút <a href="https://codespaces.new/vnstock-hq/vnstock_insider_guide" target="_blank" style="display:inline-block; vertical-align:middle;"><img src="https://img.shields.io/badge/Open%20in-GitHub%20Codespaces-blue?logo=github" alt="Open in GitHub Codespaces" style="height:20px; vertical-align:middle;"></a>

2. Tạo Codespace mới để thử nghiệm Notebook Minh hoạ

![](http://vnstocks.com/images/vnstock-guide-github-codespace.png)

3. Mở Terminal bằng phím tắt Ctrl + ` (phím backtick dưới phím Esc) sau đó nhập các dòng lệnh bên dưới vào

**Đối với Google Colab**

Chạy ô lệnh bên dưới tại Notebook minh hoạ này trên dịch vụ [Google Colab](https://colab.research.google.com/)


```bash
# Tải file về và lưu với tên vnstock-cli-installer.run
wget https://vnstocks.com/files/vnstock-cli-installer.run
# Phân quyền và chạy cài đặt
chmod +x vnstock-cli-installer.run
./vnstock-cli-installer.run
```

**⚡ Lựa chọn nền tảng:**
- **GitHub Codespaces** (Khuyến nghị): Môi trường đầy đủ, không cần cài đặt Python phức tạp và không bị chặn IP từ nguồn VCI.
- **Google Colab**: Miễn phí với hỗ trợ lưu trữ trong Google Drive. Hiện tại đang bị nguồn VCI chặn IP nên một số tính năng không sử dụng được.
