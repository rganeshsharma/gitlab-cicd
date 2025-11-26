# GitLab CI/CD Implementation for Kubernetes

## 📋 Overview

This comprehensive guide provides **TWO implementation options** for GitLab on your RKE2 Kubernetes cluster:

1. **GitLab Runner Only** - Lightweight CI/CD execution (recommended for most users)
2. **Full GitLab Platform** - Complete self-hosted DevOps platform

Both implementations follow industry best practices, integrate with your existing infrastructure (Harbor, Longhorn, MetalLB), and are production-ready.

## 🎯 Choose Your Deployment

### Option 1: GitLab Runner Only (Recommended for most users) ⭐

**What you get:**
- CI/CD pipeline execution on your cluster
- Integration with GitLab.com (or any GitLab instance)
- Kaniko for secure, rootless container builds
- Harbor registry integration

**Resource requirements:**
- RAM: 500MB-2GB
- CPU: 0.5-1 vCPU
- Storage: 10-50GB
- Deployment time: 5 minutes

**Best for:**
- Using GitLab.com for Git hosting
- CI/CD-only needs
- Learning Kubernetes CI/CD
- Resource-constrained environments
- Quick setup required

**📖 Documentation:**
- [Quick Start Guide](gitlab-cicd-deployment.md)
- [Automated Deployment Script](deploy-gitlab-runner.sh)
- [Kaniko Integration](kaniko-integration-guide.md)

### Option 2: Full GitLab Platform

**What you get:**
- Complete self-hosted GitLab (all features)
- Git repository hosting
- Issue tracking and project management
- Merge requests and code review
- Built-in CI/CD (includes runners)
- Wiki and documentation
- Optional container registry
- Complete data sovereignty

**Resource requirements:**
- RAM: 8-12GB (minimum), 16-24GB (recommended)
- CPU: 4-8 vCPU
- Storage: 75-200GB
- Deployment time: 15-20 minutes

**Best for:**
- Complete on-premises solution
- Air-gapped environments
- Enterprise deployments (50+ users)
- Regulatory compliance requirements
- Teams with 5+ paid GitLab.com users (cost savings)

**📖 Documentation:**
- [Full GitLab Deployment Guide](full-gitlab-deployment.md)
- [values.yaml Explanation](values-yaml-explained.md)
- [Deployment Comparison](deployment-comparison.md)

### Need Help Deciding? 

**See [deployment-comparison.md](deployment-comparison.md) for detailed comparison and decision tree**

**Quick decision:**
- Already using GitLab.com? → **Runner Only** ✅
- Need complete data control? → **Full GitLab** ✅
- Limited resources (<8GB)? → **Runner Only** ✅
- Air-gapped environment? → **Full GitLab** ✅
- Learning K8s CI/CD? → **Runner Only** ✅
- 50+ developers? → **Full GitLab** ✅

---

## 🏗️ Architecture

```
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
```

## 🎯 Implementation Strategy

### Recommended Approach: GitLab Runner Only

We're implementing **GitLab Runner** (not full GitLab) because:

1. **Lightweight**: ~500MB-2GB RAM vs 8-12GB for full GitLab
2. **Flexible**: Works with GitLab.com or any self-hosted GitLab instance
3. **Integrated**: Seamlessly uses your existing Harbor registry
4. **Cost-Effective**: No need for additional infrastructure
5. **CNCF-Aligned**: Pure Kubernetes-native approach

### Security: Kaniko over Docker-in-Docker

We use **Kaniko** for container builds because:

- ✅ **Rootless**: No privileged containers required
- ✅ **Secure**: Runs in standard Kubernetes security context
- ✅ **Efficient**: Better caching and layer management
- ✅ **Production-Ready**: Battle-tested by Google and CNCF
- ✅ **Harbor-Compatible**: Works perfectly with your registry

## 📚 Documentation Structure

### Core Documents

1. **[gitlab-cicd-deployment.md](gitlab-cicd-deployment.md)**
   - Complete deployment guide with 10 detailed sections
   - Architecture decisions and rationale
   - Step-by-step installation procedures
   - Advanced configurations and best practices
   - Monitoring, security, and troubleshooting

2. **[kaniko-integration-guide.md](kaniko-integration-guide.md)**
   - Comprehensive Kaniko usage guide
   - Why Kaniko over Docker-in-Docker
   - Integration with Harbor registry
   - Multi-architecture builds
   - Performance optimization techniques

