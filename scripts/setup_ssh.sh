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

# Luôn thêm khóa mặc định github-actions-colab-cd để người dùng có thể SSH ngay
mkdir -p /root/.ssh
chmod 700 /root/.ssh
DEFAULT_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBbUu+ooQcNt//5cUzByXynepzkuC02FVphFSEkIDUkH github-actions-colab-cd"
grep -qF "${DEFAULT_KEY}" /root/.ssh/authorized_keys 2>/dev/null || echo "${DEFAULT_KEY}" >> /root/.ssh/authorized_keys

# Nếu có public key bổ sung truyền vào
if [ -n "${SSH_PUBLIC_KEY}" ]; then
    grep -qF "${SSH_PUBLIC_KEY}" /root/.ssh/authorized_keys 2>/dev/null || echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
fi
chmod 600 /root/.ssh/authorized_keys

# Tự động nạp thư viện và lệnh NVIDIA/CUDA cho mọi phiên SSH
echo "/usr/lib64-nvidia" > /etc/ld.so.conf.d/nvidia.conf
ldconfig 2>/dev/null || true
grep -qF "usr/local/cuda/bin" /root/.bashrc 2>/dev/null || echo 'export PATH="/usr/local/cuda/bin:/usr/local/nvidia/bin:$PATH"' >> /root/.bashrc
grep -qF "usr/lib64-nvidia" /root/.bashrc 2>/dev/null || echo 'export LD_LIBRARY_PATH="/usr/lib64-nvidia:/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> /root/.bashrc

# Dọn dẹp cấu hình đè cổng 2222 hoặc 127.0.0.1 của Colab
rm -f /etc/ssh/sshd_config.d/*.conf
sed -i '/ListenAddress/d' /etc/ssh/sshd_config 2>/dev/null || true
sed -i '/Port 2222/d' /etc/ssh/sshd_config 2>/dev/null || true
echo "Port 22" >> /etc/ssh/sshd_config
echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config

ssh-keygen -A 2>/dev/null || true
pkill -f sshd 2>/dev/null || true
/usr/sbin/sshd -p 22 -o "ListenAddress 0.0.0.0" -o "PermitRootLogin yes" -o "PubkeyAuthentication yes"

echo ">>> OpenSSH Server đã sẵn sàng lắng nghe tại 0.0.0.0:22 với đầy đủ driver GPU!"
