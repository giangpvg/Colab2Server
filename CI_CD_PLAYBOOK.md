# 🤖 AI Agent Playbook: Hướng Dẫn Chuẩn Hóa Triển Khai CI/CD & Server

Tài liệu này được thiết kế để các **AI Coding Assistant / Agent** (như Antigravity, Claude, Cursor, Copilot) hoặc DevOps Engineer đọc và thực thi chính xác quy trình thiết lập CI/CD cho bất kỳ dự án phần mềm nào.

---

## 1. Mục Tiêu & Kiến Trúc Hệ Thống

Tất cả các dự án triển khai theo chuẩn này đều hỗ trợ 2 môi trường đích:
1. **Target A - Môi trường Thử nghiệm / Colab Server (Staging & Heavy CI)**:
   - Sử dụng Google Colab làm **Self-Hosted Runner** và **Deployment Server**.
   - Kết nối nội bộ qua mạng riêng ảo **Tailscale Mesh VPN** hoặc **Cloudflare Tunnel**.
   - Tận dụng RAM lớn và GPU miễn phí (NVIDIA Tesla T4).
2. **Target B - Môi trường Thực tế / Production Server (VPS / Cloud)**:
   - Sử dụng máy chủ vật lý / VPS (AWS EC2, DigitalOcean, Hetzner, GCP).
   - Có Public Static IP, Reverse Proxy (Nginx/Traefik) và chứng chỉ SSL Let's Encrypt.

---

## 2. Cấu Trúc Thư Mục Dự Án Bắt Buộc

Khi khởi tạo hoặc chuẩn hóa một dự án, Agent phải bảo đảm cấu trúc file tối thiểu sau:

```text
<PROJECT_ROOT>/
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Pipeline CI: Lint, Test, Build Image
│       └── cd.yml                 # Pipeline CD: Deploy ứng dụng vào Server
├── app/ hoặc src/                 # Mã nguồn chính của ứng dụng
│   └── ...
├── tests/                         # BẮT BUỘC: Thư mục chứa Unit / Integration Tests
│   └── test_*.py (hoặc *.spec.js, *_test.go)
├── Dockerfile                     # Đóng gói ứng dụng dạng container độc lập
├── docker-compose.yml             # Điều phối ứng dụng cùng Database/Redis
├── requirements.txt (hoặc package.json, go.mod)
├── .env.example                   # Khai báo các biến môi trường mẫu (KHÔNG lưu secret)
├── .gitignore                     # Bỏ qua cache, venv, log, secrets
└── README.md
```

---

## 3. Quy Chuẩn Các File Cấu Hình

### 3.1. Quy chuẩn `Dockerfile`
Agent phải tuân thủ các nguyên tắc sau:
- Sử dụng base image nhẹ (ví dụ `python:3.10-slim`, `node:20-alpine`, `golang:1.22-alpine`).
- BẮT BUỘC có lệnh `HEALTHCHECK` trong Dockerfile hoặc docker-compose để CD pipeline kiểm tra tự động.
- Không chạy container dưới quyền root nếu không cần thiết.

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Cài đặt curl để hỗ trợ automated healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Kiểm tra sức khỏe container định kỳ
HEALTHCHECK --interval=20s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### 3.2. Quy chuẩn `docker-compose.yml`
File docker-compose phải hỗ trợ restart policy và cấu hình volume bền vững:

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: app_service
    restart: unless-stopped
    ports:
      - "8000:8000"
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
```

---

### 3.3. Quy chuẩn Pipeline CI (`.github/workflows/ci.yml`)
Quy trình CI phải bao gồm 4 bước bắt buộc: **Checkout -> Setup Môi trường -> Run Tests -> Test Build Docker**.

```yaml
name: CI Pipeline

