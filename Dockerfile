# Use base CUDA image
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1

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

# Clone ComfyUI and create directories
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    mkdir -p /comfyui/custom_nodes /comfyui/models

WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --upgrade pip && \
    pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --upgrade -r requirements.txt && \
    pip3 install runpod requests

# Pre-install ALL dependencies including previously missing ones
RUN pip3 install --no-cache-dir \
    opencv-python-headless \
    "rembg[gpu]" \
    scikit-image \
    webcolors \
    pymatting \
    accelerate \
    diffusers \
    transformers \
    "qrcode[pil]" \
    segment_anything \
    docopt \
    hydra-core \
    mediapipe \
    controlnet_aux \
    scipy \
    safetensors \
    pytorch_lightning \
    einops \
    timm \
    open_clip_torch \
    ultralytics \
    openai \
    blend_modes \
    pyOpenSSL \
    GitPython \
    flask \
    lark-parser

# Add custom nodes before ComfyUI setup
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && \
    git clone https://github.com/sipherxyz/comfyui-art-venture.git && \
    git clone https://github.com/jamesWalker55/comfyui-various.git && \
    git clone https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git && \
    git clone https://github.com/spacepxl/ComfyUI-Image-Filters.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/chflame163/ComfyUI_LayerStyle.git && \
    git clone https://github.com/natto-maki/ComfyUI-NegiTools.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git

# Install any requirements from custom nodes
RUN find . -name "requirements.txt" -exec pip3 install -r {} \;

# Add volume support files
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./

# Setup start script
WORKDIR /
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Create a wrapper script to handle startup
RUN echo '#!/bin/bash\n\
if [ -d /runpod-volume/custom_nodes ]; then\n\
  cp -rf /runpod-volume/custom_nodes/* /comfyui/custom_nodes/ 2>/dev/null || true\n\
fi\n\
if [ -d /runpod-volume/models ]; then\n\
  cp -rf /runpod-volume/models/* /comfyui/models/ 2>/dev/null || true\n\
fi\n\
python3 -u /comfyui/main.py --listen 0.0.0.0 --port 8188 & \n\
sleep 5\n\
/start.sh' > /start_wrapper.sh && chmod +x /start_wrapper.sh

CMD ["/start_wrapper.sh"]
