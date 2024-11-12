# Stage 1: Base image with system dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    SERVE_API_LOCALLY=false \
    PIP_ROOT_USER_ACTION=ignore

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    git \
    wget \
    curl \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-glx \
    ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir --upgrade pip

# Stage 2: Build stage
FROM base AS builder

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm -rf /root/.cache/pip

# Install system dependencies and clean up in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    git \
    wget \
    curl \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-glx \
    ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir --upgrade pip

# Setup ComfyUI and dependencies in one layer with cleanup
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    mkdir -p /comfyui/custom_nodes /comfyui/models && \
    cd /comfyui && \
    pip3 install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    rm -rf /root/.cache/pip && \
    pip3 install --no-cache-dir --upgrade -r requirements.txt && \
    rm -rf /root/.cache/pip && \
    pip3 install --no-cache-dir runpod requests && \
    rm -rf /root/.cache/pip && \
    pip3 install --no-cache-dir \
    opencv-contrib-python \
    "rembg[gpu]" \
    scikit-image \
    webcolors \
    pymatting \
    accelerate \
    diffusers \
    blend_modes \
    pyOpenSSL \
    "qrcode[pil]" \
    segment_anything \
    openai \
    timm \
    colour-science \
    wget \
    xformers \
    imageio-ffmpeg \
    python-dotenv \
    fal-serverless \
    clip-interrogator==0.6.0 && \
    rm -rf /root/.cache/pip && \
    rm -rf /comfyui/.git

# Setup custom nodes in one layer with cleanup
WORKDIR /comfyui/custom_nodes
RUN for repo in \
    "https://github.com/ltdrdata/ComfyUI-Manager.git" \
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git" \
    "https://github.com/WASasquatch/was-node-suite-comfyui.git" \
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes.git" \
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" \
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git" \
    "https://github.com/sipherxyz/comfyui-art-venture.git" \
    "https://github.com/jamesWalker55/comfyui-various.git" \
    "https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git" \
    "https://github.com/Acly/comfyui-inpaint-nodes.git" \
    "https://github.com/spacepxl/ComfyUI-Image-Filters.git" \
    "https://github.com/cubiq/ComfyUI_essentials.git" \
    "https://github.com/kijai/ComfyUI-KJNodes.git" \
    "https://github.com/kijai/ComfyUI-IC-Light.git" \
    "https://github.com/kijai/ComfyUI-DepthAnythingV2.git" \
    "https://github.com/audioscavenger/save-image-extended-comfyui.git" \
    "https://github.com/chflame163/ComfyUI_LayerStyle.git" \
    "https://github.com/shadowcz007/comfyui-mixlab-nodes.git" \
    "https://github.com/natto-maki/ComfyUI-NegiTools.git" \
    "https://github.com/yolain/ComfyUI-Easy-Use.git" \
    "https://github.com/digitaljohn/comfyui-propost.git" \
    "https://github.com/huchenlei/ComfyUI-IC-Light-Native.git" \
    "https://github.com/SuperBeastsAI/ComfyUI-SuperBeasts.git" \
    "https://github.com/jiaxiangc/ComfyUI-ResAdapter.git" \
    "https://github.com/Goktug/comfyui-saveimage-plus.git"; \
    do \
        name=$(basename "$repo" .git); \
        echo "Installing $name..." && \
        git clone --depth=1 "$repo" "$name" || \
        echo "Failed to clone $name, continuing..." && \
        rm -rf "${name}/.git" || true; \
    done && \
    find . -name "requirements.txt" -exec pip3 install --no-cache-dir -r {} \; && \
    find . -name ".git" -type d -exec rm -rf {} + || true && \
    rm -rf /root/.cache/pip && \
    rm -rf /tmp/* /var/tmp/*

# Setup start script
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./

WORKDIR /
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Create improved wrapper script with better error handling
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Setting up directories..."\n\
\n\
# Function to safely copy files and install requirements\n\
setup_directory() {\n\
    local src=$1\n\
    local dst=$2\n\
    if [ -d "$src" ]; then\n\
        echo "Copying from $src to $dst..."\n\
        cp -rf "$src"/* "$dst"/ 2>/dev/null || true\n\
        if [ -f "$dst/requirements.txt" ]; then\n\
            echo "Installing requirements for $dst..."\n\
            pip3 install --no-cache-dir -r "$dst/requirements.txt" || true\n\
        fi\n\
    fi\n\
}\n\
\n\
# Setup directories with error handling\n\
setup_directory "/runpod-volume/custom_nodes" "/comfyui/custom_nodes"\n\
setup_directory "/runpod-volume/models" "/comfyui/models"\n\
\n\
start_comfyui() {\n\
    local port=$1\n\
    echo "Starting ComfyUI on port $port..."\n\
    if [ "$SERVE_API_LOCALLY" = "true" ]; then\n\
        python3 -u /comfyui/main.py --listen 0.0.0.0 --port $port\n\
    else\n\
        # Start ComfyUI in background for serverless mode\n\
        python3 -u /comfyui/main.py --listen 127.0.0.1 --port $port & \n\
        local pid=$!\n\
        echo "ComfyUI started with PID $pid"\n\
        \n\
        # Wait for server to be ready\n\
        echo "Waiting for ComfyUI to be ready..."\n\
        for i in {1..30}; do\n\
            if wget -q --spider http://127.0.0.1:$port; then\n\
                echo "ComfyUI is ready!"\n\
                break\n\
            fi\n\
            if [ $i -eq 30 ]; then\n\
                echo "ComfyUI failed to start"\n\
                kill -9 $pid\n\
                exit 1\n\
            fi\n\
            echo "Attempt $i: Waiting for ComfyUI..."\n\
            sleep 2\n\
        done\n\
        \n\
        # Start RunPod handler\n\
        echo "Starting RunPod handler..."\n\
        /start.sh\n\
    fi\n\
}\n\
\n\
# Start with appropriate port\n\
if [ "$SERVE_API_LOCALLY" = "true" ]; then\n\
    start_comfyui 8188\n\
else\n\
    start_comfyui 3000\n\
fi' > /start_wrapper.sh && chmod +x /start_wrapper.sh

CMD ["/start_wrapper.sh"]
