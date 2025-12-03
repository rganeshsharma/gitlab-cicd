# GitLab Deployment: Runner-Only vs Full GitLab

## Decision Guide: Which Should You Deploy?

This document helps you decide between deploying **GitLab Runner only** vs **Full GitLab platform** on your Kubernetes cluster.

---

## Quick Comparison Table

| Aspect | GitLab Runner Only | Full GitLab |
|--------|-------------------|-------------|
| **Purpose** | CI/CD execution only | Complete DevOps platform |
| **Git Hosting** | ❌ Use GitLab.com | ✅ Self-hosted |
| **Issue Tracking** | ❌ Use external | ✅ Built-in |
| **Merge Requests** | ❌ Use external | ✅ Built-in |
| **Wiki** | ❌ Use external | ✅ Built-in |
| **Container Registry** | Use Harbor | Built-in option |
| **RAM Usage** | 500MB-2GB | 8-12GB |
| **CPU Usage** | 0.5-1 vCPU | 4-8 vCPU |
| **Storage** | 10-50GB | 75-200GB |
| **Deployment Time** | 5 minutes | 15-20 minutes |
| **Maintenance** | Low | Medium-High |
| **Complexity** | Simple | Complex |
| **Cost** | Free | Free (OSS) |
| **Data Control** | Code on GitLab.com | 100% On-premises |
| **Best For** | CI/CD only | Complete platform |

---

## Detailed Comparison

### 1. Functionality

#### GitLab Runner Only ✅

**What you get:**
- CI/CD pipeline execution
- Kubernetes-native job execution
- Integration with GitLab.com or any GitLab instance
- Build, test, deploy capabilities
- Kaniko for container builds
- MinIO cache integration

**What you don't get:**
- Git repository hosting
- Issue and project management
- Merge request workflows
- Wiki and documentation hosting
- Built-in package registry
- GitLab Pages

**Use GitLab.com for:**
```
GitLab.com (Free Tier)
├── Unlimited private repositories
├── Issue tracking
├── Merge requests
├── Wiki
├── Project management
└── CI/CD pipeline definitions

Your K8s Cluster (Runner)
├── Execute CI/CD jobs
├── Build containers
├── Run tests
└── Deploy applications
```

#### Full GitLab ✅

**What you get:**
- Everything GitLab Runner provides PLUS:
- Self-hosted Git repositories
- Issue and project management
- Merge request workflows
- Built-in CI/CD pipeline definitions
- Wiki and documentation
- Container registry (optional)
- Package registry
- GitLab Pages
- User management
- Group management
- Access controls

**Complete self-hosted platform:**
```
Your K8s Cluster (Full GitLab)
├── Git repository hosting
├── Issue tracking
├── Merge requests
├── CI/CD execution
├── Wiki
├── User management
├── Container registry (optional)
└── Complete DevOps platform
```

---

### 2. Resource Requirements

#### GitLab Runner Only

```yaml
Namespace: gitlab-runner

Pods:
├── gitlab-runner (manager)
│   ├── CPU: 100m-200m
│   ├── Memory: 128Mi-256Mi
│   └── Storage: Ephemeral
│
└── Job pods (dynamic)
    ├── CPU: 500m-2000m per job
    ├── Memory: 1Gi-4Gi per job
    └── Storage: Cache PVC (50Gi)

Total Minimum:
├── CPU: ~1 vCPU
├── Memory: ~2GB
└── Storage: ~50GB (cache)
```

**Concurrent jobs:** 10-20 with minimal overhead

#### Full GitLab

