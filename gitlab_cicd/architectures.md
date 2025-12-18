# GitLab CI/CD Architecture Diagram

## High-Level Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          GitLab Instance                                  │
│                     (gitlab.com or self-hosted)                          │
│                                                                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  Git Repos  │───▶│  Pipelines  │───▶│   Runners   │                 │
│  │             │    │   (.yml)    │    │  (Manager)  │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                               │                          │
└───────────────────────────────────────────────┼───────────────────────────┘
                                                │
                                                │ Job Distribution
                                                │
┌───────────────────────────────────────────────▼───────────────────────────┐
│                    RKE2 Kubernetes Cluster                                │
│                      (3 Nodes - Ubuntu 24.04)                             │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                  Namespace: gitlab-runner                           │ │
│  │                                                                     │ │
│  │  ┌──────────────────────┐                                         │ │
│  │  │  GitLab Runner Pod   │                                         │ │
│  │  │  ┌────────────────┐  │                                         │ │
│  │  │  │ Runner Manager │  │  Spawns temporary pods                 │ │
│  │  │  │   (watches     │  │  ───────────────────┐                  │ │
│  │  │  │   for jobs)    │  │                     │                  │ │
│  │  │  └────────────────┘  │                     │                  │ │
│  │  └──────────────────────┘                     │                  │ │
│  │           │                                    ▼                  │ │
│  │           │                    ┌────────────────────────────┐    │ │
│  │           │                    │    Job Execution Pods      │    │ │
│  │           │                    │  ┌──────────────────────┐  │    │ │
│  │           │                    │  │   Kaniko Builder     │  │    │ │
│  │           │                    │  │  (rootless build)    │  │    │ │
│  │           │                    │  └──────────────────────┘  │    │ │
│  │           │                    │  ┌──────────────────────┐  │    │ │
│  │           │                    │  │   Test Runner Pod    │  │    │ │
│  │           │                    │  └──────────────────────┘  │    │ │
│  │           │                    │  ┌──────────────────────┐  │    │ │
│  │           │                    │  │   Deploy Pod         │  │    │ │
│  │           │                    │  └──────────────────────┘  │    │ │
│  │           │                    └────────────────────────────┘    │ │
│  │           │                                    │                  │ │
│  │           ▼                                    │                  │ │
│  │  ┌──────────────────────┐                     │                  │ │
│  │  │   Longhorn Storage   │◀────Cache───────────┘                  │ │
│  │  │    (PVC: cache)      │                                        │ │
│  │  └──────────────────────┘                                        │ │
│  │                                                                   │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                     │                                 │
│                                     │ Push/Pull Images                │
│  ┌──────────────────────────────────▼──────────────────────────────┐ │
│  │              Harbor Container Registry                          │ │
│  │         (harbor.k8s.local - via MetalLB)                        │ │
│  │                                                                  │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │ │
│  │  │   Projects   │  │ Robot Account│  │  Scanning    │         │ │
│  │  │   (library)  │  │  (gitlab-ci) │  │  (Trivy)     │         │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘         │ │
│  │                                                                  │ │
│  │  ┌──────────────────────────────────────────────────────────┐  │ │
│  │  │           Longhorn Storage (Harbor Data)                 │  │ │
│  │  └──────────────────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                Supporting Infrastructure                       │ │
│  │                                                                │ │
│  │  • MetalLB: Load Balancer (192.168.29.x)                      │ │
│  │  • NGINX Ingress: Traffic routing                             │ │
│  │  • cert-manager: TLS certificates                             │ │
│  │  • Longhorn: Persistent storage (CSI)                         │ │
│  │  • Calico: CNI networking                                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

## Pipeline Execution Flow

