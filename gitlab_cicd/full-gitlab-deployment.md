# Full GitLab Installation Guide for Kubernetes

## Overview

This guide covers deploying the **complete GitLab platform** on your RKE2 Kubernetes cluster, including:

- ✅ GitLab UI (Web Interface)
- ✅ Git Repository Management
- ✅ Built-in Container Registry
- ✅ GitLab Runner (CI/CD)
- ✅ PostgreSQL Database
- ✅ Redis Cache
- ✅ MinIO (Object Storage)
- ✅ Gitaly (Git Repository Storage)
- ✅ Issue Tracking, Merge Requests, Wiki
- ✅ All GitLab Enterprise Edition features

## Understanding Your values.yaml

Your uploaded `values.yaml` is the **official GitLab Helm chart configuration template**. Let me break down the key sections:

### Key Configuration Sections

#### 1. Global Settings (Lines 26-77)

```yaml
global:
  edition: ee                    # Enterprise Edition (use 'ce' for Community)
  gitlabVersion: "18.6.0"       # GitLab version to install
  
  hosts:
    domain: example.com          # YOUR DOMAIN HERE
    https: true                  # Enable HTTPS (recommended)
```

**What you need to configure:**
- `hosts.domain` - Your domain (e.g., `k8s.local` or `gitlab.yourdomain.com`)
- GitLab will be accessible at `gitlab.k8s.local` (or your domain)

#### 2. Ingress Configuration (Lines 78-91)

```yaml
global:
  ingress:
    configureCertmanager: true   # Auto TLS with cert-manager
    provider: nginx              # Use your NGINX ingress
    enabled: true
    tls:
      enabled: true              # Enable TLS
```

**Perfect for your setup:**
- Uses your existing NGINX Ingress Controller
- Integrates with cert-manager for automatic TLS
- MetalLB will provide the LoadBalancer IP

#### 3. PostgreSQL Database (Lines 129-171, 1326-1377)

```yaml
postgresql:
  install: true                  # Deploy PostgreSQL in cluster
  auth:
    password: auto-generated     # Handled by shared-secrets
```

**Bundled PostgreSQL:**
- Bitnami PostgreSQL 16.6.0
- Automatic password generation
- Uses Longhorn for persistent storage
- Metrics enabled for monitoring

#### 4. Redis Cache (Lines 172-192, 1292-1323)

```yaml
redis:
  install: true                  # Deploy Redis in cluster
  architecture: standalone       # Single Redis instance
  auth:
    enabled: true                # Password protected
```

**Bundled Redis:**
- Bitnami Redis
- Single instance (can enable cluster mode)
- Password authentication
- Metrics enabled

#### 5. MinIO Object Storage (Lines 241-245)

```yaml
global:
  minio:
    enabled: true                # Deploy MinIO for object storage
    credentials: {}              # Auto-generated
```

**What MinIO stores:**
- Container registry images (if using built-in registry)
- CI/CD artifacts and caches
- LFS objects
- Uploads and avatars
- Terraform states

#### 6. Gitaly (Git Storage) (Lines 193-213)

```yaml
global:
  gitaly:
    enabled: true                # Git repository storage service
    internal:
      names: [default]           # Storage name
```

**Gitaly handles:**
- All Git operations
- Repository storage
- Git protocol optimization

#### 7. GitLab Runner (Lines 1429-1461)

```yaml
gitlab-runner:
  install: true                  # Install runner with GitLab
  runners:
    config: |
      [[runners]]
        [runners.kubernetes]
        image = "ubuntu:22.04"
```

**Integrated Runner:**
- Automatically registered with GitLab
- Kubernetes executor configured
- Uses MinIO for cache (if enabled)

#### 8. Container Registry (Lines 1382-1386)

```yaml
# registry:
#   enabled: false               # Disabled by default (commented out)
```

**Registry Options:**
- Can enable GitLab's built-in registry
- Or use your existing Harbor registry

## Resource Requirements

### Minimum Resources

