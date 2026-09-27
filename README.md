# 🚀 Colab2Server: Biến Google Colab Thành Server Học Tập CI/CD

Bộ công cụ toàn diện giúp tận dụng tài nguyên miễn phí của **Google Colab** (RAM lớn, vCPU, GPU T4/V100) để thực hành toàn bộ quy trình **CI/CD (Continuous Integration & Continuous Deployment)**.

---

## 📌 Kiến Trúc Hệ Thống (Architecture)

Dự án triển khai đồng thời **2 mô hình CI/CD**:

```mermaid
flowchart TB
    subgraph GitHub["GitHub Platform"]
        Repo["Git Repository & Codebase"]
        GHA["GitHub Actions Engine"]
        WorkflowCI["01_ci_colab_runner.yml"]
        WorkflowCD["02_cd_colab_deploy.yml"]
    end

    subgraph ColabServer["Google Colab Runtime (Ubuntu + Docker)"]
        direction TB
        subgraph Package1["Gói 1: CI Runner (Outbound Long-Polling)"]
            Runner["GitHub Actions Self-Hosted Runner"]
            GPU["NVIDIA GPU / CUDA / vCPU"]
            Pytest["Pytest & Build Engine"]
        end

        subgraph Package2["Gói 2: CD Target Server (Inbound Access)"]
            SSHD["OpenSSH Server (Port 22)"]
            Dockerd["Docker Daemon & Compose"]
            LiveApp["Container: colab_demo_api (Port 8000)"]
        end

        KeepAlive["Keep-Alive & Resource Monitor"]
    end

    subgraph TunnelNetwork["Mạng & Kênh Truy Cập"]
        CFTunnel["Cloudflare Tunnel (trycloudflare.com)"]
        TailscaleNet["Tailscale Mesh VPN (Zero-Trust)"]
    end

    %% CI Flow
    Repo -->|Push Code| GHA
    GHA -->|Trigger CI Job| WorkflowCI
    Runner -->|1. Polling lấy Job (Không cần mở Port)| GHA
    Runner -->|2. Chạy Build / Test / GPU Task| Pytest

    %% CD Flow
    GHA -->|Trigger CD Job| WorkflowCD
    WorkflowCD -->|SSH qua Tunnel| TunnelNetwork
    TunnelNetwork -->|Inbound SSH| SSHD
    SSHD -->|Deploy Docker Container| Dockerd
    Dockerd -->|Chạy ứng dụng| LiveApp
```

---

## 📁 Cấu Trúc Thư Mục

```text
Colab2Server/
├── .github/
│   └── workflows/
│       ├── 01_ci_colab_runner.yml     # Pipeline CI: Chạy test & build trên Colab Runner
│       └── 02_cd_colab_deploy.yml     # Pipeline CD: SSH deploy app vào Colab bằng Docker
├── notebooks/
│   └── colab_server.ipynb             # Notebook 1-Click Bootstrap chạy trên Google Colab
├── scripts/
│   ├── setup_system.sh                # Cài đặt gói hệ thống và thư viện cơ bản
│   ├── setup_docker.sh                # Cài đặt & khởi động Docker daemon trên Colab
│   ├── setup_ssh.sh                   # Cài đặt OpenSSH server, mật khẩu và SSH keys
│   ├── setup_tunnel.sh                # Thiết lập Cloudflare Tunnel / Tailscale SSH
│   ├── setup_runner.sh                # Cài đặt và đăng ký GitHub Actions Runner
│   └── keep_alive.py                  # Giữ phiên & hiển thị bảng theo dõi tài nguyên
├── sample_app/                        # Ứng dụng mẫu FastAPI để kiểm thử CI/CD
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                    # API có endpoint healthcheck, system info, GPU info
│   ├── tests/
│   │   ├── __init__.py
│   │   └── test_main.py               # Unit tests cho pytest
│   ├── Dockerfile                     # Dockerfile đóng gói ứng dụng
│   ├── docker-compose.yml             # Cấu hình triển khai container
│   ├── pytest.ini                     # Cấu hình pytest
│   └── requirements.txt               # Thư viện phụ thuộc
└── README.md
```

---

## 🛠️ Hướng Dẫn Thực Hành Chi Tiết

### 1. Chuẩn Bị Thông Tin Trước Khi Chạy

#### A. Lấy Token GitHub Actions Runner (Cho Gói CI)
1. Truy cập vào GitHub Repository của bạn.
2. Vào **Settings** > **Actions** > **Runners**.
3. Bấm **New self-hosted runner**, chọn **Linux** / **x64**.
4. Bạn sẽ thấy một token tại lệnh cấu hình dạng:
   ```bash
   ./config.sh --url https://github.com/OWNER/REPO --token AABBCCDDEE12345
   ```
   👉 Lưu lại chuỗi token này (ví dụ: `AABBCCDDEE12345`).