```
┌────────────┐
│ Developer  │
│  commits   │
│  & pushes  │
└──────┬─────┘
       │
       ▼
┌────────────────┐
│ GitLab detects │
│   new commit   │
└──────┬─────────┘
       │
       ▼
┌────────────────┐
│ Pipeline (.yml)│
│   is parsed    │
└──────┬─────────┘
       │
       ▼
┌────────────────┐
│  Jobs queued   │
│  for execution │
└──────┬─────────┘
       │
       ▼
┌──────────────────────┐
│ Runner picks up job  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  Runner spawns job pod in K8s        │
│  • Sets up environment               │
│  • Mounts secrets (Harbor creds)     │
│  • Attaches cache volume             │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│     Build Stage (Kaniko)             │
│  • Pulls base image from Harbor      │
│  • Builds container image            │
│  • Uses layer caching                │
│  • Pushes to Harbor registry         │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│     Test Stage                       │
│  • Pulls built image                 │
│  • Runs tests                        │
│  • Reports results                   │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│     Deploy Stage (Manual/Auto)       │
│  • Updates K8s deployment            │
│  • Uses kubectl set image            │
│  • Monitors rollout status           │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│     Job completion                   │
│  • Logs stored in GitLab             │
│  • Artifacts preserved               │
│  • Pod cleaned up                    │
└──────────────────────────────────────┘
```

## Kaniko Build Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kaniko Build Flow                            │
└─────────────────────────────────────────────────────────────────┘

1. Job Pod Creation
   ┌──────────────────────────────────────┐
   │  Pod: runner-<hash>                  │
   │  Image: gcr.io/kaniko-project/executor│
   │  No privileged mode required!        │
   └──────────────────────────────────────┘
                  │
                  ▼
2. Authentication Setup
   ┌──────────────────────────────────────┐
   │  Create /kaniko/.docker/config.json  │
   │  {                                   │
   │    "auths": {                        │
   │      "harbor.k8s.local": {           │
   │        "auth": "base64(user:pass)"   │
   │      }                               │
   │    }                                 │
   │  }                                   │
   └──────────────────────────────────────┘
                  │
                  ▼
3. Base Image Pull
   ┌──────────────────────────────────────┐
   │  Pull FROM image                     │
   │  harbor.k8s.local/library/ubuntu     │
   │  (uses Harbor credentials)           │
   └──────────────────────────────────────┘
                  │
                  ▼
4. Layer Building
   ┌──────────────────────────────────────┐
   │  For each Dockerfile instruction:    │
   │  • RUN → Create layer                │
   │  • COPY → Create layer               │
   │  • ADD → Create layer                │
   │  • Use cache if available            │
   └──────────────────────────────────────┘
                  │
                  ▼
5. Image Push
   ┌──────────────────────────────────────┐
   │  Push to Harbor:                     │
   │  harbor.k8s.local/library/app:tag    │
   │  • Push each layer                   │
   │  • Update manifest                   │
   │  • Tag as requested                  │
   └──────────────────────────────────────┘
                  │
                  ▼
6. Cache Update
   ┌──────────────────────────────────────┐
   │  Update cache repository:            │
   │  harbor.k8s.local/cache/app          │
   │  (for faster subsequent builds)      │
   └──────────────────────────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                   Security Architecture                         │
└─────────────────────────────────────────────────────────────────┘

Layer 1: Kubernetes RBAC
┌──────────────────────────────────────┐
│  ServiceAccount: gitlab-runner       │
│  Role: Limited pod management        │
│  • Can create/delete pods            │
│  • Can read secrets/configmaps       │
│  • Cannot modify other resources     │
└──────────────────────────────────────┘

Layer 2: Pod Security
┌──────────────────────────────────────┐
│  Security Context:                   │
│  • runAsNonRoot: true                │
│  • runAsUser: 100                    │
│  • fsGroup: 65533                    │
│  • No privileged mode                │
│  • Capabilities dropped              │
└──────────────────────────────────────┘

