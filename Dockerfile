# Use base CUDA image
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    SERVE_API_LOCALLY=false

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-glx && \
    rm -rf /var/lib/apt/lists/*

# Setup ComfyUI and dependencies in one layer
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    mkdir -p /comfyui/custom_nodes /comfyui/models && \
    cd /comfyui && \
    pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --no-cache-dir --upgrade -r requirements.txt && \
    pip3 install --no-cache-dir runpod requests && \
    pip3 install --no-cache-dir \
    opencv-python-headless \
    "rembg[gpu]" \
    scikit-image \
    webcolors \
    pymatting \
    accelerate \
    diffusers \
    blend_modes \
    pyOpenSSL \
    "qrcode[pil]" \
    segment_anything

# Setup custom nodes in one layer
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git && \
    find . -name "requirements.txt" -exec pip3 install --no-cache-dir -r {} \;

# Setup start script
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./
WORKDIR /
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Create wrapper script
RUN echo '#!/bin/bash\n\
if [ -d /runpod-volume/custom_nodes ]; then\n\
  cp -rf /runpod-volume/custom_nodes/* /comfyui/custom_nodes/ 2>/dev/null || true\n\
fi\n\
if [ -d /runpod-volume/models ]; then\n\
  cp -rf /runpod-volume/models/* /comfyui/models/ 2>/dev/null || true\n\
fi\n\
if [ "$SERVE_API_LOCALLY" = "true" ]; then\n\
  python3 -u /comfyui/main.py --listen 0.0.0.0 --port 8188\n\
else\n\
  python3 -u /comfyui/main.py --listen 0.0.0.0 --port 8188 & \n\
  sleep 5\n\
  /start.sh\n\
fi' > /start_wrapper.sh && chmod +x /start_wrapper.sh

CMD ["/start_wrapper.sh"]