| Component | CPU | Memory | Storage |
|-----------|-----|---------|---------|
| **GitLab Webservice** | 1 CPU | 2.5GB | - |
| **GitLab Sidekiq** | 1 CPU | 2GB | - |
| **Gitaly** | 500m | 1GB | 50GB |
| **PostgreSQL** | 500m | 512MB | 10GB |
| **Redis** | 100m | 512MB | 5GB |
| **MinIO** | 200m | 512MB | 10GB |
| **GitLab Shell** | 100m | 100MB | - |
| **GitLab Runner** | 100m | 256MB | - |
| **Toolbox** | 200m | 256MB | - |
| **NGINX Ingress** | 200m | 256MB | - |
| **cert-manager** | - | - | - |
| **Total** | **~4 vCPU** | **~8-10GB RAM** | **~75GB** |

### Recommended Resources for Production

| Component | CPU | Memory | Storage |
|-----------|-----|---------|---------|
| **Total Recommended** | **8 vCPU** | **16-24GB RAM** | **100GB+** |

**Your Cluster Capacity:**
- 3 Nodes × 32GB RAM = 96GB total ✅
- More than sufficient for full GitLab

## Architecture: Full GitLab vs Runner-Only

### Full GitLab (This Guide)

```
┌─────────────────────────────────────────────────────────┐
│           Your Kubernetes Cluster (RKE2)                │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │         GitLab Namespace (gitlab)                  │ │
│  │                                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐              │ │
│  │  │   GitLab     │  │   GitLab     │              │ │
│  │  │  Webservice  │  │   Sidekiq    │              │ │
│  │  │   (UI/API)   │  │ (Background) │              │ │
│  │  └──────────────┘  └──────────────┘              │ │
│  │         │                  │                       │ │
│  │         └─────────┬────────┘                      │ │
│  │                   │                                │ │
│  │         ┌─────────▼─────────┐                     │ │
│  │         │    PostgreSQL     │                     │ │
│  │         │   (Database)      │                     │ │
│  │         └───────────────────┘                     │ │
│  │                   │                                │ │
│  │         ┌─────────▼─────────┐                     │ │
│  │         │      Redis        │                     │ │
│  │         │     (Cache)       │                     │ │
│  │         └───────────────────┘                     │ │
│  │                                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐              │ │
│  │  │    Gitaly    │  │    MinIO     │              │ │
│  │  │ (Git Storage)│  │   (S3-like)  │              │ │
│  │  └──────────────┘  └──────────────┘              │ │
│  │                                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐              │ │
│  │  │ GitLab Runner│  │   Registry   │              │ │
│  │  │   (CI/CD)    │  │  (Optional)  │              │ │
│  │  └──────────────┘  └──────────────┘              │ │
│  └────────────────────────────────────────────────────┘ │
│                          │                              │
│  ┌───────────────────────▼───────────────────────────┐ │
│  │          NGINX Ingress Controller                 │ │
│  └───────────────────────┬───────────────────────────┘ │
│                          │                              │
└──────────────────────────┼──────────────────────────────┘
                           │
                  ┌────────▼────────┐
                  │    MetalLB      │
                  │  (192.168.x.x)  │
                  └─────────────────┘
                           │
                     Users Access
                  gitlab.k8s.local
```

### Benefits vs Runner-Only

| Aspect | Full GitLab | Runner Only |
|--------|-------------|-------------|
| **Git Hosting** | ✅ Self-hosted | ❌ External (gitlab.com) |
| **Issue Tracking** | ✅ Included | ❌ External |
| **Merge Requests** | ✅ Included | ❌ External |
| **Wiki** | ✅ Included | ❌ External |
| **Container Registry** | ✅ Built-in option | ✅ Use Harbor |
| **Control** | ✅ Complete | ⚠️ Limited to CI/CD |
| **Data Privacy** | ✅ All on-premises | ⚠️ Code on gitlab.com |
| **Resource Usage** | ⚠️ 8-10GB RAM | ✅ ~2GB RAM |
| **Maintenance** | ⚠️ More complex | ✅ Simpler |
| **Cost** | ✅ Free (OSS) | ✅ Free (OSS) |

## Step-by-Step Deployment

### Prerequisites Checklist

