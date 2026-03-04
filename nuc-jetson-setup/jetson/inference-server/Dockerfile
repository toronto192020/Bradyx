# Bradix Jetson Inference Server
# Base: NVIDIA L4T (Linux for Tegra) with Python
# Compatible with JetPack 6.x (Jetson AGX Orin, Orin NX, Orin Nano)

FROM nvcr.io/nvidia/l4t-pytorch:r36.2.0-pth2.1-py3

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application
COPY server.py .

# Case data will be mounted at runtime
VOLUME ["/case-data"]

# Expose inference API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the inference server
CMD ["python3", "server.py"]