```yaml
Namespace: gitlab

Core Components:
├── webservice
│   ├── CPU: 1000m × 2 replicas
│   ├── Memory: 2.5Gi × 2 replicas
│   └── Storage: Ephemeral
│
├── sidekiq
│   ├── CPU: 1000m × 2 replicas
│   ├── Memory: 2Gi × 2 replicas
│   └── Storage: Ephemeral
│
├── gitaly
│   ├── CPU: 500m
│   ├── Memory: 1Gi
│   └── Storage: 100Gi (Git repos)
│
├── postgresql
│   ├── CPU: 500m
│   ├── Memory: 512Mi
│   └── Storage: 20Gi
│
├── redis
│   ├── CPU: 100m
│   ├── Memory: 512Mi
│   └── Storage: 5Gi
│
├── minio
│   ├── CPU: 200m
│   ├── Memory: 512Mi
│   └── Storage: 50Gi
│
└── gitlab-runner (included)
    ├── CPU: 100m
    ├── Memory: 256Mi
    └── Storage: Cache in MinIO

Total Minimum:
├── CPU: ~4 vCPU
├── Memory: ~8-10GB
└── Storage: ~180GB

Total Recommended:
├── CPU: ~8 vCPU
├── Memory: ~16-24GB
└── Storage: ~200GB
```

---

### 3. Deployment & Maintenance

#### GitLab Runner Only

**Deployment:**
```bash
# Single script execution
./deploy-gitlab-runner.sh

# Or manual Helm install
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values values.yaml
```

**Time:** 5 minutes

**Components to maintain:**
1. GitLab Runner (1 pod)
2. Job pods (ephemeral)
3. Harbor integration (already have)

**Upgrade process:**
```bash
# Simple Helm upgrade
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --reuse-values
```

**Backup needs:**
- Runner configuration (Helm values)
- Harbor credentials
- Cache data (optional)

#### Full GitLab

**Deployment:**
```bash
# Multiple steps
1. Create namespace
2. Create secrets
3. Configure values.yaml (complex)
4. Deploy with Helm
5. Wait for ~15-20 minutes
6. Verify 10+ pods
7. Configure initial settings
```

**Time:** 15-20 minutes + configuration

**Components to maintain:**
1. GitLab webservice (2-3 pods)
2. Sidekiq (2-3 pods)
3. Gitaly (1 pod)
4. PostgreSQL (1 pod)
5. Redis (1 pod)
6. MinIO (1-3 pods)
7. GitLab Shell (1 pod)
8. Toolbox (1 pod)
9. GitLab Runner (1 pod)
10. Migrations (jobs)

**Upgrade process:**
```bash
# More complex
1. Backup GitLab
2. Review release notes
3. Update values.yaml
4. Run database migrations
5. Helm upgrade
6. Verify all components
7. Test functionality
```

**Backup needs:**
- Git repositories (Gitaly)
- Database (PostgreSQL)
- User uploads (MinIO)
- Configuration (Helm values)
- CI/CD artifacts
- Container registry data (if enabled)

---

### 4. Use Cases

#### GitLab Runner Only - Perfect For:

✅ **You already use GitLab.com**
```
"We host our code on GitLab.com but want to run 
CI/CD on our own infrastructure for security/performance"
```

✅ **CI/CD only needed**
```
"We just need to run automated builds, tests, and 
deployments. We don't need issue tracking or wikis."
```

✅ **Resource constrained**
```
"We have limited cluster resources and want to 
maximize what's available for applications"
```

✅ **Prefer managed Git hosting**
```
"We want GitLab.com's reliability, backups, and 
features, but want control over CI/CD execution"
```

✅ **Multiple GitLab instances**
```
"We work with multiple GitLab instances (gitlab.com, 
client GitLabs) and need a central runner"
```

✅ **Learning/Experimentation**
```
"We're learning Kubernetes CI/CD and want to 
start with something simple"
```

#### Full GitLab - Perfect For:

✅ **Complete data sovereignty**
```
"All our code, issues, and data must stay 
on-premises for compliance/security"
```

✅ **Air-gapped environments**
```
"Our cluster has no internet access. We need 
everything self-hosted."
```

✅ **Enterprise requirements**
```
"We need LDAP/SAML integration, custom workflows, 
and complete control over the platform"
```

✅ **Large teams**
```
"We have 50+ developers and need a complete 
DevOps platform with SSO, groups, and permissions"
```

✅ **Regulatory compliance**
```
"HIPAA, SOC2, or other compliance requires 
self-hosted source control"
```

✅ **Complete platform consolidation**
```
"We want to replace GitHub + Jenkins + Jira 
with a single integrated platform"
```

---

### 5. Cost Analysis

