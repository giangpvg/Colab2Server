#!/usr/bin/env bash
# ==============================================================================
# Script: setup_runner.sh
# Purpose: Cài đặt và kích hoạt GitHub Actions Self-Hosted Runner trên Google Colab
# Tham số:
#   $1: GitHub Repo URL (ví dụ: https://github.com/username/repository)
#   $2: GitHub Runner Registration Token (hoặc GitHub PAT để tự lấy token)
#   $3 (tùy chọn): Tên Runner (mặc định: colab-runner)
#   $4 (tùy chọn): Labels bổ sung (mặc định: colab,gpu,cuda)
#   $5 (tùy chọn): Thư mục cài đặt runner (mặc định: /opt/actions-runner)
# ==============================================================================
set -euo pipefail

REPO_URL="${1:-}"
AUTH_TOKEN="${2:-}"
RUNNER_NAME="${3:-colab-runner-$(hostname)}"
EXTRA_LABELS="${4:-colab,gpu,cuda}"
RUNNER_DIR="${5:-/opt/actions-runner}"

if [ -z "${REPO_URL}" ] || [ -z "${AUTH_TOKEN}" ]; then
    echo "======================================================================"
    echo "LỖI: Thiếu tham số!"
    echo "Sử dụng: $0 <REPO_URL> <TOKEN> [RUNNER_NAME] [LABELS] [RUNNER_DIR]"
    echo "Ví dụ:   $0 https://github.com/myuser/myrepo AABBCCDDEE123"
    echo "======================================================================"
    exit 1
fi

echo "=========================================="
echo ">>> [5/5] Đang thiết lập GitHub Actions Runner..."
echo ">>> Repo:   ${REPO_URL}"
echo ">>> Name:   ${RUNNER_NAME}"
echo ">>> Labels: self-hosted,linux,x64,${EXTRA_LABELS}"
echo "=========================================="

export RUNNER_ALLOW_RUNASROOT=1

# 1. Chuẩn bị thư mục runner
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# 2. Tải bản mới nhất của GitHub Actions Runner nếu chưa có
RUNNER_VERSION="2.322.0" # Hoặc tự động lấy phiên bản mới nhất
if [ ! -f "config.sh" ]; then
    echo ">>> Đang tải GitHub Actions Runner v${RUNNER_VERSION}..."
    curl -o actions-runner-linux-x64.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    tar xzf ./actions-runner-linux-x64.tar.gz
    rm -f actions-runner-linux-x64.tar.gz

    # Cài đặt các thư viện phụ thuộc của runner
    echo ">>> Cài đặt dependency của runner..."
    ./bin/installdependencies.sh || true
fi

# 3. Xử lý token (Hỗ trợ Personal Access Token PAT để tự xin Registration Token)
REG_TOKEN="${AUTH_TOKEN}"
if [[ "${AUTH_TOKEN}" == ghp_* ]] || [[ "${AUTH_TOKEN}" == github_pat_* ]]; then
    echo ">>> Phát hiện GitHub Personal Access Token. Đang lấy Runner Registration Token qua API..."
    # Tách owner/repo từ URL
    REPO_PATH=$(echo "${REPO_URL}" | sed -E 's|https?://github.com/||; s|\.git$||')
    API_RESPONSE=$(curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        "https://api.github.com/repos/${REPO_PATH}/actions/runners/registration-token")
    
    PARSED_TOKEN=$(echo "${API_RESPONSE}" | jq -r '.token // empty')
    if [ -n "${PARSED_TOKEN}" ]; then
        REG_TOKEN="${PARSED_TOKEN}"
        echo ">>> Lấy Runner Registration Token thành công!"
    else
        echo ">>> CẢNH BÁO: Không lấy được token qua PAT, dùng chuỗi token nhập vào trực tiếp."
    fi
fi

# 4. Gỡ bỏ đăng ký cũ nếu có file .runner tồn tại
if [ -f ".runner" ]; then
    echo ">>> Đã tìm thấy cấu hình runner trước đó. Tiến hành dọn dẹp hoặc chạy trực tiếp..."
fi

# 5. Cấu hình Runner
echo ">>> Cấu hình runner với GitHub Actions..."
./config.sh \
    --url "${REPO_URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "self-hosted,colab,${EXTRA_LABELS}" \
    --unattended \
    --replace

echo "=========================================="
echo ">>> Runner đã đăng ký thành công với GitHub!"
echo ">>> Đang khởi chạy Runner ở chế độ background..."
echo "=========================================="

mkdir -p /var/log/actions-runner
nohup ./run.sh > /var/log/actions-runner/runner.log 2>&1 &
sleep 3

if pgrep -f "Runner.Listener" > /dev/null; then
    echo ">>> Runner đang HOẠT ĐỘNG (Listening for Jobs)!"
    echo ">>> Kiểm tra log tại: /var/log/actions-runner/runner.log"
else
    echo ">>> Có lỗi khi chạy runner. Kiểm tra log:"
    cat /var/log/actions-runner/runner.log || true
fi
