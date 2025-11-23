# GitLab CI/CD Implementation Guide

## Overview

This guide implements GitLab CI/CD using industry best practices for production Kubernetes environments, integrating with the existing infrastructure stack (Harbor, Longhorn, MetalLB, NGINX Ingress).

## 🏗️ Architecture

┌─────────────────────────────────────────────────────────────┐
│                     GitLab (gitlab.com or self-hosted)      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Projects   │  │  Pipelines   │  │   Runners    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Job Execution
                            ▼
┌─────────────────────────────────────────────────────────────┐
│               Kubernetes Cluster (RKE2)                     │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐│
│  │           Namespace: gitlab-runner                     ││
│  │                                                        ││
│  │  ┌──────────────┐      ┌──────────────┐             ││
│  │  │GitLab Runner │──────│  Job Pods    │             ││
│  │  │  Manager     │      │  (Kaniko)    │             ││
│  │  └──────────────┘      └──────────────┘             ││
│  │         │                     │                       ││
│  │         │                     │ Push Images          ││
│  │         │                     ▼                       ││
│  │         │          ┌──────────────────┐             ││
│  │         │          │ Harbor Registry  │             ││
│  │         │          └──────────────────┘             ││
│  │         │                                            ││
│  │         └──────────▶ Longhorn Storage (Cache)       ││
│  │                                                      ││
│  └────────────────────────────────────────────────────────┘│
│                                                              │
│  Supporting Services:                                       │
│  • MetalLB (Load Balancing)                                │
│  • NGINX Ingress (Traffic Routing)                         │
│  • cert-manager (TLS Certificates)                         │
│  • Longhorn (Persistent Storage)                           │
└─────────────────────────────────────────────────────────────┘

## Architecture Decision

### GitLab vs GitLab Runner Deployment Options

**Option 1: Full GitLab Deployment (Recommended for Complete DevOps Platform)**
- Self-hosted Git repository + CI/CD
- Built-in container registry (can integrate with Harbor)
- Issue tracking, merge requests, wiki
- Resource intensive: ~8-12GB RAM minimum

**Option 2: GitLab Runner Only (Recommended for small/dev Use Case)**
- Use GitLab.com or external GitLab instance for repository
- Deploy only runners in small/dev cluster
- Lightweight: ~500MB-2GB RAM per runner
- Integrates with Harbor registry
- **RECOMMENDED** - Best fit for small or Dev infrastructure

## Prerequisites

### Infrastructure Requirements
- ✅ RKE2 Kubernetes cluster (v1.27+)
- ✅ Longhorn storage class configured
- ✅ MetalLB load balancer
- ✅ NGINX Ingress Controller
- ✅ cert-manager for TLS
- ✅ Harbor container registry

### Network Requirements
- Available IP in MetalLB pool for GitLab
- DNS entry or /etc/hosts configuration
- Harbor registry accessible from cluster

### Access Requirements
- GitLab personal access token (if using GitLab.com)
- Harbor admin credentials
- kubectl access to cluster

## Implementation Strategy

We'll implement **Option 2: GitLab Runner** as it:
1. Leverages your existing Harbor registry
2. Minimizes resource footprint
3. Provides flexibility with Git hosting
4. Follows cloud-native best practices
5. Integrates seamlessly with your CNCF stack

---

## Part 1: GitLab Runner Deployment

### Step 1: Create Namespace and Configuration

```bash
# Create dedicated namespace
kubectl create namespace gitlab-runner

# Label namespace for monitoring/policy
kubectl label namespace gitlab-runner \
  name=gitlab-runner \
  component=cicd
```

### Step 2: Obtain GitLab Registration Token

**For GitLab.com:**
1. Navigate to your GitLab group/project
2. Go to Settings → CI/CD → Runners
3. Click "New project runner" or "New group runner"
4. Note the registration token

**For Self-Hosted GitLab:**
1. Admin Area → CI/CD → Runners
2. Note the registration token

### Step 3: Create GitLab Runner Configuration

