# Direct3D-S2 Docker Environment (CUDA 12.8 for RTX 5090 sm_120 support)
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

LABEL name="direct3d-s2" maintainer="direct3d-s2"

# Create workspace folder and set it as working directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Update package lists and install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    git-lfs \
    wget \
    vim \
    unzip \
    pkg-config \
    cmake \
    curl \
    libegl1-mesa-dev \
    libglib2.0-0 \
    libglvnd0 \
    libgl1 \
    libglx0 \
    libegl1 \
    libgles2 \
    libglvnd-dev \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    mesa-utils-extra \
    libeigen3-dev \
    python3-dev \
    python3-setuptools \
    libcgal-dev \
    libsparsehash-dev \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
ENV PYOPENGL_PLATFORM=egl

# Set CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV TORCH_CUDA_ARCH_LIST="12.0"

# Parallel compilation jobs (optimized for high-end systems with 12+ cores and 64GB+ RAM)
ENV MAX_JOBS=12

# Install conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x Miniconda3-latest-Linux-x86_64.sh && \
    ./Miniconda3-latest-Linux-x86_64.sh -b -p /workspace/miniconda3 && \
    rm Miniconda3-latest-Linux-x86_64.sh

# Update PATH environment variable
ENV PATH="/workspace/miniconda3/bin:${PATH}"

# Initialize conda
RUN conda init bash

# Set conda to always auto-approve
RUN conda config --set always_yes true

# Accept conda Terms of Service
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create and activate conda environment
RUN conda create -n direct3d-s2 python=3.10 && echo "source activate direct3d-s2" > ~/.bashrc
ENV PATH /workspace/miniconda3/envs/direct3d-s2/bin:$PATH

# Install conda packages
RUN conda install Ninja
# CUDA 12.8 provided by base image nvidia/cuda:12.8.0-devel-ubuntu22.04
RUN conda install -c conda-forge libstdcxx-ng -y

# Clone Direct3D-S2 repository first (needed for requirements.txt)
RUN git clone https://github.com/DreamTechAI/Direct3D-S2.git
WORKDIR /workspace/Direct3D-S2

# Install PyTorch 2.7.1 with CUDA 12.8 FIRST (required for RTX 5090 sm_120 support)
RUN pip install torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128

# Install dependencies that DON'T require compilation first
RUN pip install scikit-image trimesh omegaconf tqdm huggingface_hub einops numpy transformers==4.40.2 diffusers pymeshfix pyvista igraph

# Install utils3d from git
RUN pip install git+https://github.com/EasternJournalist/utils3d.git#egg=utils3d

# Try to install triton (may fail on some systems, but not critical)
RUN pip install triton==3.1.0 || echo "⚠️ Triton installation failed - continuing without it"

# Try to install flash-attn (may fail, but not always critical)
RUN pip install flash-attn --no-build-isolation || echo "⚠️ flash-attn installation failed - continuing without it"

# Install third_party/voxelize (requires PyTorch to be already installed)
RUN pip install third_party/voxelize/ || echo "⚠️ voxelize installation failed - some features may be limited"

# Install additional dependencies with compatible gradio_client version
RUN pip install timm kornia "gradio<5.0" "gradio_client<1.0"

# Install TorchSparse dependencies BEFORE compiling TorchSparse
RUN pip install rootpath backports.cached-property

# Try to install torchsparse using setup.py (avoids pip isolation issues)
RUN git clone https://github.com/mit-han-lab/torchsparse.git /workspace/torchsparse && cd /workspace/torchsparse && python setup.py install || echo "❌ TorchSparse installation failed completely. Direct3D-S2 may work with limited functionality."

# Set global library paths to ensure proper linking at runtime
ENV LD_LIBRARY_PATH="/workspace/miniconda3/envs/direct3d-s2/lib:${LD_LIBRARY_PATH}"

# Activate conda environment by default
RUN echo "conda activate direct3d-s2" >> ~/.bashrc
SHELL ["/bin/bash", "--login", "-c"]

# Create test script to check installation
RUN echo '#!/bin/bash\n\
echo "🧪 Testing Direct3D-S2 installation..."\n\
python -c "import torch; print(f\"✅ PyTorch {torch.__version__} with CUDA {torch.version.cuda}\")" || echo "❌ PyTorch import failed"\n\
python -c "import direct3d_s2; print(\"✅ Direct3D-S2 imported successfully\")" || echo "❌ Direct3D-S2 import failed"\n\
python -c "import torchsparse; print(\"✅ TorchSparse imported successfully\")" || echo "⚠️  TorchSparse not available - some features may be limited"\n\
python -c "import timm, kornia, gradio; print(\"✅ Additional dependencies imported successfully\")" || echo "❌ Some dependencies missing"\n\
echo "🎉 Installation check complete!"' > /workspace/test_installation.sh && chmod +x /workspace/test_installation.sh

# Create helper script for manual torchsparse compilation if needed
RUN echo '#!/bin/bash\n\
echo "🔧 Manual TorchSparse compilation..."\n\
cd /workspace\n\
rm -rf torchsparse\n\
git clone https://github.com/mit-han-lab/torchsparse.git\n\
cd torchsparse\n\
export MAX_JOBS=1\n\
export TORCH_CUDA_ARCH_LIST="12.0"\n\
python setup.py clean --all\n\
python setup.py install' > /workspace/compile_torchsparse.sh && chmod +x /workspace/compile_torchsparse.sh

# Set working directory to Direct3D-S2 project
WORKDIR /workspace/Direct3D-S2

# Set default command
CMD ["/bin/bash", "-c", "echo 'Welcome to Direct3D-S2 Docker environment!' && echo 'Run /workspace/test_installation.sh to check installation status' && echo 'If TorchSparse failed, try /workspace/compile_torchsparse.sh' && /bin/bash"]