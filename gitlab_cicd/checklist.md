# GitLab CI/CD Quick Start Checklist

## Prerequisites Verification

- [ ] RKE2 Kubernetes cluster is running and accessible
- [ ] kubectl configured and working (`kubectl cluster-info`)
- [ ] Helm 3.x installed (`helm version`)
- [ ] Harbor registry deployed and accessible
- [ ] MetalLB providing load balancer service
- [ ] Longhorn storage class available
- [ ] NGINX Ingress Controller deployed

## Pre-Deployment Information Gathering

### GitLab Information
- [ ] GitLab URL: _________________________________
  - GitLab.com: `https://gitlab.com/`
  - Self-hosted: `https://gitlab.yourdomain.com/`

- [ ] Runner Registration Token: _________________________________
  - Location: GitLab > Settings > CI/CD > Runners > New runner
  - Or: Admin Area > CI/CD > Runners (for self-hosted)

### Harbor Information
- [ ] Harbor URL: _________________________________
  - Example: `harbor.k8s.local`

- [ ] Harbor Admin Credentials
  - Username: _________________________________
  - Password: _________________________________

- [ ] Harbor Project Created: _________________________________
  - Recommended: `library` or `cicd`

### Kubernetes Information
- [ ] Cluster nodes ready: _________________________________
- [ ] Available storage: _________________________________
- [ ] MetalLB IP range: _________________________________

## Deployment Steps

### Step 1: Edit Deployment Script
```bash
# Edit the following variables in deploy-gitlab-runner.sh
nano deploy-gitlab-runner.sh
```

Variables to update:
- [ ] `GITLAB_URL` - Your GitLab instance URL
- [ ] `RUNNER_REGISTRATION_TOKEN` - From GitLab UI
- [ ] `HARBOR_URL` - Your Harbor registry URL
- [ ] `HARBOR_USERNAME` - Harbor admin username (default: admin)
- [ ] `HARBOR_PASSWORD` - Harbor admin password

### Step 2: Make Script Executable
```bash
chmod +x deploy-gitlab-runner.sh
```

### Step 3: Run Deployment Script
```bash
./deploy-gitlab-runner.sh
```

Expected output:
- [ ] Namespace `gitlab-runner` created
- [ ] Harbor secret created
- [ ] RBAC resources created
- [ ] Helm values file generated
- [ ] GitLab Runner installed
- [ ] Runner pod is running

### Step 4: Verify Deployment
```bash
# Check runner pods
kubectl get pods -n gitlab-runner

# Expected: gitlab-runner-xxxxx-xxxx  1/1  Running  0  1m

# Check runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner --tail=50
```

### Step 5: Verify Runner Registration in GitLab
- [ ] Navigate to GitLab > Settings > CI/CD > Runners
- [ ] Verify runner appears with green status indicator
- [ ] Note runner tags and executor type (should be: kubernetes)

## Post-Deployment Configuration

### Step 6: Create Harbor Robot Account for CI/CD
```bash
# Using Harbor UI:
# 1. Go to Harbor UI: https://harbor.k8s.local
# 2. Login as admin
# 3. Navigate to: Projects > library > Robot Accounts
# 4. Click "New Robot Account"
# 5. Name: gitlab-ci
# 6. Expiration: Never
# 7. Permissions: Push, Pull, Delete artifacts
# 8. Save the token
```

- [ ] Robot account created: robot$gitlab-ci
- [ ] Token saved securely: _________________________________

### Step 7: Configure GitLab CI/CD Variables
In GitLab project/group (Settings > CI/CD > Variables):

- [ ] `HARBOR_REGISTRY` = harbor.k8s.local
- [ ] `HARBOR_PROJECT` = library
- [ ] `HARBOR_USERNAME` = robot$gitlab-ci
- [ ] `HARBOR_PASSWORD` = <robot-account-token> (Protected, Masked)

### Step 8: Test with Sample Pipeline

1. Create new repository or use existing one
2. Add `.gitlab-ci.yml`:

```bash
# Copy sample pipeline
cp sample-gitlab-ci.yml /path/to/your/repo/.gitlab-ci.yml
```

3. Create a simple Dockerfile:
```dockerfile
FROM alpine:latest
RUN echo "Hello from GitLab CI/CD + Harbor!" > /hello.txt
CMD ["cat", "/hello.txt"]
```

4. Commit and push:
```bash
git add .gitlab-ci.yml Dockerfile
git commit -m "Add CI/CD pipeline"
git push origin main
```

- [ ] Pipeline triggered in GitLab
- [ ] Build stage completed successfully
- [ ] Test stage completed successfully
- [ ] Image pushed to Harbor (check Harbor UI)

## Verification Checklist

### Runner Health
```bash
# Check runner status
kubectl get pods -n gitlab-runner
kubectl describe pod -n gitlab-runner -l app=gitlab-runner
```

- [ ] Pod is in Running state
- [ ] No restarts or errors
- [ ] Logs show successful registration

### GitLab Integration
- [ ] Runner appears in GitLab UI
- [ ] Runner status is "online" (green)
- [ ] Runner can pick up jobs
- [ ] Test pipeline completes successfully

### Harbor Integration
- [ ] Can push images to Harbor
- [ ] Images appear in Harbor UI
- [ ] Robot account authentication works
- [ ] Harbor vulnerability scanning works (if enabled)

### Network Connectivity
```bash
# Test from runner pod
kubectl exec -it -n gitlab-runner <runner-pod> -- /bin/sh
# Inside pod:
wget -O- https://harbor.k8s.local/api/v2.0/systeminfo
```