```bash
# Create values file for Helm deployment
cat > gitlab-runner-values.yaml <<'EOF'
# GitLab Runner Configuration
# Version: Latest stable (17.x)

## GitLab URL
gitlabUrl: https://gitlab.com/  # Change if using self-hosted

## Runner registration token (will be replaced with runner authentication token)
runnerRegistrationToken: "YOUR_REGISTRATION_TOKEN"  # Replace this

## Runner configuration
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "ubuntu:22.04"
        
        # Use Longhorn for build caches
        [[runners.kubernetes.volumes.pvc]]
          name = "runner-cache"
          mount_path = "/cache"
        
        # Resource limits per job
        cpu_limit = "2"
        cpu_request = "500m"
        memory_limit = "4Gi"
        memory_request = "1Gi"
        
        # Service account for builds
        service_account = "gitlab-runner"
        
        # Helper image (contains Git, gitlab-runner scripts)
        helper_image = "gitlab/gitlab-runner-helper:x86_64-latest"
        
        # Privilege mode for Docker-in-Docker
        privileged = false  # Set to true only if needed for Docker builds
        
        # Poll interval
        poll_interval = 3
        
        # Build directory
        builds_dir = "/builds"
        
      [runners.cache]
        Type = "s3"
        Shared = true
        [runners.cache.s3]
          ServerAddress = "s3.amazonaws.com"
          BucketName = "runner-cache"
          Insecure = false

## Resource allocation for runner manager
resources:
  limits:
    memory: 256Mi
    cpu: 200m
  requests:
    memory: 128Mi
    cpu: 100m

## Number of concurrent jobs
concurrent: 10

## Check interval for new jobs
checkInterval: 3

## Runner behavior
logLevel: info
logFormat: json

## RBAC settings
rbac:
  create: true
  serviceAccountName: gitlab-runner

## Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 100
  fsGroup: 65533

## Pod annotations for monitoring
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9252"
  prometheus.io/path: "/metrics"

## Affinity and tolerations
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - gitlab-runner
        topologyKey: kubernetes.io/hostname

## Node selector (optional - adjust for your cluster)
# nodeSelector:
#   kubernetes.io/hostname: k8s-node-1

## Metrics and monitoring
metrics:
  enabled: true
  portName: metrics
  port: 9252

## Session server (for interactive debugging)
sessionServer:
  enabled: false

EOF
```

### Step 4: Deploy GitLab Runner using Helm

```bash
# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io
helm repo update

# Install GitLab Runner
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yaml \
  --version 0.60.0

# Verify deployment
kubectl get pods -n gitlab-runner
kubectl logs -n gitlab-runner -l app=gitlab-runner
```

### Step 5: Create ServiceAccount with Docker Registry Access

```yaml
# Create file: gitlab-runner-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/attach"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gitlab-runner
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: gitlab-runner
---
# Secret for Harbor registry access
apiVersion: v1
kind: Secret
metadata:
  name: harbor-registry-secret
  namespace: gitlab-runner
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: BASE64_ENCODED_DOCKER_CONFIG
```

**Generate Harbor Docker Config:**
```bash
# Create Docker config for Harbor
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.k8s.local \
  --docker-username=admin \
  --docker-password=YOUR_HARBOR_PASSWORD \
  --docker-email=admin@example.com \
  --namespace=gitlab-runner \
  --dry-run=client -o yaml > harbor-secret.yaml

# Apply the secret
kubectl apply -f harbor-secret.yaml
```

### Step 6: Configure Runner for Harbor Integration

Update the runner configuration to use Harbor:

```yaml
# Update gitlab-runner-values.yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "harbor.k8s.local/library/ubuntu:22.04"
        
        # Pull secrets for private registry
        image_pull_secrets = ["harbor-registry-secret"]
        
        # Cache image from Harbor
        helper_image = "harbor.k8s.local/library/gitlab-runner-helper:x86_64-latest"
```

---

## Part 2: Docker-in-Docker (DinD) Setup for Container Builds

### Option A: Docker-in-Docker (Privileged - Less Secure)

