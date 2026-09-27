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

# 2. Khởi chạy Docker daemon (Colab không dùng systemd, dùng service hoặc dockerd trực tiếp)
if ! docker info &> /dev/null; then
    echo ">>> Khởi động Docker daemon service..."
    service docker start || true
    sleep 3
fi

# Nếu service docker start chưa chạy được, chạy dockerd nền với cgroup/vfs tương thích container
if ! docker info &> /dev/null; then
    echo ">>> Khởi chạy dockerd nền chế độ fallback..."
    mkdir -p /var/log/docker
    dockerd --iptables=false > /var/log/docker/dockerd.log 2>&1 &
    sleep 5
fi

# 3. Kiểm tra trạng thái
if docker info &> /dev/null; then
    echo ">>> Docker đã hoạt động bình thường!"
    docker --version
else
    echo ">>> CẢNH BÁO: Không thể khởi chạy Docker daemon tự động. Vui lòng kiểm tra log: /var/log/docker/dockerd.log"
fi
