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

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui

WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --upgrade -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Pre-install all custom node dependencies
RUN pip3 install --no-cache-dir \
    opencv-python \
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
    hydra-core

# Create directories for nodes and models
RUN mkdir -p /comfyui/custom_nodes /comfyui/models

# Add volume support files
ADD src/extra_model_paths.yaml ./

WORKDIR /
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

CMD /start.sh