- [ ] RKE2 cluster with 3 nodes
- [ ] kubectl configured
- [ ] Helm 3.x installed
- [ ] NGINX Ingress Controller deployed
- [ ] cert-manager deployed
- [ ] MetalLB deployed with available IPs
- [ ] Longhorn storage class available
- [ ] DNS or /etc/hosts configured for gitlab.k8s.local

### Step 1: Add GitLab Helm Repository

```bash
# Add official GitLab Helm chart repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Verify repository
helm search repo gitlab/gitlab --versions | head -5
```

### Step 2: Create Namespace

```bash
# Create dedicated namespace
kubectl create namespace gitlab

# Label namespace
kubectl label namespace gitlab \
  name=gitlab \
  component=devops \
  monitoring=enabled
```

### Step 3: Prepare Your Custom values.yaml

Create a custom configuration based on the template:

```bash
# Create custom values file
cat > gitlab-custom-values.yaml <<'EOF'
# GitLab Custom Configuration for k8s.local

## Global settings
global:
  # Edition: ee (Enterprise) or ce (Community)
  edition: ee
  
  # Host configuration
  hosts:
    domain: k8s.local               # Your domain
    https: true                      # Enable HTTPS
    gitlab:
      name: gitlab.k8s.local        # GitLab URL
    registry:
      name: registry.k8s.local      # Registry URL (if enabled)
  
  # Ingress configuration
  ingress:
    configureCertmanager: true      # Use cert-manager for TLS
    provider: nginx                  # Use your NGINX ingress
    enabled: true
    class: nginx                     # Ingress class name
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod  # Your cert-manager issuer
    tls:
      enabled: true
  
  # Initial root password (will be auto-generated if not set)
  initialRootPassword:
    secret: gitlab-initial-root-password
    key: password
  
  # Time zone
  time_zone: UTC
  
  # GitLab application configuration
  appConfig:
    enableUsagePing: false          # Disable usage statistics
    enableSeatLink: false
    
    # Default project features
    defaultProjectsFeatures:
      issues: true
      mergeRequests: true
      wiki: true
      snippets: true
      builds: true                   # CI/CD enabled by default
    
    # Object storage (MinIO)
    object_store:
      enabled: true
      proxy_download: true
      storage_options: {}
      connection: {}
    
    # LFS, Artifacts, Uploads, Packages
    lfs:
      enabled: true
      proxy_download: true
      bucket: git-lfs
      connection: {}
    artifacts:
      enabled: true
      proxy_download: true
      bucket: gitlab-artifacts
      connection: {}
    uploads:
      enabled: true
      proxy_download: true
      bucket: gitlab-uploads
      connection: {}
    packages:
      enabled: true
      proxy_download: true
      bucket: gitlab-packages
      connection: {}
    
    # Backup settings
    backups:
      bucket: gitlab-backups
      tmpBucket: tmp

## PostgreSQL configuration
postgresql:
  install: true
  image:
    tag: 16.6.0
  primary:
    persistence:
      storageClass: longhorn        # Use Longhorn storage
      size: 20Gi
  metrics:
    enabled: true

## Redis configuration  
redis:
  install: true
  architecture: standalone
  auth:
    enabled: true
  master:
    persistence:
      storageClass: longhorn
      size: 5Gi
  metrics:
    enabled: true

## MinIO configuration (Object Storage)
minio:
  install: true
  persistence:
    storageClass: longhorn
    size: 50Gi                      # Adjust based on needs
  resources:
    requests:
      memory: 512Mi
      cpu: 200m

## GitLab components configuration
gitlab:
  # Webservice (main application)
  webservice:
    replicas: 2                     # HA with 2 replicas
    resources:
      requests:
        memory: 2.5Gi
        cpu: 1000m
      limits:
        memory: 3Gi
        cpu: 1500m
    workhorse:
      resources:
        requests:
          memory: 100Mi
          cpu: 100m
  
  # Sidekiq (background jobs)
  sidekiq:
    replicas: 2
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 2.5Gi
        cpu: 1500m
  
  # Gitaly (Git repository storage)
  gitaly:
    persistence:
      storageClass: longhorn
      size: 100Gi                   # Main Git storage
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
  
  # GitLab Shell (SSH access for Git)
  gitlab-shell:
    service:
      type: LoadBalancer            # Expose SSH via MetalLB
      loadBalancerIP: 192.168.29.151  # Assign IP for SSH
    resources:
      requests:
        memory: 100Mi
        cpu: 100m
  
  # Migrations (database migrations)
  migrations:
    resources:
      requests:
        memory: 200Mi
        cpu: 200m
  
  # Toolbox (maintenance and backup)
  toolbox:
    replicas: 1
    persistence:
      storageClass: longhorn
      size: 10Gi
    resources:
      requests:
        memory: 256Mi
        cpu: 200m

## Registry configuration (Optional - disable if using Harbor)
registry:
  enabled: false                    # Disable to use Harbor instead
  # enabled: true                   # Enable for built-in registry
  # hpa:
  #   minReplicas: 2
  # persistence:
  #   storageClass: longhorn
  #   size: 50Gi

## GitLab Runner configuration
gitlab-runner:
  install: true                     # Install runner with GitLab
  replicas: 2
  runners:
    locked: false
    config: |
      [[runners]]
        [runners.kubernetes]
          namespace = "{{.Release.Namespace}}"
          image = "ubuntu:22.04"
          privileged = false        # Rootless builds
          
          # Resource limits per job
          cpu_limit = "2"
          cpu_request = "500m"
          memory_limit = "4Gi"
          memory_request = "1Gi"
          
          # Use MinIO for cache
          [runners.cache]
            Type = "s3"
            Path = "gitlab-runner"
            Shared = true
            [runners.cache.s3]
              ServerAddress = "{{- include \"gitlab-runner.cache-tpl.s3ServerAddress\" . }}"
              BucketName = "runner-cache"
              BucketLocation = "us-east-1"
              Insecure = false
  
  resources:
    requests:
      memory: 256Mi
      cpu: 100m

## Prometheus monitoring (optional)
prometheus:
  install: false                    # Set to true if you want GitLab Prometheus
  
## Nginx Ingress (use existing one)
nginx-ingress:
  enabled: false                    # Use your existing NGINX

## cert-manager (use existing one)
certmanager:
  install: false                    # Use your existing cert-manager

## Shared secrets configuration
shared-secrets:
  enabled: true                     # Auto-generate secrets
  rbac:
    create: true

EOF
```

