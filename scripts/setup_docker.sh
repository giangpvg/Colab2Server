#!/usr/bin/env bash
# ==============================================================================
# Script: setup_docker.sh
# Purpose: Cài đặt và kích hoạt Docker daemon bên trong môi trường Colab
# ==============================================================================
set -euo pipefail

echo "=========================================="
echo ">>> [2/5] Đang thiết lập Docker Engine..."
echo "=========================================="

# 1. Kiểm tra xem docker đã cài chưa
if ! command -v docker &> /dev/null; then
    echo ">>> Cài đặt docker.io & docker-compose..."
    apt-get update -qq
    apt-get install -y -qq docker.io docker-compose
fi

# 2. Khởi chạy containerd và dockerd (Tương thích Ubuntu 24.04 trên Colab không có systemd)
mkdir -p /var/log/docker

if ! docker info &> /dev/null; then
    echo ">>> Khởi động containerd..."
    if ! pgrep -f containerd > /dev/null; then
        nohup containerd > /var/log/docker/containerd.log 2>&1 &
        sleep 2
    fi

    echo ">>> Khởi chạy dockerd..."
    # Thử chạy với driver overlay2 hoặc fallback sang vfs nếu container bị hạn chế
    nohup dockerd --iptables=false > /var/log/docker/dockerd.log 2>&1 &
    sleep 4

    # Nếu chưa lên, thử với storage-driver vfs
    if ! docker info &> /dev/null; then
        echo ">>> Thử lại với storage-driver=vfs..."
        pkill -f dockerd || true
        sleep 1
        nohup dockerd --storage-driver=vfs --iptables=false > /var/log/docker/dockerd.log 2>&1 &
        sleep 4
    fi
fi

# 3. Kiểm tra trạng thái
if docker info &> /dev/null; then
    echo ">>> Docker đã hoạt động bình thường!"
    docker --version
    docker ps
else
    echo ">>> CẢNH BÁO: Không thể khởi chạy Docker daemon. Chi tiết log:"
    tail -n 20 /var/log/docker/dockerd.log 2>/dev/null || true
fi
