# Kaniko Integration Guide for GitLab CI/CD

## Why Kaniko?

Kaniko is a tool to build container images from a Dockerfile inside a container or Kubernetes cluster **without requiring privileged access** or a Docker daemon. This makes it the recommended approach for production CI/CD systems.

### Kaniko vs Docker-in-Docker (DinD)

| Feature | Kaniko | Docker-in-Docker |
|---------|--------|------------------|
| Security | ✅ Rootless, no privileged mode | ❌ Requires privileged mode |
| Performance | ✅ Efficient layer caching | ⚠️ Can be slower |
| Compatibility | ✅ Pure Kubernetes-native | ⚠️ Requires Docker daemon |
| Resource Usage | ✅ Lower overhead | ❌ Higher overhead |
| Maintenance | ✅ Simpler | ⚠️ More complex |
| **Recommendation** | **RECOMMENDED** | Use only if necessary |

## Prerequisites

1. Harbor registry deployed and accessible
2. GitLab Runner installed on Kubernetes
3. Harbor project created for CI/CD images

## Step 1: Create Harbor Robot Account for Kaniko

```bash
# Create robot account via Harbor API
curl -X POST "https://harbor.k8s.local/api/v2.0/robots" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "name": "kaniko-builder",
    "description": "Robot account for Kaniko image builds",
    "duration": -1,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "library",
        "access": [
          {"resource": "repository", "action": "push"},
          {"resource": "repository", "action": "pull"},
          {"resource": "artifact", "action": "delete"}
        ]
      }
    ]
  }' | jq

# Save the token from the response
```

## Step 2: Configure GitLab CI/CD Variables

In your GitLab project (Settings > CI/CD > Variables), add:

```
# Harbor Configuration
HARBOR_REGISTRY = harbor.k8s.local
HARBOR_PROJECT = library
HARBOR_USERNAME = robot$kaniko-builder
HARBOR_PASSWORD = <robot-account-token>

# Optional: Kaniko specific
KANIKO_CACHE_REPO = harbor.k8s.local/cache
```

## Step 3: Basic Kaniko Pipeline

### Simple Build Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - build

variables:
  IMAGE_NAME: $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

build-image:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    # Create Docker config for authentication
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    # Build and push image
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --destination $IMAGE_NAME:latest
      --cache=true
      --cache-repo=$KANIKO_CACHE_REPO/$CI_PROJECT_NAME
  only:
    - main
    - develop
```

## Step 4: Advanced Kaniko Configuration

### Multi-Stage Build with Cache

```yaml
build-optimized:
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
      --cache-repo=$KANIKO_CACHE_REPO/$CI_PROJECT_NAME
      --cache-ttl=24h
      --compressed-caching=false
      --snapshot-mode=redo
      --build-arg VERSION=$CI_COMMIT_TAG
      --label "ci.commit=$CI_COMMIT_SHA"
      --label "ci.pipeline=$CI_PIPELINE_ID"
  only:
    - main
```

### Build Arguments and Labels

```yaml
build-with-args:
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
      --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
      --build-arg VCS_REF=$CI_COMMIT_SHORT_SHA
      --build-arg VERSION=$CI_COMMIT_TAG
      --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
      --label org.opencontainers.image.revision=$CI_COMMIT_SHA
      --label org.opencontainers.image.version=$CI_COMMIT_TAG
      --label org.opencontainers.image.source=$CI_PROJECT_URL
```

## Step 5: Multi-Architecture Builds

### AMD64 and ARM64 Support

```yaml
build:amd64:
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
      --destination $IMAGE_NAME:$IMAGE_TAG-amd64
      --custom-platform=linux/amd64
  tags:
    - kubernetes
    - amd64

build:arm64:
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
      --destination $IMAGE_NAME:$IMAGE_TAG-arm64
      --custom-platform=linux/arm64
  tags:
    - kubernetes
    - arm64