### Step 4: Create Initial Root Password Secret

```bash
# Generate strong password
export GITLAB_ROOT_PASSWORD=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password=$GITLAB_ROOT_PASSWORD \
  --namespace=gitlab

# Save password securely
echo "GitLab Root Password: $GITLAB_ROOT_PASSWORD" > ~/gitlab-root-password.txt
chmod 600 ~/gitlab-root-password.txt

echo "Root password saved to ~/gitlab-root-password.txt"
```

### Step 5: Create cert-manager ClusterIssuer (if not exists)

```bash
# Check if ClusterIssuer exists
kubectl get clusterissuer

# If not exists, create one
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@k8s.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Step 6: Configure DNS/Hosts

```bash
# Get MetalLB IP assigned to NGINX Ingress
export INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Add to /etc/hosts on all nodes:"
echo "$INGRESS_IP gitlab.k8s.local"
echo "$INGRESS_IP registry.k8s.local"

# Add to /etc/hosts on master and worker nodes
sudo bash -c "echo '$INGRESS_IP gitlab.k8s.local' >> /etc/hosts"
sudo bash -c "echo '$INGRESS_IP registry.k8s.local' >> /etc/hosts"

# Also add on your local machine for access
```

### Step 7: Deploy GitLab

```bash
# Dry-run first to validate
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values gitlab-custom-values.yaml \
  --dry-run --debug > gitlab-dry-run.yaml

# Check for any errors in dry-run output
less gitlab-dry-run.yaml

# Deploy GitLab (this will take 10-15 minutes)
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values gitlab-custom-values.yaml \
  --timeout 30m

# Watch deployment progress
watch kubectl get pods -n gitlab
```

### Step 8: Monitor Deployment

```bash
# Watch all pods in gitlab namespace
kubectl get pods -n gitlab -w

# Check specific components
kubectl get pods -n gitlab | grep -E 'webservice|sidekiq|gitaly|postgresql|redis'

