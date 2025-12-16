# GitLab values.yaml Deep Dive

## Overview

Your uploaded `values.yaml` is the **official GitLab Helm chart configuration template** (v8.6.0). It contains 1,562 lines of configuration options for deploying a complete GitLab instance. This document explains each major section.

## File Structure

```
values.yaml (1,562 lines)
├── Global Configuration (lines 26-248)
│   ├── Basic Settings
│   ├── Host Configuration  
│   ├── Ingress Setup
│   ├── Database Configuration
│   ├── Redis Configuration
│   ├── Gitaly Configuration
│   └── Application Config
│
├── Component-Specific Config (lines 249-1469)
│   ├── certmanager
│   ├── nginx-ingress
│   ├── prometheus
│   ├── redis
│   ├── postgresql
│   ├── registry
│   ├── gitlab-runner
│   └── gitlab subcharts
│
└── GitLab Components (lines 1470-1562)
    ├── toolbox
    ├── webservice
    ├── sidekiq
    ├── gitaly
    └── gitlab-shell
```

## Section-by-Section Breakdown

### Section 1: Global Settings (Lines 26-54)

```yaml
global:
  edition: ee                       # Enterprise Edition (EE) or Community (CE)
  gitlabVersion: "18.6.0"          # GitLab version to deploy
```

**What this means:**
- `edition: ee` - Installs Enterprise Edition (includes all features)
  - Change to `ce` for Community Edition (free, fewer features)
- `gitlabVersion` - Locks to specific GitLab version
  - Recommended: Use specific versions for stability
  - Can use `latest` but not recommended for production

**Your options:**
```yaml
# Option 1: Enterprise Edition (recommended)
edition: ee

# Option 2: Community Edition (if you don't need EE features)
edition: ce
```

### Section 2: Host Configuration (Lines 62-76)

```yaml
global:
  hosts:
    domain: example.com             # Base domain
    hostSuffix:                     # Optional suffix
    https: true                     # Enable HTTPS
    gitlab: {}                      # GitLab-specific overrides
    registry: {}                    # Registry-specific overrides
```

**What this configures:**
- Base domain for all GitLab services
- Automatic subdomain creation:
  - `gitlab.example.com` - Main GitLab UI
  - `registry.example.com` - Container registry
  - `minio.example.com` - MinIO object storage
  - `kas.example.com` - Kubernetes Agent Server

**Your configuration:**
```yaml
global:
  hosts:
    domain: k8s.local               # Your local domain
    https: true                      # Always use HTTPS
    gitlab:
      name: gitlab.k8s.local        # Full GitLab URL
    registry:
      name: registry.k8s.local      # Full registry URL
```

### Section 3: Ingress Configuration (Lines 78-91)

```yaml
global:
  ingress:
    configureCertmanager: true      # Auto-configure cert-manager
    provider: nginx                  # Ingress controller type
    enabled: true                    # Enable ingress
    annotations: {}                  # Custom annotations
    tls:
      enabled: true                  # Enable TLS
```

**What this does:**
- Integrates with your existing NGINX Ingress Controller
- Automatically creates TLS certificates via cert-manager
- Creates Ingress resources for all GitLab services

**Perfect for your setup:**
```yaml
global:
  ingress:
    configureCertmanager: true      # Uses your cert-manager
    provider: nginx                  # Uses your NGINX
    enabled: true
    class: nginx                     # Ingress class name
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    tls:
      enabled: true
```

### Section 4: Initial Credentials (Lines 122-127)

```yaml
global:
  initialRootPassword: {}
    # secret: RELEASE-gitlab-initial-root-password
    # key: password
```

**What this is:**
- Root user password for first login
- If not set, automatically generated
- Stored in Kubernetes Secret

**Recommended approach:**
```bash
# Create secret manually before deployment
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password='YourSecurePassword123!' \
  --namespace=gitlab
```

### Section 5: PostgreSQL Configuration (Lines 129-171)

```yaml
global:
  psql:
    password: {}                    # Database password
    host: postgresql.hostedsomewhere.else  # External DB (optional)
    port: 123
    username: gitlab
    database: gitlabhq_production
```

**Two deployment modes:**

**Mode 1: Bundled PostgreSQL (Default)**
```yaml
postgresql:
  install: true                     # Deploy PostgreSQL in cluster
  # Uses Longhorn for persistence
```