#### GitLab Runner Only

**Infrastructure:**
- Uses 1-2GB RAM (minimal impact)
- 1 vCPU for runner manager
- 50GB storage for cache
- Your existing cluster resources

**External Services:**
- GitLab.com Free tier: Unlimited
- GitLab.com Premium: $29/user/month (optional)

**Total monthly cost:**
- Self-hosted runner: $0
- GitLab.com Free: $0
- **Total: $0/month**

**If using GitLab.com paid:**
- $29/user/month for 10 users = $290/month
- But you get GitLab.com features

#### Full GitLab

**Infrastructure:**
- Uses 8-16GB RAM
- 4-8 vCPU
- 200GB storage
- Backup storage (another 200GB+)

**If using cloud:**
- Small instance: ~$100-200/month
- Medium instance: ~$300-500/month
- Large instance: ~$500-1000/month

**Your cluster (already have):**
- Additional cost: $0/month
- Just using existing resources

**But saves:**
- GitLab.com Premium: $29/user/month
- For 10 users: $290/month saved
- For 50 users: $1,450/month saved

**Total monthly cost:**
- Self-hosted GitLab: $0 (using existing cluster)
- Backup storage: ~$10-20/month (optional)
- **Total: $0-20/month**

**Break-even:**
- If you have >5 paid users, self-hosted is cheaper
- If using free tier, runner-only is more efficient

---

### 6. Network & Security

#### GitLab Runner Only

**Inbound:**
- None required
- Runner polls GitLab.com

**Outbound:**
- GitLab.com API (HTTPS)
- Docker Hub / Harbor (image pull)
- Package registries (npm, pip, etc.)

**Security posture:**
- Code/issues on GitLab.com ⚠️
- CI/CD execution on-premises ✅
- Build artifacts on-premises ✅
- Harbor registry on-premises ✅

**Network diagram:**
```
Internet
   │
   │ HTTPS (polling)
   ▼
Runner ──────────▶ GitLab.com
   │                 (code, pipelines)
   │
   ├──────▶ Harbor (your cluster)
   │         (images)
   │
   └──────▶ Your Apps (your cluster)
             (deployments)
```

#### Full GitLab

**Inbound:**
- HTTPS (443) via Ingress
- SSH (22) via LoadBalancer
- Optional: Custom ports

**Outbound:**
- External package registries (optional)
- Email server (SMTP, optional)
- External integrations (optional)

**Security posture:**
- Code on-premises ✅
- Issues on-premises ✅
- CI/CD on-premises ✅
- Everything on-premises ✅

**Network diagram:**
```
Internet (optional)
   │
   │ HTTPS/SSH
   ▼
GitLab (your cluster)
   ├── Repositories
   ├── Issues
   ├── CI/CD
   ├── Registry
   └── Everything

Completely isolated if desired
```

---

### 7. Scalability

#### GitLab Runner Only

**Horizontal scaling:**
```yaml
# Easy to scale
gitlab-runner:
  replicas: 5              # More runners

  concurrent: 20            # More concurrent jobs per runner
```

**Scales to:**
- 100s of concurrent jobs
- Multiple runner types (fast, build, deploy)
- Cross-cluster runners
- Minimal resource growth

**Limits:**
- GitLab.com API rate limits
- Network bandwidth to GitLab.com

#### Full GitLab

**Horizontal scaling:**
```yaml
# More complex scaling
gitlab:
  webservice:
    replicas: 10           # Scale web tier
    hpa:
      maxReplicas: 20
  
  sidekiq:
    replicas: 5            # Scale background jobs
  
  gitaly:
    # Requires Praefect for HA/scaling
    
  redis:
    architecture: replication
    replicas: 3
    
  postgresql:
    # Requires external DB for HA
```

**Scales to:**
- 1000s of users
- 100s of projects
- TBs of repositories
- Requires careful planning

**Limits:**
- Storage growth (Git repos)
- Database performance
- Network I/O for Git operations

---

### 8. Backup & Disaster Recovery

#### GitLab Runner Only

