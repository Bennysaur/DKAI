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
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --upgrade -r requirements.txt && \
    pip3 install runpod requests

# Pre-install all custom node dependencies
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
    ultralytics

# Clone essential custom nodes
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    git clone https://github.com/EllangoK/ComfyUI-post-processing-nodes.git && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && \
    git clone https://github.com/sipherxyz/comfyui-art-venture.git && \
    git clone https://github.com/jamesWalker55/comfyui-various.git && \
    git clone https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git && \
    git clone https://github.com/Acly/comfyui-inpaint-nodes.git && \
    git clone https://github.com/spacepxl/ComfyUI-Image-Filters.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/chflame163/ComfyUI_LayerStyle.git && \
    git clone https://github.com/shadowcz007/comfyui-mixlab-nodes.git && \
    git clone https://github.com/natto-maki/ComfyUI-NegiTools.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone https://github.com/digitaljohn/comfyui-propost.git && \
    git clone https://github.com/SuperBeastsAI/ComfyUI-SuperBeasts.git

# Add volume support files
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./

# Setup start script
WORKDIR /
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Modified CMD to handle both pre-installed and network volume nodes
CMD sh -c "if [ -d /runpod-volume/custom_nodes ]; then cp -rf /runpod-volume/custom_nodes/* /comfyui/custom_nodes/ 2>/dev/null || true; fi && if [ -d /runpod-volume/models ]; then cp -rf /runpod-volume/models/* /comfyui/models/ 2>/dev/null || true; fi && /start.sh"
