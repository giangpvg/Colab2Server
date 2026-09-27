#!/usr/bin/env bash
# ==============================================================================
# Script: setup_ssh.sh
# Purpose: Cài đặt và cấu hình OpenSSH Server trên Colab
# Tham số:
#   $1 (tùy chọn): Mật khẩu cho user root (mặc định: colab123456)
#   $2 (tùy chọn): SSH Public Key để thêm vào authorized_keys
# ==============================================================================
set -euo pipefail

SSH_PASSWORD="${1:-colab123456}"
SSH_PUBLIC_KEY="${2:-}"

echo "=========================================="
echo ">>> [3/5] Đang thiết lập OpenSSH Server..."
echo "=========================================="

# Cài đặt OpenSSH Server
apt-get update -qq
apt-get install -y -qq openssh-server

# Đặt mật khẩu cho root
echo "root:${SSH_PASSWORD}" | chpasswd

# Cấu hình sshd
mkdir -p /var/run/sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Nếu có public key truyền vào
if [ -n "${SSH_PUBLIC_KEY}" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo ">>> Đã thêm SSH Public Key vào /root/.ssh/authorized_keys"
fi

# Khởi chạy SSH service
service ssh restart

echo ">>> OpenSSH Server đã sẵn sàng lắng nghe tại cổng 22!"