Layer 3: Network Isolation
┌──────────────────────────────────────┐
│  Network Policies:                   │
│  • Ingress: Only from monitoring     │
│  • Egress: GitLab + Harbor + K8s API │
│  • No cross-namespace traffic        │
└──────────────────────────────────────┘

Layer 4: Secret Management
┌──────────────────────────────────────┐
│  Kubernetes Secrets:                 │
│  • Harbor credentials                │
│  • Robot account tokens              │
│  • Encrypted at rest                 │
│  • RBAC-controlled access            │
└──────────────────────────────────────┘

Layer 5: Registry Security
┌──────────────────────────────────────┐
│  Harbor Security:                    │
│  • Robot accounts (not admin)        │
│  • Project-level RBAC                │
│  • Vulnerability scanning            │
│  • Content trust (optional)          │
└──────────────────────────────────────┘
```

## Resource Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Resource Management                         │
└─────────────────────────────────────────────────────────────────┘

Runner Manager Pod
├─ CPU: 100m-200m
├─ Memory: 128Mi-256Mi
└─ Storage: Ephemeral

Job Execution Pods (per job)
├─ CPU: 500m-2000m
├─ Memory: 1Gi-4Gi
└─ Storage:
   ├─ Ephemeral (build)
   └─ PVC (cache) - shared across jobs

Cache Storage (Longhorn PVC)
├─ Capacity: 50Gi
├─ AccessMode: ReadWriteMany
└─ StorageClass: longhorn

Harbor Storage (Longhorn PVCs)
├─ Registry: 100Gi
├─ Database: 10Gi
└─ Redis: 1Gi
```

## Network Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Network Architecture                       │
└─────────────────────────────────────────────────────────────────┘

External Traffic:
Internet ─────┐
              │
              ▼
         ┌─────────┐
         │ MetalLB │ (192.168.29.150)
         └────┬────┘
              │
              ▼
      ┌────────────────┐
      │ NGINX Ingress  │
      └────┬───────────┘
           │
           ├──▶ Harbor (harbor.k8s.local)
           └──▶ Other services

Internal Traffic:
Runner ─────────┐
                │
                ├──▶ GitLab API (https://gitlab.com)
                │    • Job polling
                │    • Log streaming
                │    • Artifact upload
                │
                ├──▶ Harbor Registry (harbor.k8s.local)
                │    • Image pull
                │    • Image push
                │    • Authentication
                │
                └──▶ Kubernetes API (in-cluster)
                     • Pod creation
                     • Resource management
                     • Secret access
```

## Monitoring Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring & Observability                   │
└─────────────────────────────────────────────────────────────────┘

GitLab Runner Metrics (Port 9252)
├─ Job metrics
│  ├─ gitlab_runner_jobs_total
│  ├─ gitlab_runner_job_duration_seconds
│  └─ gitlab_runner_failed_jobs_total
├─ System metrics
│  ├─ gitlab_runner_concurrent_limit
│  └─ process_cpu_seconds_total
└─ Exported to Prometheus

Logs
├─ Runner Manager
│  ├─ Job lifecycle events
│  └─ Registration status
├─ Job Pods
│  ├─ Build output
│  └─ Error messages
└─ Aggregated in GitLab UI

Harbor Metrics
├─ Storage usage
├─ Pull/push rates
└─ Vulnerability scan results
```

## Deployment Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Physical Deployment                          │
└─────────────────────────────────────────────────────────────────┘

MacBook M3 (96GB RAM)
├─ VM: k8s-master (192.168.64.10)
│  ├─ Control plane
│  ├─ etcd
│  └─ Runner Manager (can run here)
│
├─ VM: k8s-node-1 (192.168.64.11)
│  ├─ Worker node
│  ├─ Harbor pods
│  └─ Job execution pods
│
└─ VM: k8s-node-2 (192.168.64.12)
   ├─ Worker node
   ├─ Longhorn storage
   └─ Job execution pods

Anti-Affinity Rules:
• Runner pods spread across nodes
• No single point of failure
• HA for critical services
```