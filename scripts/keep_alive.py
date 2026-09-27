#!/usr/bin/env python3
"""
Keep-alive and Server Status Dashboard for Google Colab.
In ra thông tin trạng thái tài nguyên, dịch vụ (SSH, Docker, Tunnel, Runner) định kỳ.
"""

import os
import subprocess
import time
from datetime import datetime


def get_command_output(cmd: str) -> str:
    try:
        res = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=5
        )
        return res.stdout.strip()
    except Exception:
        return "N/A"


def check_service(name: str, check_cmd: str) -> str:
    status = subprocess.run(check_cmd, shell=True, capture_output=True)
    return "🟢 RUNNING" if status.returncode == 0 else "🔴 STOPPED"


def print_dashboard():
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Resource info
    ram = get_command_output(
        "free -h | awk '/Mem:/ {print $3 \" / \" $2}'"
    )
    disk = get_command_output(
        "df -h / | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'"
    )
    gpu = get_command_output(
        "nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits"
    )
    if not gpu or "N/A" in gpu:
        gpu_str = "No GPU / CPU Runtime"
    else:
        parts = [p.strip() for p in gpu.split(",")]
        gpu_str = f"{parts[0]} | Util: {parts[1]}% | VRAM: {parts[2]}MB / {parts[3]}MB"

    # Services
    ssh_status = check_service("SSH", "pgrep -f sshd")
    docker_status = check_service("Docker", "docker info")
    runner_status = check_service("GitHub Runner", "pgrep -f Runner.Listener")
    cf_status = check_service("Cloudflare Tunnel", "pgrep -f cloudflared")
    tailscale_status = check_service("Tailscale", "pgrep -f tailscaled")

    print("\n" + "=" * 65)
    print(f" 🚀 COLAB SERVER DASHBOARD & HEARTBEAT | {timestamp}")
    print("=" * 65)
    print(f" 💾 RAM Usage   : {ram}")
    print(f" 💽 Disk Space  : {disk}")
    print(f" ⚡ GPU Info    : {gpu_str}")
    print("-" * 65)
    print(" 🛠️  DỊCH VỤ:")
    print(f"    • OpenSSH Server      : {ssh_status}")
    print(f"    • Docker Daemon       : {docker_status}")
    print(f"    • GitHub CI Runner    : {runner_status}")
    print(f"    • Cloudflare Tunnel   : {cf_status}")
    print(f"    • Tailscale VPN       : {tailscale_status}")
    print("=" * 65)
    print(" (Đang duy trì phiên làm việc... Nhấn Stop cell để dừng)\n")


def main():
    interval = int(os.environ.get("HEARTBEAT_INTERVAL", 60))
    print(f">>> Bắt đầu keep-alive dashboard (chu kỳ {interval} giây)...")
    try:
        while True:
            print_dashboard()
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n>>> Đã dừng Keep-alive loop.")


if __name__ == "__main__":
    main()
