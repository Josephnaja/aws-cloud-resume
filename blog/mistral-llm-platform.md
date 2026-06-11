# Building a Production LLM Inference Platform on AWS EKS with vLLM

**June 9, 2026**

---

## The Goal

Deploy [Mistral 7B Instruct v0.3](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3) as a production-ready inference service on AWS — with GPU acceleration, authentication, rate limiting, autoscaling, monitoring, and CI/CD — while keeping costs under control with Spot instances.

## Architecture

```
Internet → NLB → FastAPI Gateway (2x CPU pods)
                        ↓
              vLLM Inference Server (GPU pod, A10G)
                        ↓
              Mistral 7B Model (bfloat16, FlashAttention2)
```

The platform runs on AWS EKS (Kubernetes 1.30) with two node groups:

- **CPU nodes** (2x t3.medium, On-Demand): Run the FastAPI gateway pods
- **GPU nodes** (g5.xlarge/2xlarge/4xlarge, Spot): Run the vLLM inference server with NVIDIA A10G GPU (24GB VRAM)

## Key Components

### 1. vLLM Inference Server

[vLLM](https://docs.vllm.ai/) serves the model with:
- **Paged attention** for efficient GPU memory management
- **Continuous batching** for high throughput
- **FlashAttention2** for optimized attention computation
- OpenAI-compatible API (`/v1/chat/completions`)

Configuration: 8192 max context, 90% GPU memory utilization, bfloat16 precision.

### 2. FastAPI Gateway

A lightweight API gateway handling:
- **Bearer token authentication** — validates API keys before forwarding to vLLM
- **Per-IP rate limiting** — sliding window counter (configurable RPM)
- **Prometheus metrics** — request count, latency histograms, token generation rate
- **Health/readiness checks** — `/health` (gateway) and `/ready` (backend connectivity)

### 3. Infrastructure as Code (Terraform)

All AWS resources defined in Terraform:
- VPC with public/private subnets across 2 AZs
- EKS cluster with managed node groups
- ECR repositories for container images
- S3 backend for remote state

### 4. Kubernetes Deployment (Helm)

Helm chart deploying:
- vLLM deployment with GPU tolerations, node affinity, and generous startup probes (5 min for model loading)
- Gateway deployment on CPU nodes
- ClusterIP service for internal vLLM communication
- LoadBalancer service for external gateway access
- HPA with custom metrics (pending request queue depth)

### 5. CI/CD Pipelines

- **CI**: Lint (ruff) → Test (pytest) → Build & push to ECR
- **CD**: Canary deployment (10% traffic) → Smoke tests → Full promotion or rollback

## Challenges & Solutions

### Challenge 1: GPU Node Disk Space

The vLLM Docker image is ~12GB. The default 20GB root volume on g5 instances ran out of space during image pull.

**Solution**: Updated the launch template to use 100GB gp3 volumes for GPU nodes.

### Challenge 2: Spot Instance Availability

Single GPU instance type led to `UnfulfillableCapacity` errors.

**Solution**: Configured multiple g5 instance types (xlarge, 2xlarge, 4xlarge) — all with compatible single-GPU configurations — increasing Spot fulfillment probability.

### Challenge 3: EKS 1.30 AMI Compatibility

Amazon Linux 2 AMIs are deprecated for EKS 1.29+.

**Solution**: Migrated to `AL2023_x86_64_STANDARD` (CPU) and `AL2023_x86_64_NVIDIA` (GPU) AMI types.

### Challenge 4: vLLM Model Loading Time

Mistral 7B takes ~2 minutes to load into GPU memory, causing premature pod restarts.

**Solution**: Configured a startup probe with 60s initial delay, 10s period, and 30 failure threshold (allows up to 5 minutes for model download and loading).

## Load Test Results

Using Locust with 3 concurrent users over 60 seconds:

| Metric | Value |
|--------|-------|
| Total requests | 59 |
| Failure rate | 0% |
| Avg inference latency | 3,451ms |
| p50 latency | 3,400ms |
| p95 latency | 3,500ms |
| Health check latency | 24ms |
| Throughput | 0.81 req/s |

The consistent ~3.4s latency for 100-token completions with zero failures demonstrates stable production performance.

## Cost Optimization

| Strategy | Savings |
|----------|---------|
| GPU Spot instances | ~60-70% vs On-Demand |
| Single NAT gateway | ~50% vs multi-AZ NAT |
| t3.medium CPU nodes (burstable) | Minimal cost for gateway workloads |
| HPA on queue depth | Scale-to-zero potential during idle periods |

Estimated monthly cost: ~$250-400 (depending on Spot pricing and utilization).

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Model | Mistral 7B Instruct v0.3 |
| Inference | vLLM 0.22.1 (FlashAttention2, CUDA 13) |
| GPU | NVIDIA A10G (24GB VRAM) |
| Gateway | Python, FastAPI, Uvicorn |
| Containers | Docker, ECR |
| Orchestration | Kubernetes 1.30 (EKS) |
| Deployment | Helm 4, GitHub Actions |
| IaC | Terraform (EKS module v20) |
| Monitoring | Prometheus, Grafana |
| Load Testing | Locust |

## Key Takeaways

1. **vLLM is production-ready** — continuous batching and paged attention deliver consistent low-latency inference
2. **Spot GPU instances work** for inference — the key is offering multiple instance types and handling interruptions gracefully
3. **Disk sizing matters** — large ML container images need planning beyond default EBS volumes
4. **Startup probes are essential** — LLM model loading takes minutes, not seconds
5. **Gateway pattern adds value** — authentication, rate limiting, and observability at the edge before hitting expensive GPU resources

---

*Source code available on [GitHub](https://github.com/josenaja/mistrall-llm-platform).*