# Check ingress
kubectl get ingress -n gitlab

# Check services
kubectl get svc -n gitlab
```

Expected pods (will take 10-15 minutes):
```
gitlab-gitaly-0                           1/1     Running
gitlab-gitlab-shell-xxx                   1/1     Running
gitlab-postgresql-0                       2/2     Running
gitlab-redis-master-0                     2/2     Running
gitlab-minio-xxx                          1/1     Running
gitlab-sidekiq-xxx                        1/1     Running
gitlab-webservice-default-xxx             2/2     Running
gitlab-migrations-xxx                     0/1     Completed
gitlab-shared-secrets-xxx                 0/1     Completed
gitlab-toolbox-xxx                        1/1     Running
gitlab-runner-xxx                         1/1     Running
```

### Step 9: Access GitLab

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=webservice \
  -n gitlab \
  --timeout=600s

# Get the root password
kubectl get secret gitlab-initial-root-password \
  -n gitlab \
  -o jsonpath='{.data.password}' | base64 -d

echo ""

# Access GitLab
echo "GitLab URL: https://gitlab.k8s.local"
echo "Username: root"
echo "Password: <password from above>"
```

### Step 10: Initial Configuration

1. **Login to GitLab**
   - URL: https://gitlab.k8s.local
   - Username: `root`
   - Password: From secret

2. **Change Root Password**
   - Click profile icon → Edit Profile → Password
   - Set new secure password

3. **Disable Sign-up** (Security)
   - Admin Area → Settings → General
   - Sign-up restrictions → Sign-up enabled → Uncheck
   - Save changes

4. **Create First Project**
   - Click "New project"
   - Test GitLab functionality

5. **Configure SSH** (Optional)
   ```bash
   # Add your SSH key
   # Profile → SSH Keys → Add new key
   
   # Test SSH connection
   ssh -T git@gitlab.k8s.local -p 22
   ```

## Configuration Guide

### Using Harbor Registry Instead of Built-in

If you want to use your existing Harbor registry:

```yaml
# In gitlab-custom-values.yaml
registry:
  enabled: false                    # Disable GitLab registry

# Then in GitLab UI:
# Admin Area → Settings → CI/CD → Container Registry
# External registry URL: https://harbor.k8s.local
```

Configure in your `.gitlab-ci.yml`:
```yaml
variables:
  CI_REGISTRY: harbor.k8s.local
  CI_REGISTRY_IMAGE: $CI_REGISTRY/library/$CI_PROJECT_NAME
```

### Resource Adjustments

For smaller clusters:
```yaml
gitlab:
  webservice:
    replicas: 1                     # Single replica
    resources:
      requests:
        memory: 1.5Gi
        cpu: 500m
  
  sidekiq:
    replicas: 1
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
```

For production:
```yaml
gitlab:
  webservice:
    replicas: 3                     # More replicas for HA
    hpa:
      minReplicas: 2
      maxReplicas: 10
```

### External PostgreSQL (Optional)

If you have an external PostgreSQL:

```yaml
postgresql:
  install: false                    # Don't install bundled PostgreSQL

global:
  psql:
    host: postgresql.external.com
    port: 5432
    username: gitlab
    database: gitlabhq_production
    password:
      secret: gitlab-postgresql-password
      key: password
```

### External Redis (Optional)

```yaml
redis:
  install: false                    # Don't install bundled Redis

global:
  redis:
    host: redis.external.com
    port: 6379
    password:
      enabled: true
      secret: gitlab-redis-secret
      key: password
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n gitlab

# Describe failing pod
kubectl describe pod <pod-name> -n gitlab

# Check logs
kubectl logs <pod-name> -n gitlab

# Common issues:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. PVC not binding
kubectl get pvc -n gitlab
kubectl describe pvc <pvc-name> -n gitlab
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n gitlab
kubectl describe ingress gitlab-webservice-default -n gitlab

# Check cert-manager
kubectl get certificate -n gitlab
kubectl describe certificate gitlab-gitlab-tls -n gitlab

# Check NGINX ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl logs -n gitlab gitlab-postgresql-0 -c postgresql

# Check PostgreSQL service
kubectl get svc -n gitlab | grep postgresql

# Test connection from toolbox
kubectl exec -it -n gitlab <toolbox-pod> -- \
  gitlab-rake gitlab:db:configure
```