# Create manifest list
create-manifest:
  stage: package
  image: mplatform/manifest-tool:alpine
  script:
    - manifest-tool push from-args
      --platforms linux/amd64,linux/arm64
      --template $IMAGE_NAME:$IMAGE_TAG-ARCH
      --target $IMAGE_NAME:$IMAGE_TAG
  needs:
    - build:amd64
    - build:arm64
```

## Step 6: Kaniko with Private Base Images

### Using Harbor-hosted Base Images

```dockerfile
# Dockerfile
FROM harbor.k8s.local/library/ubuntu:22.04

RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip3 install -r requirements.txt

COPY . /app
WORKDIR /app

CMD ["python3", "app.py"]
```

```yaml
# .gitlab-ci.yml
build-private-base:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    # Setup authentication for both pull and push
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    # Build with private base image
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --cache=true
```

## Step 7: Kaniko Optimization Techniques

### Build Performance Optimization

```yaml
build-optimized:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  variables:
    # Kaniko performance tuning
    KANIKO_CACHE_ARGS: >
      --cache=true
      --cache-repo=$KANIKO_CACHE_REPO/$CI_PROJECT_NAME
      --cache-ttl=168h
      --cache-run-layers=true
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      $KANIKO_CACHE_ARGS
      --snapshot-mode=redo
      --use-new-run=true
      --compressed-caching=false
      --log-format=text
      --verbosity=info
```

### Layer Caching Strategy

```dockerfile
# Dockerfile optimized for Kaniko caching
FROM harbor.k8s.local/library/node:18-alpine

WORKDIR /app

# Cache dependencies separately
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Build application
RUN npm run build

EXPOSE 3000
CMD ["npm", "start"]
```

## Step 8: Debugging Kaniko Builds

### Debug Mode

```yaml
build-debug:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    # Enable verbose logging
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --verbosity=debug
      --log-format=text
      --no-push  # Don't push for debugging
  when: manual
```

### Common Issues and Solutions

**1. Authentication Failures**
```yaml
# Verify Docker config is correct
script:
  - cat /kaniko/.docker/config.json
  - echo "Testing Harbor connectivity..."
  - wget --spider https://$HARBOR_REGISTRY/v2/
```

**2. Cache Not Working**
```yaml
# Clear cache and rebuild
script:
  - /kaniko/executor
      --cleanup
      --cache=false
      --no-push
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
```

**3. Base Image Pull Failures**
```yaml
# Use skip-tls-verify for self-signed certificates
script:
  - /kaniko/executor
      --skip-tls-verify
      --skip-tls-verify-pull
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
```

## Step 9: Kaniko + Harbor Integration Testing

### Test Pipeline

```yaml
# test-kaniko-harbor.yml
stages:
  - build
  - verify

variables:
  TEST_IMAGE: $HARBOR_REGISTRY/$HARBOR_PROJECT/test-app
  IMAGE_TAG: test-$CI_PIPELINE_ID

build-test:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    # Create simple test Dockerfile
    - |
      cat > Dockerfile <<EOF
      FROM alpine:latest
      RUN echo "Kaniko + Harbor Test" > /test.txt
      CMD ["cat", "/test.txt"]
      EOF
    
    # Build and push
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $TEST_IMAGE:$IMAGE_TAG
      --verbosity=info

verify-image:
  stage: verify
  image: harbor.k8s.local/library/docker:latest
  services:
    - docker:dind
  script:
    - echo "$HARBOR_PASSWORD" | docker login -u "$HARBOR_USERNAME" --password-stdin $HARBOR_REGISTRY
    - docker pull $TEST_IMAGE:$IMAGE_TAG
    - docker run --rm $TEST_IMAGE:$IMAGE_TAG
    - docker rmi $TEST_IMAGE:$IMAGE_TAG
  needs:
    - build-test