**Mode 2: External PostgreSQL**
```yaml
postgresql:
  install: false                    # Don't deploy PostgreSQL

global:
  psql:
    host: your-postgres.example.com
    port: 5432
    username: gitlab
    database: gitlabhq_production
    password:
      secret: gitlab-postgresql-password
      key: password
```

**Recommendation:** Start with bundled PostgreSQL

### Section 6: Redis Configuration (Lines 172-192)

```yaml
global:
  redis:
    auth:
      enabled: true                 # Password authentication
    host: redis.hostedsomewhere.else  # External Redis (optional)
    port: 6379
```

**Similar to PostgreSQL:**

**Bundled Redis (Default):**
```yaml
redis:
  install: true                     # Deploy Redis in cluster
  architecture: standalone          # Single instance
```

**External Redis:**
```yaml
redis:
  install: false

global:
  redis:
    host: your-redis.example.com
    port: 6379
    auth:
      enabled: true
      secret: gitlab-redis-secret
      key: password
```

### Section 7: Gitaly Configuration (Lines 193-213)

```yaml
global:
  gitaly:
    enabled: true                   # Git repository storage
    internal:
      names: [default]              # Storage pools
    external: []                    # External Gitaly (optional)
```

**What Gitaly does:**
- Stores all Git repositories
- Handles all Git operations
- Can be scaled horizontally

**Storage pools:**
```yaml
global:
  gitaly:
    internal:
      names: [default]              # Single storage pool
      # names: [default, storage2] # Multiple pools for scaling
```

### Section 8: MinIO Configuration (Lines 241-245)

```yaml
global:
  minio:
    enabled: true                   # S3-compatible object storage
    credentials: {}                 # Auto-generated
```

**What MinIO stores:**
- Container registry images (if using built-in registry)
- CI/CD artifacts (build outputs)
- CI/CD caches (dependencies)
- LFS (Large File Storage) objects
- User uploads (avatars, attachments)
- Terraform state files
- Backup archives

**Alternative: External S3**
```yaml
global:
  minio:
    enabled: false                  # Don't deploy MinIO

  appConfig:
    object_store:
      enabled: true
      connection:
        secret: gitlab-object-storage
        key: connection
    # Then configure AWS S3, Google Cloud Storage, etc.
```

### Section 9: Application Configuration (Lines 247-280)

```yaml
global:
  appConfig:
    enableUsagePing: true           # Send usage statistics to GitLab
    enableSeatLink: true            # License seat linking
    enableImpersonation:            # Admin can impersonate users
    
    defaultProjectsFeatures:
      issues: true                  # Enable issues by default
      mergeRequests: true           # Enable merge requests
      wiki: true                    # Enable wiki
      snippets: true                # Enable snippets
      builds: true                  # Enable CI/CD
```

**Privacy settings:**
```yaml
global:
  appConfig:
    enableUsagePing: false          # Don't send usage data
    enableSeatLink: false           # No license calling home
```

### Section 10: GitLab Components (Lines 1470-1499)

```yaml
gitlab:
  toolbox:                          # Maintenance and backup tool
    replicas: 1
  
  webservice:                       # Main web application
    enabled: true
    replicas: 2                     # For high availability
  
  sidekiq:                          # Background job processor
    enabled: true
    replicas: 2
  
  gitaly:                           # Git storage service
    enabled: true
  
  gitlab-shell:                     # SSH access for Git
    enabled: true
```

**Component purposes:**

| Component | Purpose | Replicas |
|-----------|---------|----------|
| **webservice** | Web UI, API, Git HTTP | 2+ (HA) |
| **sidekiq** | Background jobs (emails, imports) | 2+ (HA) |
| **gitaly** | Git operations | 1+ |
| **gitlab-shell** | SSH for Git | 1+ |
| **toolbox** | Backups, maintenance | 1 |
| **migrations** | Database migrations | Job |

### Section 11: GitLab Runner (Lines 1429-1461)

```yaml
gitlab-runner:
  install: true                     # Install runner with GitLab
  rbac:
    create: true                    # Create RBAC resources
  
  runners:
    locked: false                   # Runners can be shared
    config: |
      [[runners]]
        [runners.kubernetes]
        image = "ubuntu:22.04"      # Default job image
```

**Integrated runner features:**
- Automatically registered with GitLab
- Pre-configured Kubernetes executor
- Uses MinIO for caching
- No manual registration needed