**What to backup:**
```bash
# 1. Runner configuration
helm get values gitlab-runner -n gitlab-runner > backup.yaml

# 2. Harbor credentials (already backed up with Harbor)

# 3. Cache data (optional, can rebuild)
```

**Recovery time:** <5 minutes
```bash
# Restore
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values backup.yaml
```

**Data loss impact:**
- ⚠️ Pipeline history (on GitLab.com)
- ✅ Cache can rebuild
- ✅ No code loss (on GitLab.com)

#### Full GitLab

**What to backup:**
```bash
# 1. Git repositories (100GB+)
gitlab-rake gitlab:backup:create

# 2. PostgreSQL database
pg_dump gitlabhq_production

# 3. MinIO/Object storage
# All artifacts, uploads, LFS

# 4. Configuration
helm get values gitlab -n gitlab > config.yaml
kubectl get secrets -n gitlab > secrets.yaml
```

**Backup size:** 100GB-1TB+
**Backup frequency:** Daily
**Recovery time:** 1-4 hours

**Data loss impact:**
- ❌ All code (if no backup)
- ❌ All issues (if no backup)
- ❌ All CI/CD history
- ❌ Everything (if no backup)

**Critical:** Must have solid backup strategy

---

## Decision Matrix

### Choose GitLab Runner Only If:

| Criteria | Weight | Runner Only Score |
|----------|--------|-------------------|
| Using GitLab.com already | ⭐⭐⭐⭐⭐ | ✅ Perfect fit |
| Limited cluster resources | ⭐⭐⭐⭐ | ✅ Uses <2GB RAM |
| Simple maintenance needs | ⭐⭐⭐⭐ | ✅ Very simple |
| CI/CD only requirement | ⭐⭐⭐⭐⭐ | ✅ Exactly what it does |
| Quick setup needed | ⭐⭐⭐ | ✅ 5 min deployment |
| Learning Kubernetes CI/CD | ⭐⭐⭐⭐ | ✅ Great for learning |

**Total: Excellent choice**

### Choose Full GitLab If:

| Criteria | Weight | Full GitLab Score |
|----------|--------|-------------------|
| Complete data sovereignty | ⭐⭐⭐⭐⭐ | ✅ 100% on-premises |
| Air-gapped environment | ⭐⭐⭐⭐⭐ | ✅ Can be isolated |
| >5 paid GitLab users | ⭐⭐⭐ | ✅ Cost effective |
| Need all features | ⭐⭐⭐⭐ | ✅ Complete platform |
| Enterprise requirements | ⭐⭐⭐⭐ | ✅ LDAP, SAML, etc. |
| Sufficient resources | ⭐⭐⭐⭐⭐ | ✅ Need 8-16GB RAM |

**Total: Excellent choice**

---

## Migration Path

### Start with Runner, Upgrade to Full Later

```
Phase 1 (Now): Deploy GitLab Runner
├── Use GitLab.com for code
├── Run CI/CD on your cluster
└── Learn Kubernetes + CI/CD

Phase 2 (3-6 months): Evaluate
├── Assess GitLab.com costs
├── Review team's needs
└── Measure resource usage

Phase 3 (If needed): Migrate to Full
├── Deploy Full GitLab
├── Migrate repositories
├── Update CI/CD configurations
└── Decommission runner-only
```

**This approach:**
- ✅ Start simple and fast
- ✅ Learn before committing
- ✅ Evaluate actual needs
- ✅ Migrate if beneficial

### Start with Full, Scale Down if Needed

```
Phase 1 (Now): Deploy Full GitLab
├── Complete platform
├── All features available
└── Team evaluates

Phase 2 (3-6 months): Evaluate
├── Actual usage patterns
├── Resource consumption
└── Feature utilization

Phase 3 (If beneficial): Simplify
├── Move code to GitLab.com
├── Keep runner for CI/CD
└── Reduce resource usage
```

---

## Recommendations by Scenario

### Scenario 1: Startup/Small Team (<10 people)

**Recommendation:** GitLab Runner Only + GitLab.com Free

**Rationale:**
- Free GitLab.com tier is generous
- Minimal infrastructure overhead
- Focus on building product, not DevOps platform
- Easy to upgrade later if needed