### GitLab Not Accessible

```bash
# 1. Check webservice pods
kubectl get pods -n gitlab -l app=webservice

# 2. Check ingress
kubectl get ingress -n gitlab

# 3. Verify DNS/hosts
nslookup gitlab.k8s.local
ping gitlab.k8s.local

# 4. Check certificate
kubectl get certificate -n gitlab

# 5. Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://gitlab-webservice-default.gitlab.svc.cluster.local:8181
```

## Backup and Restore

### Creating Backups

```bash
# Backup using toolbox
kubectl exec -it -n gitlab <toolbox-pod> -- \
  backup-utility --skip artifacts

# Backups are stored in object storage (MinIO) by default
# Location: gitlab-backups bucket
```

### Restoring from Backup

```bash
# List available backups
kubectl exec -it -n gitlab <toolbox-pod> -- \
  backup-utility --list

# Restore specific backup
kubectl exec -it -n gitlab <toolbox-pod> -- \
  backup-utility --restore -t <timestamp>
```

## Upgrading GitLab

```bash
# Check current version
helm list -n gitlab

# Update Helm repository
helm repo update

# Check available versions
helm search repo gitlab/gitlab --versions | head -10

# Upgrade GitLab
helm upgrade gitlab gitlab/gitlab \
  --namespace gitlab \
  --values gitlab-custom-values.yaml \
  --version <new-version> \
  --timeout 30m

# Monitor upgrade
kubectl get pods -n gitlab -w
```

## Uninstalling GitLab

```bash
# Uninstall Helm release
helm uninstall gitlab -n gitlab

# Delete PVCs (optional - careful, this deletes data!)
kubectl delete pvc -n gitlab --all

# Delete namespace
kubectl delete namespace gitlab
```

## Performance Tuning

### For Better Performance

```yaml
gitlab:
  webservice:
    workerProcesses: 4              # Increase workers
    workerMemoryKillMax: 1500       # Adjust memory limits
    
  sidekiq:
    concurrency: 25                 # More concurrent jobs
    
postgresql:
  primary:
    resources:
      requests:
        memory: 2Gi                 # More memory for DB
        cpu: 1
    
redis:
  master:
    resources:
      requests:
        memory: 1Gi                 # More memory for cache
```

### Enable Object Storage Caching

```yaml
global:
  appConfig:
    object_store:
      enabled: true
      proxy_download: true          # Cache downloads
```

## Monitoring

### Built-in Prometheus

```yaml
prometheus:
  install: true                     # Enable GitLab Prometheus
```

### External Prometheus

If using your own Prometheus:

```yaml
gitlab:
  webservice:
    metrics:
      enabled: true
      port: 8083
      
  sidekiq:
    metrics:
      enabled: true
      port: 8082
```

Then add ServiceMonitors for scraping.

## Next Steps

After deployment:

1. ✅ Configure LDAP/SAML authentication
2. ✅ Set up email notifications (SMTP)
3. ✅ Configure container registry (or use Harbor)
4. ✅ Set up GitLab Pages (optional)
5. ✅ Configure backup schedule
6. ✅ Set up monitoring and alerting
7. ✅ Create groups and projects
8. ✅ Add users or integrate authentication
9. ✅ Configure CI/CD pipelines
10. ✅ Set up GitOps with ArgoCD/Flux

## Summary

You now have:
- ✅ Complete GitLab platform self-hosted
- ✅ Git repository management
- ✅ Issue tracking and project management
- ✅ Built-in CI/CD with runners
- ✅ All data on your infrastructure
- ✅ Integrated with your existing stack
- ✅ Production-ready configuration

**Resource Usage:** ~8-10GB RAM, 4 vCPUs, 75-100GB storage
**Time to Deploy:** 15-20 minutes
**Access:** https://gitlab.k8s.local

---

**Documentation:** https://docs.gitlab.com/charts/
**Support:** GitLab Community Forum
**Version:** GitLab 18.6.0