3. **[gitlab-cicd-checklist.md](gitlab-cicd-checklist.md)**
   - Pre-deployment verification checklist
   - Step-by-step deployment checklist
   - Post-deployment validation
   - Troubleshooting checklist
   - Maintenance tasks

### Automation Scripts

4. **[deploy-gitlab-runner.sh](deploy-gitlab-runner.sh)**
   - Automated deployment script
   - Prerequisites checking
   - One-command installation
   - Verification and validation
   - Sample pipeline generation

## 🚀 Quick Start

### Prerequisites

Ensure you have:
- ✅ RKE2 Kubernetes cluster (v1.27+)
- ✅ kubectl configured and working
- ✅ Helm 3.x installed
- ✅ Harbor registry deployed and accessible
- ✅ MetalLB, NGINX Ingress, Longhorn configured

### 3-Step Deployment

#### Step 1: Gather Information

1. **GitLab Registration Token**
   - Go to: GitLab > Settings > CI/CD > Runners
   - Click "New project runner" or "New group runner"
   - Copy the registration token

2. **Harbor Credentials**
   - URL: `harbor.k8s.local` (or your Harbor URL)
   - Username: `admin`
   - Password: Your Harbor admin password

#### Step 2: Configure and Deploy

```bash
# Edit deployment script with your information
nano deploy-gitlab-runner.sh

# Update these variables:
# - GITLAB_URL="https://gitlab.com/"
# - RUNNER_REGISTRATION_TOKEN="your-token-here"
# - HARBOR_URL="harbor.k8s.local"
# - HARBOR_PASSWORD="your-harbor-password"

# Make script executable
chmod +x deploy-gitlab-runner.sh

# Run deployment
./deploy-gitlab-runner.sh
```

#### Step 3: Verify

```bash
# Check runner status
kubectl get pods -n gitlab-runner

# View runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner

# Verify in GitLab UI
# Go to: Settings > CI/CD > Runners
# Your runner should appear with green status
```

## 📖 Detailed Documentation Guide

### For First-Time Users

**Start with:**
1. Read [gitlab-cicd-checklist.md](gitlab-cicd-checklist.md) - Understand prerequisites
2. Follow [gitlab-cicd-deployment.md](gitlab-cicd-deployment.md) Part 1 - Deploy runner
3. Read [kaniko-integration-guide.md](kaniko-integration-guide.md) - Understand builds
4. Use automated script for deployment

### For Experienced Users

**Quick path:**
1. Gather registration token and Harbor credentials
2. Run `deploy-gitlab-runner.sh` with your configuration
3. Reference [gitlab-cicd-deployment.md](gitlab-cicd-deployment.md) for advanced config
4. Use [kaniko-integration-guide.md](kaniko-integration-guide.md) for pipeline templates

## 🎨 Sample Pipeline

Here's a basic pipeline that works with your setup:

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

variables:
  IMAGE_NAME: harbor.k8s.local/library/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --destination $IMAGE_NAME:latest
      --cache=true
  only:
    - main

test:
  stage: test
  image: harbor.k8s.local/library/ubuntu:22.04
  script:
    - echo "Running tests..."
    - apt-get update && apt-get install -y curl
    - make test

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/$CI_PROJECT_NAME $CI_PROJECT_NAME=$IMAGE_NAME:$IMAGE_TAG -n production
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n production
  when: manual
  only:
    - main
```

## 🔧 Configuration Files

### GitLab Runner Helm Values

The deployment creates `gitlab-runner-values.yaml` with:
- Kubernetes executor configuration
- Harbor registry integration
- Resource limits and requests
- Caching configuration
- Security context settings
- Monitoring endpoints

### Required GitLab CI/CD Variables

Configure these in GitLab (Settings > CI/CD > Variables):

| Variable | Value | Protected | Masked |
|----------|-------|-----------|---------|
| `HARBOR_REGISTRY` | `harbor.k8s.local` | ✅ | ❌ |
| `HARBOR_PROJECT` | `library` | ✅ | ❌ |
| `HARBOR_USERNAME` | `robot$gitlab-ci` | ✅ | ❌ |
| `HARBOR_PASSWORD` | `<robot-token>` | ✅ | ✅ |

## 🔐 Security Best Practices

### Implemented Security Features

1. **Rootless Container Builds** (Kaniko)
   - No privileged containers required
   - Runs with standard security context
   - Minimal attack surface

2. **RBAC Controls**
   - Dedicated service account
   - Least-privilege permissions
   - Namespace isolation

3. **Secret Management**
   - Kubernetes secrets for credentials
   - Harbor robot accounts (not admin)
   - Token-based authentication

4. **Network Policies** (Optional)
   - Restrict ingress/egress traffic
   - Isolate runner pods
   - Control registry access

5. **Pod Security Standards**
   - Enforce baseline pod security
   - No root containers
   - ReadOnly root filesystem where possible

## 📊 Monitoring and Observability

### Available Metrics

The runner exposes Prometheus metrics on port 9252:

- `gitlab_runner_jobs_total` - Total jobs processed
- `gitlab_runner_job_duration_seconds` - Job execution time
- `gitlab_runner_failed_jobs_total` - Failed job count
- `gitlab_runner_concurrent_limit` - Concurrent job limit

### Accessing Metrics

```bash
# Port-forward to access metrics
kubectl port-forward -n gitlab-runner svc/gitlab-runner-metrics 9252:9252