#### B. Chọn Phương Thức Kết Nối Cho Gói CD (Deploy Server)
Bạn có thể chọn 1 trong 2 cách:
- **Cách 1: Tailscale (Khuyên dùng nhất - Nhanh, bảo mật)**
  - Đăng ký tài khoản miễn phí tại [tailscale.com](https://tailscale.com/).
  - Vào **Settings** > **Keys** > **Generate auth key** (Bật *Reusable*).
  - Máy tính hoặc GitHub Actions runner cùng tham gia Tailnet là có thể SSH trực tiếp vào Colab không cần mở bất kỳ port nào.
- **Cách 2: Cloudflare Quick Tunnel (Tiện lợi, không cần tài khoản)**
  - Script sẽ tự động tạo URL dạng `https://xxxx.trycloudflare.com` và tunnel TCP cho SSH.

---

### 2. Khởi Chạy Server Trên Google Colab

1. **Mở Google Colab**:
   - Tải file [notebooks/colab_server.ipynb](file:///home/giangpv102/Tool/Colab2Server/notebooks/colab_server.ipynb) lên Google Colab hoặc kết nối trực tiếp với GitHub repo.
   - Chọn loại phần cứng: **Runtime** > **Change runtime type** > Chọn **T4 GPU** (hoặc CPU nếu chỉ cần test nhẹ).

2. **Chạy các Cell**:
   - **Cell 1**: Kích hoạt JavaScript Keep-alive chống ngắt kết nối khi chuyển tab.
   - **Cell 3**: Clone repo `Colab2Server` về Colab.
   - **Cell 4 (Form Cấu Hình)**:
     - `ENABLE_RUNNER`: Chọn `True` nếu muốn chạy CI Runner.
     - `GITHUB_REPO_URL`: Nhập link GitHub repo của bạn.
     - `RUNNER_TOKEN`: Dán mã token lấy ở Bước 1.A.
     - `ENABLE_DOCKER` & `ENABLE_SSH`: Chọn `True` để làm CD Server.
     - `TUNNEL_MODE`: Chọn `cloudflare-quick` hoặc `tailscale`.
   - **Cell 5**: Nhấn chạy, script sẽ tự động cài đặt hệ thống, Docker, SSH, Tunnel và Runner trong vòng 1–2 phút.
   - **Cell 6**: Bật dashboard theo dõi tài nguyên (CPU, RAM, GPU) và giữ phiên làm việc.

---

### 3. Kiểm Thử Gói 1: CI Pipeline Với GitHub Actions

1. Sau khi chạy Cell 5, kiểm tra trang **Settings** > **Actions** > **Runners** trên GitHub. Bạn sẽ thấy một runner mới với trạng thái **Idle** (màu xanh lá) và các nhãn: `self-hosted`, `colab`, `gpu`.
2. Tạo một commit thay đổi code (hoặc vào tab **Actions** trên GitHub, chọn workflow **CI - Chạy trên Colab Self-Hosted Runner** và bấm **Run workflow**).
3. GitHub Actions sẽ đẩy Job về máy Colab của bạn:
   - Tải code.
   - Kiểm tra GPU (`nvidia-smi`).
   - Cài đặt thư viện và chạy `pytest`.
   - Đóng gói Docker image trực tiếp trên Colab.

---

### 4. Kiểm Thử Gói 2: CD Pipeline (Deploy Ứng Dụng Lên Colab)

1. Cấu hình **GitHub Secrets** trong Repository (**Settings** > **Secrets and variables** > **Actions**):
   - Nếu dùng **Tailscale**:
     - `TAILSCALE_AUTHKEY`: Khóa Tailscale Auth Key.
     - `COLAB_SSH_PRIVATE_KEY`: Private key tương ứng với Public key bạn đã điền lúc tạo SSH.
   - Nếu dùng **Cloudflare Tunnel**:
     - `CF_SSH_HOSTNAME`: Domain SSH sinh ra từ Cloudflare.
     - `COLAB_SSH_PRIVATE_KEY`: Private SSH Key.
2. Chạy workflow **CD - Triển khai ứng dụng lên Colab Staging Server** từ tab **Actions**.
3. Pipeline sẽ tự động:
   - SSH vào Colab thông qua kênh mã hóa an toàn.
   - Kéo mã nguồn mới nhất.
   - Chạy lệnh `docker-compose up -d --build`.
   - Gửi yêu cầu kiểm tra endpoint `http://localhost:8000/health`.

---

## ⚡ Các Điểm Cần Lưu Ý Khi Dùng Colab Làm Server

1. **Giới hạn thời gian (Ephemeral Runtime)**:
   - Tài khoản Colab miễn phí có thời gian chạy tối đa khoảng **12 tiếng liên tục**, hoặc ngắt sớm hơn nếu rớt mạng lâu.
   - *Giải pháp*: File notebook đã được tối ưu dạng **1-Click Run**. Khi Colab bị reset, chỉ cần mở lại notebook và bấm **Run All** là toàn bộ server được tái thiết lập trong 60 giây.
2. **Quyền Root trong Docker**:
   - Môi trường Colab mặc định chạy dưới quyền `root`. Do đó GitHub Runner được cấu hình chạy kèm cờ `RUNNER_ALLOW_RUNASROOT=1`.
3. **Quy định sử dụng của Google Colab**:
   - Chỉ sử dụng để học tập, thử nghiệm CI/CD, chạy test, build container hoặc huấn luyện mô hình. Tránh chạy đào coin (crypto mining) hoặc các dịch vụ vi phạm chính sách của Google.
