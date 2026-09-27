#!/usr/bin/env bash
# ==============================================================================
# Script: setup_tunnel.sh
# Purpose: Thiết lập Tunnel công khai để truy cập SSH / HTTP vào Colab
# Hỗ trợ:
#   1. Cloudflare Quick Tunnel (TryCloudflare - Không cần tài khoản)
#   2. Cloudflare Named Tunnel (Với Cloudflare Tunnel Token cố định domain)
#   3. Tailscale (Mesh VPN - Zero-trust SSH)
# ==============================================================================
set -euo pipefail

MODE="${1:-cloudflare-quick}"  # cloudflare-quick | cloudflare-token | tailscale
PARAM="${2:-}"                 # Token nếu chọn cloudflare-token hoặc authkey nếu chọn tailscale

echo "=========================================="
echo ">>> [4/5] Đang thiết lập Tunnel mạng (Chế độ: ${MODE})..."
echo "=========================================="

case "${MODE}" in
    "cloudflare-quick")
        echo ">>> Cài đặt cloudflared..."
        if ! command -v cloudflared &> /dev/null; then
            curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
            dpkg -i /tmp/cloudflared.deb
            rm -f /tmp/cloudflared.deb
        fi

        echo ">>> Khởi chạy Cloudflare Quick Tunnel cho SSH (Port 22)..."
        mkdir -p /var/log/cloudflared
        nohup cloudflared tunnel --url tcp://localhost:22 > /var/log/cloudflared/tunnel.log 2>&1 &
        sleep 5

        echo "=========================================="
        echo ">>> URL KẾT NỐI CLOUDFLARE TUNNEL (SSH):"
        grep -o 'https://.*trycloudflare.com' /var/log/cloudflared/tunnel.log || true
        echo "Xem chi tiết tại: /var/log/cloudflared/tunnel.log"
        echo "=========================================="
        ;;

    "cloudflare-token")
        if [ -z "${PARAM}" ]; then
            echo "LỖI: Bạn phải cung cấp Cloudflare Tunnel Token khi dùng chế độ cloudflare-token!"
            exit 1
        fi
        echo ">>> Cài đặt cloudflared..."
        if ! command -v cloudflared &> /dev/null; then
            curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
            dpkg -i /tmp/cloudflared.deb
            rm -f /tmp/cloudflared.deb
        fi

        echo ">>> Khởi chạy Cloudflare Tunnel với Token..."
        nohup cloudflared tunnel run --token "${PARAM}" > /var/log/cloudflared/tunnel.log 2>&1 &
        sleep 3
        echo ">>> Cloudflare Tunnel cố định đã hoạt động!"
        ;;

    "tailscale")
        if [ -z "${PARAM}" ]; then
            echo "LỖI: Bạn phải cung cấp Tailscale Auth Key khi dùng chế độ tailscale!"
            exit 1
        fi
        echo ">>> Cài đặt Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        
        echo ">>> Khởi chạy tailscaled service..."
        service tailscaled start || tailscaled --tun=userspace-networking > /var/log/tailscale.log 2>&1 &
        sleep 3

        echo ">>> Đăng nhập Tailscale với Auth Key & bật Tailscale SSH..."
        tailscale up --authkey="${PARAM}" --ssh --hostname="colab-server" --accept-routes
        echo ">>> Kết nối Tailscale thành công! Máy Colab đã gia nhập mạng riêng ảo của bạn."
        tailscale ip -4
        ;;

    *)
        echo "Lựa chọn không hợp lệ. Chọn một trong: cloudflare-quick | cloudflare-token | tailscale"
        exit 1
        ;;
esac