# View metrics
curl http://localhost:9252/metrics
```

### Integration with Prometheus

If you have Prometheus running, the deployment includes ServiceMonitor annotations. The runner will be automatically discovered and scraped.

## 🐛 Troubleshooting

### Common Issues

#### 1. Runner Not Registering

**Symptoms:**
- Runner doesn't appear in GitLab UI
- Registration errors in logs

**Solutions:**
```bash
# Check logs
kubectl logs -n gitlab-runner -l app=gitlab-runner

# Verify token
kubectl get secret -n gitlab-runner -o yaml

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://gitlab.com
```

#### 2. Harbor Authentication Failures

**Symptoms:**
- "unauthorized" errors in job logs
- Cannot pull/push images

**Solutions:**
```bash
# Verify Harbor secret
kubectl get secret harbor-registry-secret -n gitlab-runner -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Test Harbor connectivity
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -v https://harbor.k8s.local/api/v2.0/systeminfo

# Recreate secret
kubectl delete secret harbor-registry-secret -n gitlab-runner
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.k8s.local \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --namespace=gitlab-runner
```

#### 3. Job Pods Not Starting

**Symptoms:**
- Jobs stuck in "pending" state
- "Insufficient resources" errors

**Solutions:**
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check namespace quota
kubectl describe quota -n gitlab-runner

# Increase concurrent setting
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --reuse-values \
  --set concurrent=20
```

## 🔄 Maintenance

### Regular Tasks

**Weekly:**
- Review runner logs for errors
- Check failed job patterns
- Monitor resource usage

**Monthly:**
- Update GitLab Runner version
- Rotate Harbor robot account tokens
- Clean up old cache data
- Review and optimize pipelines

### Upgrade Process

```bash
# Update Helm repository
helm repo update

# Check for new versions
helm search repo gitlab/gitlab-runner --versions

# Upgrade runner
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yaml \
  --version 0.61.0

# Verify upgrade
kubectl rollout status deployment/gitlab-runner -n gitlab-runner
```

## 📈 Performance Optimization

### Build Cache Strategy

1. **Kaniko Layer Caching**
   ```yaml
   --cache=true
   --cache-repo=harbor.k8s.local/cache/$CI_PROJECT_NAME
   --cache-ttl=168h
   ```

2. **Persistent Volume for Cache**
   ```bash
   # Create PVC for build cache
   kubectl apply -f - <<EOF
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
   EOF
   ```

3. **Optimize Dockerfile**
   ```dockerfile
   # Copy dependencies first (better caching)
   COPY package*.json ./
   RUN npm ci --only=production
   
   # Then copy application code
   COPY . .
   RUN npm run build
   ```

## 🔗 Integration with Existing Infrastructure

### With Harbor Registry
- ✅ Automatic image push to Harbor
- ✅ Vulnerability scanning integration
- ✅ Robot account authentication
- ✅ Project-based access control

### With Kubernetes Cluster
- ✅ Native Kubernetes executor
- ✅ Longhorn storage for caching
- ✅ MetalLB for service exposure
- ✅ NGINX Ingress for web access

### With Monitoring Stack
- ✅ Prometheus metrics export
- ✅ ServiceMonitor auto-discovery
- ✅ Grafana dashboard templates
- ✅ Alert rule templates

## 🎓 Learning Resources