on:
  push:
    branches: [ "main", "develop" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  test_and_lint:
    name: Run Unit Tests & Build Check
    # Chạy trên Colab Runner nếu có nhãn [self-hosted, colab], hoặc fallback sang ubuntu-latest
    runs-on: [ self-hosted, colab ]

    steps:
      - name: 1. Checkout Code
        uses: actions/checkout@v4

      - name: 2. Thiết lập Môi trường & Dependency
        run: |
          python3 -m pip install --upgrade pip --break-system-packages 2>/dev/null || true
          pip install --break-system-packages -r requirements.txt

      - name: 3. Thực thi Kiểm thử Tự động (Tests)
        run: |
          python3 -m pytest -v tests/

      - name: 4. Kiểm tra Build Docker Container
        run: |
          docker build -t app-service:ci-test .
```

---

### 3.4. Quy chuẩn Pipeline CD (`.github/workflows/cd.yml`)
Hỗ trợ cả 2 chế độ:
- Chế độ 1: Deploy trực tiếp trên Runner (Agent-based).
- Chế độ 2: Deploy qua SSH (Tailscale / VPS IP).

```yaml
name: CD Pipeline - Automated Deployment

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  deploy_app:
    name: Deploy to Target Server
    runs-on: ubuntu-latest

    steps:
      - name: 1. Checkout Code
        uses: actions/checkout@v4

      - name: 2. Kết nối Mạng Riêng Ảo (Tailscale VPN)
        # Bỏ qua bước này nếu dùng Public IP của Server thật
        uses: tailscale/github-action@v2
        with:
          authkey: ${{ secrets.TAILSCALE_AUTHKEY }}

      - name: 3. Nạp SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.COLAB_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: 4. Thực thi Deploy qua SSH
        run: |
          ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@${{ secrets.TARGET_HOST }} << 'EOF'
            set -e
            echo ">>> Đang deploy ứng dụng mới..."
            mkdir -p /root/deploy/my_project
            cd /root/deploy/my_project

            # Kéo mã nguồn mới nhất
            if [ ! -d ".git" ]; then
              git clone https://github.com/${{ github.repository }} .
            else
              git fetch --all && git reset --hard origin/main
            fi

            # Khởi động dịch vụ Docker
            docker-compose down 2>/dev/null || true
            docker-compose up -d --build

            # Automated Health Check
            sleep 6
            curl -f http://localhost:8000/health || exit 1
            echo ">>> TRIỂN KHAI THÀNH CÔNG!"
          EOF
```

---

## 4. Danh Sách GitHub Secrets Bắt Buộc

Trước khi chạy CD, Agent phải kiểm tra và nhắc nhở người dùng cấu hình các Secrets sau tại **Settings > Secrets and variables > Actions**:

| Secret Key | Ý nghĩa | Ví dụ giá trị |
| :--- | :--- | :--- |
| `TARGET_HOST` | Địa chỉ Hostname hoặc IP của Server | `colab-server` hoặc `139.59.100.20` |
| `COLAB_SSH_PRIVATE_KEY` | Private SSH Key để đăng nhập không cần mật khẩu | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `TAILSCALE_AUTHKEY` | Khóa xác thực Tailscale (nếu deploy vào Colab / Staging) | `tskey-auth-k12345...` |

---

## 5. Bảng Xử Lý Lỗi Phổ Biến Cho Agent (Troubleshooting Matrix)

| Hiện tượng lỗi | Nguyên nhân gốc rễ | Hướng xử lý cho Agent |
| :--- | :--- | :--- |
| `pip install: externally-managed-environment` | Ubuntu 24.04 áp dụng PEP 668 chặn cài đè system python. | Thêm cờ `--break-system-packages` vào lệnh `pip install` hoặc kích hoạt Virtualenv. |
| `Cannot connect to the Docker daemon` | Docker daemon chưa chạy do Colab thiếu init script systemd. | Chạy nền `nohup containerd &` rồi chạy `nohup dockerd --storage-driver=vfs --iptables=false &`. |
| `ssh: connect to host ... port 22: Connection refused` | `sshd` chưa chạy, hoặc bị bind nhầm ở `127.0.0.1:2222`. | Chạy `/usr/sbin/sshd -p 22 -o "ListenAddress 0.0.0.0"`. |
| `Healthcheck failed: Connection refused` | Container bị crash ngay khi bật (thiếu biến môi trường hoặc sai port). | Đọc log container bằng `docker logs <container_name>` để phân tích stack trace. |
| `Runs-on [self-hosted, colab] waiting forever` | Runner trên máy Colab đang offline hoặc chưa đăng ký đúng label. | Bật lại cell Runner trên Colab hoặc đổi tạm sang `runs-on: ubuntu-latest`. |

---

## 6. Hướng Dẫn Thực Thi Từng Bước Dành Cho Agent (Agent Step-by-Step Execution)

Khi nhận yêu cầu: *"Hãy triển khai CI/CD cho dự án này"*, Agent phải thực hiện theo đúng trình tự:

1. **Bước 1 (Source Verification)**: Kiểm tra file `tests/` xem có bài test nào chưa. Nếu chưa có, viết unit test tối thiểu cho các endpoint chính.
2. **Bước 2 (Containerization)**: Tạo `Dockerfile` và `docker-compose.yml` có sẵn endpoint `/health`.
3. **Bước 3 (Pipeline Creation)**: Tạo `.github/workflows/ci.yml` và `.github/workflows/cd.yml` theo mẫu ở Mục 3.
4. **Bước 4 (Local Validation)**: Chạy thử `pytest` và `docker build` ở local trước khi commit.
5. **Bước 5 (Secrets & Target Verification)**: Nhắc nhở người dùng thiết lập các GitHub Secrets cần thiết và khởi động Server Colab / VPS.