**Configuration:**
```yaml
gitlab-runner:
  install: true
  replicas: 2                       # Multiple runners for HA
  
  runners:
    config: |
      [[runners]]
        [runners.kubernetes]
          namespace = "gitlab"
          image = "ubuntu:22.04"
          privileged = false        # Rootless (use Kaniko)
          
          cpu_limit = "2"
          memory_limit = "4Gi"
          
          [runners.cache]
            Type = "s3"             # Uses MinIO
            Path = "gitlab-runner"
            Shared = true
```

### Section 12: Container Registry (Lines 1382-1386)

```yaml
# registry:
#   enabled: false                  # Commented out = disabled by default
```

**Registry options:**

**Option 1: GitLab Built-in Registry**
```yaml
registry:
  enabled: true                     # Enable built-in registry
  persistence:
    enabled: true
    storageClass: longhorn
    size: 100Gi
```

**Option 2: Use Harbor (Your existing registry)**
```yaml
registry:
  enabled: false                    # Disable built-in registry
  
# Then configure Harbor in GitLab UI:
# Admin Area → Settings → CI/CD → Container Registry
# External registry URL: https://harbor.k8s.local
```

**Recommendation:** Use Harbor (you already have it configured)

### Section 13: Redis Deployment (Lines 1292-1323)

```yaml
redis:
  install: true                     # Deploy Redis
  image:
    repository: bitnamilegacy/redis
  auth:
    existingSecret: gitlab-redis-secret  # Auto-generated password
    usePasswordFiles: true
  architecture: standalone          # or "replication" for HA
  metrics:
    enabled: true                   # Prometheus metrics
```

**Architecture options:**

**Standalone (Default):**
```yaml
redis:
  architecture: standalone          # Single instance
  cluster:
    enabled: false
```

**High Availability:**
```yaml
redis:
  architecture: replication         # Master + replicas
  replica:
    replicaCount: 3                 # 3 Redis replicas
  sentinel:
    enabled: true                   # Enable Sentinel for failover
```

### Section 14: PostgreSQL Deployment (Lines 1326-1377)

```yaml
postgresql:
  install: true
  image:
    repository: bitnamilegacy/postgresql
    tag: 16.6.0                     # PostgreSQL version
  
  primary:
    persistence:
      size: 8Gi                     # Database storage size
    
  metrics:
    enabled: true                   # Prometheus metrics
```

**Storage configuration:**
```yaml
postgresql:
  primary:
    persistence:
      enabled: true
      storageClass: longhorn        # Use Longhorn
      size: 20Gi                    # Adjust based on needs
      accessModes:
        - ReadWriteOnce
```

**Resource configuration:**
```yaml
postgresql:
  primary:
    resources:
      requests:
        memory: 256Mi
        cpu: 250m
      limits:
        memory: 2Gi                 # Adjust for your workload
        cpu: 1000m
```

## Key Configuration Patterns

### Pattern 1: Use Existing Infrastructure

```yaml
# Use your existing NGINX Ingress
nginx-ingress:
  enabled: false

# Use your existing cert-manager
certmanager:
  install: false

# Use your existing monitoring
prometheus:
  install: false
```

### Pattern 2: Scale Components Independently

```yaml
gitlab:
  webservice:
    replicas: 3                     # More for web traffic
    minReplicas: 2
    maxReplicas: 10
  
  sidekiq:
    replicas: 2                     # Fewer for background jobs
```

### Pattern 3: Resource Right-Sizing

**Development/Testing:**
```yaml
gitlab:
  webservice:
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
```

**Production:**
```yaml
gitlab:
  webservice:
    resources:
      requests:
        memory: 2.5Gi
        cpu: 1000m
      limits:
        memory: 3Gi
        cpu: 1500m
```

### Pattern 4: Storage Allocation

```yaml
# Git repositories (grows over time)
gitlab:
  gitaly:
    persistence:
      size: 100Gi                   # Start with 100GB

# PostgreSQL database
postgresql:
  primary:
    persistence:
      size: 20Gi                    # 20GB is usually enough

# MinIO object storage (artifacts, uploads, backups)
minio:
  persistence:
    size: 50Gi                      # Adjust based on usage
```

## Important Values to Set

### Must Configure