```

## Step 10: Production Pipeline Template

### Complete Production-Ready Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - build
  - scan
  - deploy

variables:
  IMAGE_NAME: $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA
  CACHE_REPO: $HARBOR_REGISTRY/cache/$CI_PROJECT_NAME

# Validate Dockerfile
validate:dockerfile:
  stage: validate
  image: hadolint/hadolint:latest-debian
  script:
    - hadolint Dockerfile
  allow_failure: true

# Build with Kaniko
build:image:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    # Setup authentication
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    
    # Build and push
    - |
      /kaniko/executor \
        --context $CI_PROJECT_DIR \
        --dockerfile $CI_PROJECT_DIR/Dockerfile \
        --destination $IMAGE_NAME:$IMAGE_TAG \
        --destination $IMAGE_NAME:latest \
        --cache=true \
        --cache-repo=$CACHE_REPO \
        --cache-ttl=168h \
        --snapshot-mode=redo \
        --use-new-run=true \
        --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --build-arg VCS_REF=$CI_COMMIT_SHORT_SHA \
        --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
        --label org.opencontainers.image.revision=$CI_COMMIT_SHA \
        --label org.opencontainers.image.source=$CI_PROJECT_URL
  only:
    - main
    - develop
    - tags

# Scan image with Trivy
scan:trivy:
  stage: scan
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL $IMAGE_NAME:$IMAGE_TAG
  needs:
    - build:image
  allow_failure: true

# Deploy to Kubernetes
deploy:kubernetes:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/$CI_PROJECT_NAME $CI_PROJECT_NAME=$IMAGE_NAME:$IMAGE_TAG -n production
    - kubectl rollout status deployment/$CI_PROJECT_NAME -n production
  needs:
    - build:image
    - scan:trivy
  only:
    - main
  when: manual
```

## Best Practices Summary

### ✅ Do's

1. **Use Kaniko instead of DinD** for security and simplicity
2. **Enable layer caching** to speed up builds
3. **Use robot accounts** for authentication
4. **Tag images properly** with commit SHA and semantic versions
5. **Add OCI labels** for traceability
6. **Scan images** before deployment
7. **Use multi-stage builds** to minimize image size
8. **Optimize Dockerfile** for caching efficiency

### ❌ Don'ts

1. **Don't use privileged mode** unless absolutely necessary
2. **Don't hardcode credentials** in pipelines
3. **Don't skip image scanning** in production pipelines
4. **Don't use `latest` tag** in production deployments
5. **Don't ignore cache configuration** - it significantly impacts build times

## Troubleshooting Guide

### Issue: Authentication failures

```bash
# Verify Harbor credentials
echo "$HARBOR_PASSWORD" | base64

# Test Harbor API
curl -u "$HARBOR_USERNAME:$HARBOR_PASSWORD" https://$HARBOR_REGISTRY/api/v2.0/projects
```

### Issue: Slow builds

```yaml
# Enable all cache optimizations
--cache=true
--cache-repo=$CACHE_REPO
--cache-ttl=168h
--cache-run-layers=true
--snapshot-mode=redo
--use-new-run=true
```

### Issue: Large image sizes

```dockerfile
# Use multi-stage builds
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o app

FROM alpine:latest
COPY --from=builder /app/app /app
CMD ["/app"]
```

## Monitoring and Metrics

### Track Build Performance

```yaml
# Add timing and metrics
build:image:
  before_script:
    - export BUILD_START=$(date +%s)
  after_script:
    - export BUILD_END=$(date +%s)
    - echo "Build duration: $((BUILD_END - BUILD_START)) seconds"
```

## Conclusion

Kaniko provides a secure, efficient, and Kubernetes-native way to build container images in your CI/CD pipeline. Combined with Harbor registry, you have a complete, production-ready container build and distribution system.

For more information:
- Kaniko GitHub: https://github.com/GoogleContainerTools/kaniko
- Harbor Documentation: https://goharbor.io/docs/
- GitLab CI/CD Docs: https://docs.gitlab.com/ee/ci/