# Direct3D-S2 for NVIDIA RTX 5090 (sm_120)

This fork provides full support for NVIDIA RTX 5090 GPUs with CUDA Compute Capability 12.0 (sm_120).

## Problem Statement

The original Direct3D-S2 uses PyTorch 2.5.1 which only supports CUDA architectures up to sm_90. The RTX 5090 requires sm_120 support, causing the following error:

```
RuntimeError: CUDA error: no kernel image is available for execution on the device
NVIDIA GeForce RTX 5090 with CUDA capability sm_120 is not compatible with the current PyTorch installation.
```

## Solution

This fork upgrades the stack to support RTX 5090:

- **PyTorch**: 2.5.1 → 2.7.1 (CUDA 12.8)
- **Base Docker Image**: nvidia/cuda:12.1.0 → nvidia/cuda:12.8.0
- **CUDA Architecture**: TORCH_CUDA_ARCH_LIST="12.0"
- **TorchSparse**: Manually compiled with sm_120 support
- **Removed**: xformers (compatibility issues with PyTorch 2.7.1)

## Changes Made

### 1. Dockerfile
- Updated base image to `nvidia/cuda:12.8.0-devel-ubuntu22.04`
- Upgraded PyTorch to 2.7.1 with CUDA 12.8: `torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128`
- Set `TORCH_CUDA_ARCH_LIST="12.0"` for RTX 5090 architecture
- Removed xformers dependency
- Updated helper script with correct architecture

### 2. app.py (Gradio Interface)
- Added gradio_client monkey patch to fix json_schema issues
- Updated launch configuration for proper localhost access

## Installation

### Prerequisites
- NVIDIA RTX 5090 GPU
- Docker with NVIDIA Container Toolkit
- Docker Compose

### Quick Start

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/Direct3D-S2-RTX5090.git
cd Direct3D-S2-RTX5090

# Build the Docker image (this will take 20-30 minutes)
docker-compose build

# Start the container
docker-compose up
```

The Gradio interface will be available at http://localhost:7860

## First-Time Setup

On the first run, TorchSparse needs to be compiled with CUDA support. If mesh generation fails with:
```
AttributeError: module 'torchsparse.backend' has no attribute 'build_kernel_map_subm_hashmap'
```

Run the manual compilation script inside the container:

```bash
docker exec direct3d-s2-direct3d_s2-1 /workspace/compile_torchsparse.sh
```

Then restart the container:
```bash
docker-compose restart
```

## Verification

Verify your installation works correctly:

```bash
docker exec direct3d-s2-direct3d_s2-1 python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA: {torch.version.cuda}')
print(f'GPU: {torch.cuda.get_device_name(0)}')
print(f'CUDA Available: {torch.cuda.is_available()}')

import torchsparse.backend
cuda_funcs = [x for x in dir(torchsparse.backend) if 'cuda' in x.lower()]
print(f'TorchSparse CUDA functions: {len(cuda_funcs)}')
print(f'Has critical function: {hasattr(torchsparse.backend, \"build_kernel_map_subm_hashmap\")}')
"
```

Expected output:
```
PyTorch: 2.7.1+cu128
CUDA: 12.8
GPU: NVIDIA GeForce RTX 5090
CUDA Available: True
TorchSparse CUDA functions: 21
Has critical function: True
```

## Technical Details

### Stack Comparison

| Component | Original | RTX 5090 Fork |
|-----------|----------|---------------|
| Base Image | nvidia/cuda:12.1.0-devel-ubuntu22.04 | nvidia/cuda:12.8.0-devel-ubuntu22.04 |
| PyTorch | 2.5.1+cu121 | 2.7.1+cu128 |
| torchvision | 0.20.1+cu121 | 0.22.1+cu128 |
| CUDA | 12.1 | 12.8 |
| xformers | 0.0.29.post1 | Removed |
| TORCH_CUDA_ARCH_LIST | 6.0;6.1;7.0;7.5;8.0;8.6;8.9;9.0 | 12.0 |

### Why These Changes?

1. **PyTorch 2.7.1**: First stable PyTorch version with sm_120 (RTX 5090) support
2. **CUDA 12.8**: Required by PyTorch 2.7.1 for sm_120 kernels
3. **Single Architecture**: Building only for sm_120 reduces compilation time significantly
4. **No xformers**: Version conflicts with PyTorch 2.7.1; flash-attn provides similar functionality

### Compatibility

This fork is specifically optimized for RTX 5090. If you have older GPUs, use the original repository instead.

Supported GPUs:
- ✅ NVIDIA RTX 5090 (sm_120)
- ✅ NVIDIA RTX 50-series (sm_120)

Not supported:
- ❌ RTX 40-series and older (use original repo)

## Troubleshooting

### Models Not Downloading
The container will automatically download required models on first run. Ensure you have:
- Stable internet connection
- Sufficient disk space (~20GB for models)
- Hugging Face access (some models may require authentication)

### Out of Memory Errors
The RTX 5090 has 32GB VRAM, which should be sufficient. If you encounter OOM errors:
- Close other GPU applications
- Reduce batch size if processing multiple images

### Container Won't Start
Check NVIDIA Container Toolkit is installed:
```bash
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
```

## Performance

On RTX 5090, you can expect:
- Image preprocessing: ~2-3 seconds
- Mesh generation: ~8-15 seconds (depending on complexity)
- Total time per image: ~10-20 seconds

## Contributing

Issues and pull requests are welcome! If you encounter problems specific to RTX 5090, please open an issue with:
- Your GPU model
- Docker version
- Error logs

## Credits

- Original Direct3D-S2: [DreamTechAI/Direct3D-S2](https://github.com/DreamTechAI/Direct3D-S2)
- RTX 5090 adaptation: Based on successful TRELLIS RTX 5090 configuration
- Thanks to the PyTorch, TorchSparse, and NVIDIA CUDA teams for sm_120 support

## License

Same as original Direct3D-S2 repository.
