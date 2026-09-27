#!/usr/bin/env bash
# ==============================================================================
# Script: setup_system.sh
# Purpose: Chuẩn bị môi trường hệ thống cơ bản trên Google Colab
# ==============================================================================
set -euo pipefail

echo "=========================================="
echo ">>> [1/5] Đang cập nhật gói hệ thống cơ bản..."
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    jq \
    tar \
    unzip \
    tmux \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release

echo ">>> Cập nhật hệ thống thành công!"