**Your setup:**
```
GitLab.com (Free)          Your Cluster
├── Code hosting    ──────▶ GitLab Runner
├── Issues                  ├── CI/CD jobs
├── Merge requests          ├── Deployments
└── Pipelines               └── Harbor registry
```

### Scenario 2: Growing Team (10-50 people)

**Recommendation:** Evaluate both options

**If using GitLab.com Premium already:**
- Consider Full GitLab (save $290+/month)
- Better value with self-hosting

**If using GitLab.com Free:**
- Stick with Runner Only
- Upgrade when you hit free tier limits

### Scenario 3: Enterprise (50+ people)

**Recommendation:** Full GitLab

**Rationale:**
- Cost effective vs GitLab.com Premium ($29/user/month)
- Complete control and customization
- LDAP/SAML integration
- Compliance requirements likely
- You have resources (96GB RAM available)

### Scenario 4: Regulated Industry (Healthcare, Finance)

**Recommendation:** Full GitLab (Air-gapped)

**Rationale:**
- Data sovereignty required
- Compliance mandates
- Audit requirements
- No external dependencies

### Scenario 5: Learning/Lab Environment

**Recommendation:** GitLab Runner Only

**Rationale:**
- Fast setup for learning
- Low resource impact
- Can experiment freely
- Easy to rebuild

---

## Final Recommendation for Your Cluster

**Your situation:**
- 3-node RKE2 cluster
- 96GB RAM total
- Longhorn, Harbor, MetalLB already deployed
- Learning/experimenting phase

### Start with: GitLab Runner Only ✅

**Why:**
1. **Quick win** - Deploy in 5 minutes
2. **Low risk** - Only 2GB RAM
3. **Learn first** - Understand CI/CD on K8s
4. **Easy upgrade** - Can deploy Full GitLab later

**Use the automated script:**
```bash
./deploy-gitlab-runner.sh
```

### Upgrade to Full GitLab when:

1. **You need** complete data sovereignty
2. **You have** 5+ paid GitLab users
3. **You want** on-premises Git hosting
4. **You've learned** K8s CI/CD basics

**Then use:**
```bash
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values gitlab-custom-values.yaml
```

---

## Quick Decision Tree

```
Do you REQUIRE on-premises Git hosting?
├─ YES → Deploy Full GitLab
└─ NO
   │
   Do you have >10 paid GitLab.com users?
   ├─ YES → Consider Full GitLab (cost savings)
   └─ NO
      │
      Is this for learning/experimentation?
      ├─ YES → Deploy Runner Only ✅
      └─ NO
         │
         Do you have <8GB free RAM?
         ├─ YES → Deploy Runner Only ✅
         └─ NO → Either option works
                  (Start with Runner Only)
```

---

## Documentation Reference

| Document | For Runner Only | For Full GitLab |
|----------|----------------|-----------------|
| `README.md` | ✅ | ✅ |
| `deploy-gitlab-runner.sh` | ✅ | ❌ |
| `gitlab-cicd-deployment.md` | ✅ | ⚠️ Runner section |
| `full-gitlab-deployment.md` | ❌ | ✅ |
| `values-yaml-explained.md` | ❌ | ✅ |
| `kaniko-integration-guide.md` | ✅ | ✅ |
| `quick-reference.md` | ✅ | ⚠️ Mostly runner |
| `technology-comparison.md` | ✅ | ✅ |

---

## Summary

**GitLab Runner Only:**
- ✅ Simple, fast, lightweight
- ✅ Perfect for CI/CD on K8s
- ✅ Great with GitLab.com
- ✅ Low maintenance
- ⚠️ No self-hosted Git

**Full GitLab:**
- ✅ Complete DevOps platform
- ✅ Total data control
- ✅ All features included
- ✅ Cost-effective at scale
- ⚠️ More resource intensive
- ⚠️ Higher maintenance

**Your best path:**
1. Start with Runner Only (5 min setup)
2. Use GitLab.com for Git hosting
3. Run CI/CD on your cluster
4. Evaluate needs after 3-6 months
5. Upgrade to Full GitLab if beneficial

**Both are excellent choices - it depends on your specific needs!**