```yaml
# gitlab-runner-dind-values.yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "harbor.k8s.local/library/docker:24-dind"
        privileged = true
        
        [[runners.kubernetes.volumes.empty_dir]]
          name = "docker-certs"
          mount_path = "/certs/client"
          medium = "Memory"
        
        [runners.kubernetes.services]
          [[runners.kubernetes.services]]
            name = "docker:24-dind"
            alias = "docker"
            command = ["dockerd-entrypoint.sh"]
```

### Option B: Kaniko (Rootless - More Secure, RECOMMENDED)

```yaml
# gitlab-runner-kaniko-values.yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "harbor.k8s.local/library/ubuntu:22.04"
        privileged = false
        
        # Kaniko doesn't need privileged mode
        [[runners.kubernetes.volumes.secret]]
          name = "harbor-registry-secret"
          mount_path = "/kaniko/.docker"
          read_only = true
```

**Sample .gitlab-ci.yml for Kaniko:**
```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

variables:
  IMAGE_NAME: harbor.k8s.local/library/myapp
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"harbor.k8s.local\":{\"auth\":\"$(echo -n admin:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --destination $IMAGE_NAME:latest
      --cache=true
      --cache-repo=harbor.k8s.local/cache/myapp
  only:
    - main
    - develop
```

---

## Part 3: Integration with Harbor Registry

### Step 1: Create Harbor Project for CI/CD

```bash
# Using Harbor API
curl -X POST "https://harbor.k8s.local/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "project_name": "cicd",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "low",
      "reuse_sys_cve_allowlist": "true"
    }
  }'

# Create robot account for CI/CD
curl -X POST "https://harbor.k8s.local/api/v2.0/robots" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "name": "gitlab-ci",
    "description": "GitLab CI/CD robot account",
    "duration": -1,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "cicd",
        "access": [
          {"resource": "repository", "action": "push"},
          {"resource": "repository", "action": "pull"},
          {"resource": "artifact", "action": "delete"}
        ]
      }
    ]
  }'
```

### Step 2: Configure GitLab CI/CD Variables

In your GitLab project/group:
1. Settings → CI/CD → Variables
2. Add the following variables:

```
HARBOR_REGISTRY=harbor.k8s.local
HARBOR_PROJECT=cicd
HARBOR_USERNAME=robot$gitlab-ci
HARBOR_PASSWORD=<robot-account-token>
KUBECONFIG=<base64-encoded-kubeconfig>
```

---

## Part 4: Sample Pipeline Configurations

### Basic CI/CD Pipeline

```yaml
# .gitlab-ci.yml
image: harbor.k8s.local/library/ubuntu:22.04

stages:
  - build
  - test
  - package
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  KUBECONFIG: /tmp/kubeconfig

before_script:
  - echo $CI_JOB_TOKEN | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY

build:
  stage: build
  script:
    - apt-get update && apt-get install -y build-essential
    - make build
  artifacts:
    paths:
      - build/
    expire_in: 1 hour

test:
  stage: test
  script:
    - apt-get update && apt-get install -y curl
    - make test
  coverage: '/TOTAL.*\s+(\d+%)$/'

package:
  stage: package
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME:$CI_COMMIT_SHORT_SHA
      --destination $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME:latest
      --cache=true
  only:
    - main

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - echo "$KUBECONFIG" | base64 -d > /tmp/kubeconfig
    - kubectl set image deployment/$CI_PROJECT_NAME $CI_PROJECT_NAME=$HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME:$CI_COMMIT_SHORT_SHA -n production
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n production
  only:
    - main
  when: manual
```

### Multi-Environment Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy-dev
  - deploy-staging
  - deploy-prod

.deploy_template: &deploy_template
  image: bitnami/kubectl:latest
  script:
    - echo "$KUBECONFIG" | base64 -d > /tmp/kubeconfig
    - |
      cat <<EOF | kubectl apply -f -
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: $CI_PROJECT_NAME
        namespace: $ENVIRONMENT
      spec:
        replicas: $REPLICAS
        selector:
          matchLabels:
            app: $CI_PROJECT_NAME
        template:
          metadata:
            labels:
              app: $CI_PROJECT_NAME
              version: $CI_COMMIT_SHORT_SHA
          spec:
            imagePullSecrets:
            - name: harbor-registry-secret
            containers:
            - name: $CI_PROJECT_NAME
              image: $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME:$CI_COMMIT_SHORT_SHA
              ports:
              - containerPort: 8080
              env:
              - name: ENVIRONMENT
                value: $ENVIRONMENT
              resources:
                requests:
                  memory: "256Mi"
                  cpu: "250m"
                limits:
                  memory: "512Mi"
                  cpu: "500m"
      EOF
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n $ENVIRONMENT