```yaml
# 1. Domain name
global:
  hosts:
    domain: k8s.local               # YOUR DOMAIN

# 2. Root password
global:
  initialRootPassword:
    secret: gitlab-initial-root-password

# 3. Storage class
postgresql:
  primary:
    persistence:
      storageClass: longhorn        # YOUR STORAGE CLASS
```

### Recommended to Configure

```yaml
# 1. Disable external services
global:
  appConfig:
    enableUsagePing: false
    enableSeatLink: false

# 2. Resource limits
gitlab:
  webservice:
    resources:
      requests:
        memory: 2.5Gi
        cpu: 1000m

# 3. High availability
gitlab:
  webservice:
    replicas: 2
  sidekiq:
    replicas: 2
```

### Optional but Useful

```yaml
# 1. Custom annotations
global:
  ingress:
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "0"  # Unlimited upload

# 2. Time zone
global:
  time_zone: America/New_York

# 3. Email configuration
global:
  smtp:
    enabled: true
    address: smtp.gmail.com
    port: 587
    user_name: "your-email@gmail.com"
    password:
      secret: gitlab-smtp-password
      key: password
```

## Common Customization Scenarios

### Scenario 1: Minimal Installation (Low Resources)

```yaml
gitlab:
  webservice:
    replicas: 1
    resources:
      requests: {memory: 1.5Gi, cpu: 500m}
  sidekiq:
    replicas: 1
    resources:
      requests: {memory: 1Gi, cpu: 500m}
  gitaly:
    persistence:
      size: 50Gi

postgresql:
  primary:
    persistence:
      size: 10Gi

minio:
  persistence:
    size: 20Gi
```

**Total resources:** ~3-4GB RAM, 2 vCPU, 80GB storage

### Scenario 2: Production HA Installation

```yaml
gitlab:
  webservice:
    replicas: 3
    hpa:
      minReplicas: 2
      maxReplicas: 10
    resources:
      requests: {memory: 2.5Gi, cpu: 1000m}
  
  sidekiq:
    replicas: 3
    hpa:
      minReplicas: 2
      maxReplicas: 5
  
  gitaly:
    persistence:
      size: 200Gi

redis:
  architecture: replication
  replica:
    replicaCount: 3

postgresql:
  primary:
    persistence:
      size: 50Gi
```

**Total resources:** ~12-16GB RAM, 8 vCPU, 250GB storage

### Scenario 3: Use External Services

```yaml
# External PostgreSQL
postgresql:
  install: false
global:
  psql:
    host: postgres.external.com
    password:
      secret: external-postgres-secret

# External Redis
redis:
  install: false
global:
  redis:
    host: redis.external.com
    password:
      secret: external-redis-secret

# External Object Storage (S3)
minio:
  install: false
global:
  appConfig:
    object_store:
      enabled: true
      connection:
        secret: gitlab-s3-storage
        key: connection
```

**Benefits:** Reduced cluster resource usage, managed services

## values.yaml Best Practices

### 1. Use a Custom Values File

```bash
# Don't modify the default values.yaml
# Create your own:
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values my-custom-values.yaml
```

### 2. Version Control Your Values

```bash
# Keep your values.yaml in Git
git add my-custom-values.yaml
git commit -m "GitLab configuration"
```

### 3. Use Secrets Properly

```yaml
# Don't put passwords in values.yaml
# Reference secrets instead:
global:
  psql:
    password:
      secret: gitlab-postgres-secret  # Created separately
      key: password
```

### 4. Start Minimal, Scale Up

```yaml
# Begin with:
- replicas: 1 for all components
- Smaller storage sizes
- Lower resource requests

# Then increase based on actual usage
```

### 5. Test with Dry-Run

```bash
# Always dry-run first
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values my-values.yaml \
  --dry-run --debug > output.yaml

# Review output.yaml for issues
```

## Summary

Your `values.yaml` file is a comprehensive configuration template with:

- **Global settings** - Apply to all components
- **Component configs** - Individual service tuning
- **Integration points** - External services
- **Resource allocation** - CPU, memory, storage
- **High availability** - Replication and scaling
- **Security** - TLS, authentication, RBAC

**Key points:**
1. Don't use the default values.yaml directly
2. Create a custom values file with only what you need
3. Start with minimal resources
4. Scale based on usage
5. Use your existing infrastructure (NGINX, cert-manager, Longhorn)

**Next step:** Use the `full-gitlab-deployment.md` guide with a custom values file!