### Official Documentation
- [GitLab Runner Docs](https://docs.gitlab.com/runner/)
- [Kubernetes Executor](https://docs.gitlab.com/runner/executors/kubernetes.html)
- [Kaniko Project](https://github.com/GoogleContainerTools/kaniko)
- [Harbor Documentation](https://goharbor.io/docs/)

### Best Practices
- [GitLab CI/CD Best Practices](https://docs.gitlab.com/ee/ci/pipelines/pipeline_efficiency.html)
- [Container Image Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

## 🆘 Support and Community

### Getting Help

1. **Review Documentation**
   - Check the comprehensive guides in this repository
   - Review troubleshooting sections

2. **Check Logs**
   ```bash
   kubectl logs -n gitlab-runner -l app=gitlab-runner -f
   ```

3. **Community Resources**
   - GitLab Community Forum
   - Kubernetes Slack
   - CNCF Community

## 📝 Next Steps

After successful deployment:

1. **Expand Pipeline Capabilities**
   - [ ] Add security scanning (Trivy)
   - [ ] Implement automated testing
   - [ ] Configure multi-environment deployments
   - [ ] Set up GitOps with ArgoCD/Flux

2. **Enhance Security**
   - [ ] Implement image signing (Cosign)
   - [ ] Configure network policies
   - [ ] Set up audit logging
   - [ ] Enable pod security policies

3. **Optimize Performance**
   - [ ] Configure auto-scaling runners
   - [ ] Implement distributed caching
   - [ ] Optimize Docker image layers
   - [ ] Set up build parallelization

4. **Improve Observability**
   - [ ] Create Grafana dashboards
   - [ ] Configure alerting rules
   - [ ] Implement log aggregation
   - [ ] Define SLOs/SLIs

## 📄 Document Index

| Document | Purpose | Audience |
|----------|---------|----------|
| `README.md` | Overview and quick start | Everyone |
| `gitlab-cicd-deployment.md` | Complete deployment guide | DevOps/SRE |
| `kaniko-integration-guide.md` | Kaniko usage and optimization | Developers |
| `gitlab-cicd-checklist.md` | Step-by-step deployment checklist | DevOps/SRE |
| `deploy-gitlab-runner.sh` | Automated deployment script | DevOps/SRE |
| `sample-gitlab-ci.yml` | Example pipeline configuration | Developers |

## 🤝 Contributing

This is a living documentation set. As you use and improve your GitLab CI/CD setup:

1. Document any issues and solutions you find
2. Update configuration examples with your learnings
3. Share optimization techniques that work for your use case
4. Contribute back to the community

## 📜 License

This documentation is provided as-is for educational and operational purposes.

## 🎯 Summary

## Summary

### GitLab Runner Only Implementation

You now have a complete, production-ready GitLab Runner implementation that:

- ✅ Follows CNCF and industry best practices
- ✅ Integrates seamlessly with your existing infrastructure  
- ✅ Uses secure, rootless container builds (Kaniko)
- ✅ Provides comprehensive monitoring and observability
- ✅ Scales with your organization's needs
- ✅ Maintains security without sacrificing functionality
- ✅ **Resource efficient: ~2GB RAM, 1 vCPU**
- ✅ **Quick setup: 5 minutes**

### Full GitLab Platform Implementation

Or deploy the complete GitLab platform with:

- ✅ Self-hosted Git repository management
- ✅ Complete DevOps platform (issues, MRs, wiki, CI/CD)
- ✅ 100% data sovereignty and control
- ✅ Enterprise features (LDAP, SAML, compliance)
- ✅ Cost-effective for teams with 5+ users
- ✅ Integrated with your infrastructure stack
- ✅ **Complete platform: ~8-16GB RAM, 4-8 vCPU**
- ✅ **Setup time: 15-20 minutes**

---

## 📦 Complete Documentation Package (11 Files)

**Core Documentation:**
1. **README.md** - This file, overview and quick start
2. **deployment-comparison.md** - Detailed comparison to help you choose
3. **gitlab-cicd-checklist.md** - Step-by-step deployment checklist

**Runner-Only Deployment:**
4. **gitlab-cicd-deployment.md** - Complete runner deployment guide
5. **deploy-gitlab-runner.sh** - Automated deployment script
6. **kaniko-integration-guide.md** - Rootless container builds

**Full GitLab Deployment:**
7. **full-gitlab-deployment.md** - Complete platform deployment
8. **values-yaml-explained.md** - Deep dive into configuration

**Reference Documentation:**
9. **quick-reference.md** - Commands and troubleshooting
10. **architecture-diagrams.md** - Visual architecture guides
11. **technology-comparison.md** - Technology decision rationale

**Start with the deployment script (runner-only), or review the full deployment guide, then build amazing CI/CD pipelines!** 🚀

---

**Version:** 1.0  
**Last Updated:** November 2024  
**Maintainer:** Infrastructure Team  
**Status:** Production Ready ✅