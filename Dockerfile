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
    curl \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-glx \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir --upgrade pip

# Setup ComfyUI and dependencies in one layer
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    mkdir -p /comfyui/custom_nodes /comfyui/models && \
    cd /comfyui && \
    pip3 install --no-cache-dir --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --no-cache-dir --upgrade -r requirements.txt && \
    pip3 install --no-cache-dir runpod requests && \
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
    clip-interrogator==0.6.0

# Setup custom nodes in one layer with error handling
WORKDIR /comfyui/custom_nodes
RUN set -e; \
    declare -A repos=( \
        ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git" \
        ["ComfyUI-Inspire-Pack"]="https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git" \
        ["was-node-suite-comfyui"]="https://github.com/WASasquatch/was-node-suite-comfyui.git" \
        ["ComfyUI-post-processing-nodes"]="https://github.com/EllangoK/ComfyUI-post-processing-nodes.git" \
        ["ComfyUI_Comfyroll_CustomNodes"]="https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" \
        ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git" \
        ["comfyui-art-venture"]="https://github.com/sipherxyz/comfyui-art-venture.git" \
        ["comfyui-various"]="https://github.com/jamesWalker55/comfyui-various.git" \
        ["ComfyUI-AutomaticCFG"]="https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git" \
        ["comfyui-inpaint-nodes"]="https://github.com/Acly/comfyui-inpaint-nodes.git" \
        ["ComfyUI-Image-Filters"]="https://github.com/spacepxl/ComfyUI-Image-Filters.git" \
        ["ComfyUI_essentials"]="https://github.com/cubiq/ComfyUI_essentials.git" \
        ["ComfyUI-KJNodes"]="https://github.com/kijai/ComfyUI-KJNodes.git" \
        ["ComfyUI-IC-Light"]="https://github.com/kijai/ComfyUI-IC-Light.git" \
        ["ComfyUI-DepthAnythingV2"]="https://github.com/kijai/ComfyUI-DepthAnythingV2.git" \
        ["save-image-extended-comfyui"]="https://github.com/audioscavenger/save-image-extended-comfyui.git" \
        ["ComfyUI_LayerStyle"]="https://github.com/chflame163/ComfyUI_LayerStyle.git" \
        ["comfyui-mixlab-nodes"]="https://github.com/shadowcz007/comfyui-mixlab-nodes.git" \
        ["ComfyUI-NegiTools"]="https://github.com/natto-maki/ComfyUI-NegiTools.git" \
        ["ComfyUI-Easy-Use"]="https://github.com/yolain/ComfyUI-Easy-Use.git" \
        ["comfyui-propost"]="https://github.com/digitaljohn/comfyui-propost.git" \
        ["ComfyUI-IC-Light-Native"]="https://github.com/huchenlei/ComfyUI-IC-Light-Native.git" \
        ["ComfyUI-SuperBeasts"]="https://github.com/SuperBeastsAI/ComfyUI-SuperBeasts.git" \
        ["ComfyUI-ResAdapter"]="https://github.com/jiaxiangc/ComfyUI-ResAdapter.git" \
        ["comfyui-saveimage-plus"]="https://github.com/Goktug/comfyui-saveimage-plus.git" \
    ); \
    for name in "${!repos[@]}"; do \
        echo "Installing ${name}..." && \
        git clone --depth=1 "${repos[$name]}" "$name" || \
        echo "Failed to clone ${name}, continuing..."; \
    done && \
    for dir in */; do \
        if [ -f "${dir}requirements.txt" ]; then \
            echo "Installing requirements for ${dir}..." && \
            pip3 install --no-cache-dir -r "${dir}requirements.txt" || \
            echo "Failed to install requirements for ${dir}, continuing..."; \
        fi \
    done

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