- [ ] Runner can reach Harbor registry
- [ ] Runner can reach GitLab instance
- [ ] DNS resolution works correctly

## Monitoring Setup (Optional)

### Step 9: Configure Prometheus Monitoring
```bash
# If using Prometheus, add ServiceMonitor
kubectl apply -f - <<EOF
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
EOF
```

- [ ] ServiceMonitor created
- [ ] Metrics visible in Prometheus
- [ ] Grafana dashboard configured (if applicable)

## Troubleshooting Checklist

If something doesn't work:

### Runner Not Registering
- [ ] Verify registration token is correct
- [ ] Check runner logs: `kubectl logs -n gitlab-runner -l app=gitlab-runner`
- [ ] Verify network connectivity to GitLab
- [ ] Check GitLab URL is correct and accessible

### Harbor Authentication Failures
- [ ] Verify Harbor secret is created correctly
- [ ] Check robot account permissions in Harbor
- [ ] Test Harbor credentials manually
- [ ] Verify Harbor URL is accessible from cluster

### Jobs Not Starting
- [ ] Check runner has available capacity (concurrent setting)
- [ ] Verify runner tags match job requirements
- [ ] Check resource quotas in namespace
- [ ] Review runner configuration in GitLab

### Build Failures
- [ ] Check job logs in GitLab UI
- [ ] Verify Dockerfile is correct
- [ ] Check base image is accessible
- [ ] Verify Harbor authentication in pipeline

## Advanced Configuration Checklist

### For Production Use
- [ ] Configure runner auto-scaling
- [ ] Set up multiple runner groups (fast, build, deploy)
- [ ] Configure build cache with Longhorn PVC
- [ ] Implement network policies
- [ ] Set up pod security policies
- [ ] Configure resource limits appropriately
- [ ] Enable runner metrics monitoring
- [ ] Set up log aggregation
- [ ] Implement secrets management (Sealed Secrets/Vault)
- [ ] Configure backup strategy for runner configuration

### Security Hardening
- [ ] Use Kaniko instead of Docker-in-Docker
- [ ] Implement least-privilege RBAC
- [ ] Enable pod security standards
- [ ] Use network policies to restrict traffic
- [ ] Rotate runner tokens regularly
- [ ] Scan images with Trivy/Clair
- [ ] Enable Harbor vulnerability scanning
- [ ] Use separate robot accounts per project
- [ ] Implement image signing (Cosign/Notary)
- [ ] Configure pod security context

## Maintenance Checklist

### Regular Tasks
- [ ] Check runner health weekly
- [ ] Review failed jobs and logs
- [ ] Update runner version monthly
- [ ] Rotate secrets quarterly
- [ ] Clean up old images from Harbor
- [ ] Monitor resource usage
- [ ] Review and optimize pipeline configurations

### Monthly Tasks
- [ ] Check for GitLab Runner updates
- [ ] Review Harbor storage usage
- [ ] Audit runner access logs
- [ ] Review and optimize cache usage
- [ ] Update base images in pipelines

## Success Criteria

You've successfully deployed GitLab CI/CD when:

✅ Runner appears online in GitLab UI
✅ Test pipeline runs successfully
✅ Images are pushed to Harbor registry
✅ No errors in runner logs
✅ Metrics are being collected (if configured)
✅ Jobs complete within expected timeframes
✅ Harbor authentication works reliably

## Documentation References

- [ ] Main guide: `gitlab-cicd-deployment.md`
- [ ] Kaniko guide: `kaniko-integration-guide.md`
- [ ] Deployment script: `deploy-gitlab-runner.sh`
- [ ] Sample pipeline: `sample-gitlab-ci.yml`

## Next Steps

After successful deployment:

1. **Expand Pipeline Capabilities**
   - Add security scanning (Trivy, SonarQube)
   - Implement automated testing
   - Configure multi-environment deployments
   - Set up automated deployments to Kubernetes

2. **Optimize Performance**
   - Implement build caching
   - Configure runner auto-scaling
   - Optimize Docker image layers
   - Use Kaniko cache repository

3. **Enhance Security**
   - Implement image signing
   - Configure RBAC policies
   - Set up network policies
   - Enable audit logging

4. **Improve Observability**
   - Set up Grafana dashboards
   - Configure alerting rules
   - Implement log aggregation
   - Create SLOs/SLIs

## Support and Resources

- GitLab Runner Documentation: https://docs.gitlab.com/runner/
- Kaniko Project: https://github.com/GoogleContainerTools/kaniko
- Harbor Documentation: https://goharbor.io/docs/
- Kubernetes Best Practices: https://kubernetes.io/docs/concepts/

## Notes Section

Use this space for environment-specific notes:

```
Date: _______________
Deployed by: _______________
Environment: _______________

Notes:
_____________________________________________
_____________________________________________
_____________________________________________
```

---

## Quick Commands Reference

```bash
# Check runner status
kubectl get pods -n gitlab-runner

# View runner logs
kubectl logs -n gitlab-runner -l app=gitlab-runner -f

# Restart runner
kubectl rollout restart deployment/gitlab-runner -n gitlab-runner

# Update runner configuration
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --reuse-values \
  --set concurrent=15

# Check runner metrics
kubectl port-forward -n gitlab-runner svc/gitlab-runner-metrics 9252:9252

# Verify Harbor connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://harbor.k8s.local/api/v2.0/systeminfo

# Clean up failed jobs
kubectl delete pods --field-selector=status.phase==Failed -n gitlab-runner
```

---

**Checklist Version:** 1.0  
**Last Updated:** 2024  
**Compatible with:** GitLab Runner 17.x, Harbor 2.x, Kubernetes 1.27+