deploy:dev:
  <<: *deploy_template
  stage: deploy-dev
  variables:
    ENVIRONMENT: development
    REPLICAS: "1"
  only:
    - develop

deploy:staging:
  <<: *deploy_template
  stage: deploy-staging
  variables:
    ENVIRONMENT: staging
    REPLICAS: "2"
  only:
    - main
  when: manual

deploy:prod:
  <<: *deploy_template
  stage: deploy-prod
  variables:
    ENVIRONMENT: production
    REPLICAS: "3"
  only:
    - tags
  when: manual
```

---

## Part 5: Advanced Configuration

### Auto-Scaling Runners

```yaml
# gitlab-runner-autoscale-values.yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        
        # Pod specifications
        [runners.kubernetes.pod_spec]
          node_selector = { "workload" = "ci" }
        
        # Auto-scaling configuration
        [runners.kubernetes.pod_annotations]
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"

concurrent: 20  # Max concurrent jobs

# Resource requests ensure proper scheduling
resources:
  limits:
    memory: 512Mi
    cpu: 500m
  requests:
    memory: 256Mi
    cpu: 250m
```

### Runner Groups for Different Workloads

```yaml
# Deploy multiple runner groups
# Fast runners for quick tests
helm install gitlab-runner-fast gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --set runnerRegistrationToken="TOKEN_1" \
  --set runners.tags="fast\,test" \
  --set concurrent=20

# Heavy runners for builds
helm install gitlab-runner-build gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --set runnerRegistrationToken="TOKEN_2" \
  --set runners.tags="build\,docker" \
  --set concurrent=5 \
  --set resources.limits.memory=8Gi
```

### Cache Configuration with Longhorn

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-cache
  namespace: gitlab-runner
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi
```

---

## Part 6: Monitoring and Observability

### Prometheus Metrics

```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
spec:
  selector:
    matchLabels:
      app: gitlab-runner
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Key Metrics to Monitor

1. **Runner Availability**
   - `gitlab_runner_jobs_total`
   - `gitlab_runner_job_duration_seconds`

2. **Job Success Rate**
   - `gitlab_runner_failed_jobs_total`
   - `gitlab_runner_job_queue_duration_seconds`

3. **Resource Usage**
   - Container CPU/Memory via cAdvisor
   - Node resource pressure

### Logging

```bash
# View runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner -f

# View specific job logs
kubectl logs -n gitlab-runner -l job-name=<job-name>
```

---

## Part 7: Security Best Practices

### 1. Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
spec:
  podSelector:
    matchLabels:
      app: gitlab-runner
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9252
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
  - to:
    - podSelector:
        matchLabels:
          app: harbor
    ports:
    - protocol: TCP
      port: 443
```

### 2. Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gitlab-runner
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Secret Management

**Use Sealed Secrets or External Secrets Operator:**

```bash
# Example with kubeseal
kubectl create secret generic gitlab-runner-secret \
  --from-literal=runner-registration-token=YOUR_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-gitlab-runner-secret.yaml
```

### 4. Runner Token Rotation

```bash
# Script to rotate runner tokens
#!/bin/bash
NEW_TOKEN="new-registration-token"

helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --reuse-values \
  --set runnerRegistrationToken=$NEW_TOKEN

kubectl rollout restart deployment/gitlab-runner -n gitlab-runner
```

---

## Part 8: Troubleshooting

### Common Issues

**1. Runner not registering:**
```bash
# Check runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner

# Verify registration token
kubectl get secret -n gitlab-runner gitlab-runner -o jsonpath='{.data.runner-registration-token}' | base64 -d

# Test connectivity to GitLab
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v https://gitlab.com
```

