import os
import platform
import time
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="Colab CI/CD Demo Service",
    description="Ứng dụng mẫu để thực hành CI/CD với Google Colab",
    version="1.0.0",
)

START_TIME = time.time()


class SystemInfoResponse(BaseModel):
    status: str
    uptime_seconds: float
    system: str
    node_name: str
    python_version: str
    gpu_available: bool
    gpu_name: str | None = None


@app.get("/", tags=["General"])
def read_root():
    return {
        "message": "Xin chào! Ứng dụng đã được triển khai thành công trên Colab Server qua CI/CD Pipeline!",
        "version": "1.0.0",
        "docs_url": "/docs",
    }


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "healthy", "timestamp": time.time()}


@app.get("/system-info", response_model=SystemInfoResponse, tags=["System"])
def get_system_info():
    gpu_available = False
    gpu_name = None

    try:
        import torch

        gpu_available = torch.cuda.is_available()
        if gpu_available:
            gpu_name = torch.cuda.get_device_name(0)
    except ImportError:
        pass

    return SystemInfoResponse(
        status="running",
        uptime_seconds=round(time.time() - START_TIME, 2),
        system=f"{platform.system()} {platform.release()}",
        node_name=platform.node(),
        python_version=platform.python_version(),
        gpu_available=gpu_available,
        gpu_name=gpu_name,
    )