**2. Docker build failures:**
```bash
# Check if privileged mode is enabled (for DinD)
kubectl get pods -n gitlab-runner -o yaml | grep privileged

# Verify Docker socket
kubectl exec -it -n gitlab-runner <pod-name> -- docker ps
```

**3. Harbor authentication failures:**
```bash
# Verify Harbor secret
kubectl get secret harbor-registry-secret -n gitlab-runner -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Test Harbor connectivity
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- curl -v https://harbor.k8s.local
```

**4. Insufficient resources:**
```bash
# Check resource usage
kubectl top pods -n gitlab-runner

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Scale runner replicas
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --reuse-values \
  --set replicas=3
```

### Debug Mode

```yaml
# Enable debug logging
runners:
  config: |
    [[runners]]
      log_level = "debug"
      log_format = "json"
```

---

## Part 9: Maintenance and Operations

### Backup Runner Configuration

```bash
# Backup Helm values
helm get values gitlab-runner -n gitlab-runner > gitlab-runner-backup.yaml

# Backup secrets
kubectl get secret -n gitlab-runner -o yaml > gitlab-runner-secrets-backup.yaml
```

### Upgrade Process

```bash
# Update Helm repo
helm repo update

# Check for new versions
helm search repo gitlab/gitlab-runner --versions

# Upgrade runner
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yaml \
  --version 0.61.0

# Verify upgrade
helm list -n gitlab-runner
kubectl rollout status deployment/gitlab-runner -n gitlab-runner
```

### Cleanup Old Job Pods

```bash
# Create CronJob to cleanup completed jobs
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-old-jobs
  namespace: gitlab-runner
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: gitlab-runner-cleanup
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              kubectl delete pods --field-selector=status.phase==Succeeded -n gitlab-runner --ignore-not-found=true
              kubectl delete pods --field-selector=status.phase==Failed -n gitlab-runner --ignore-not-found=true
          restartPolicy: OnFailure
```

---

## Part 10: Performance Optimization

### Build Cache Strategy

```yaml
# Use Kaniko cache for faster builds
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        [runners.cache]
          Type = "local"
          Path = "/cache"
          Shared = true
          
        [[runners.kubernetes.volumes.pvc]]
          name = "build-cache"
          mount_path = "/cache"
```

### Parallel Job Execution

```yaml
# .gitlab-ci.yml
test:
  stage: test
  parallel: 5
  script:
    - make test-chunk-${CI_NODE_INDEX}
```

### Resource Optimization

```yaml
# Right-size job resources
test:
  stage: test
  variables:
    KUBERNETES_CPU_REQUEST: "500m"
    KUBERNETES_CPU_LIMIT: "1"
    KUBERNETES_MEMORY_REQUEST: "512Mi"
    KUBERNETES_MEMORY_LIMIT: "1Gi"
```

---

## Summary

### What We've Implemented

1. ✅ GitLab Runner deployment with Kubernetes executor
2. ✅ Harbor registry integration
3. ✅ Kaniko for rootless container builds
4. ✅ Multi-environment CI/CD pipelines
5. ✅ Monitoring and observability
6. ✅ Security best practices
7. ✅ Auto-scaling and resource optimization

### Key Benefits

- **Security**: Rootless builds, network policies, secret management
- **Scalability**: Auto-scaling runners, parallel jobs
- **Reliability**: Longhorn-backed caching, pod anti-affinity
- **Integration**: Seamless Harbor integration, CNCF alignment
- **Maintainability**: Helm-based deployment, comprehensive monitoring

### Next Steps

1. Deploy runner with provided Helm values
2. Configure Harbor integration
3. Create sample pipeline
4. Set up monitoring dashboards
5. Implement security policies
6. Test and validate

### Additional Resources

- GitLab Runner Docs: https://docs.gitlab.com/runner/
- Kaniko Documentation: https://github.com/GoogleContainerTools/kaniko
- Harbor API Reference: https://goharbor.io/docs/
- Kubernetes Executor: https://docs.gitlab.com/runner/executors/kubernetes.html