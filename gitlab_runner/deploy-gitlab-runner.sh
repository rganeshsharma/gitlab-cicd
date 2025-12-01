#!/bin/bash
# GitLab CI/CD Runner Deployment Script
# This script automates the deployment of GitLab Runner on Kubernetes

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables (EDIT THESE)
GITLAB_URL="https://gitlab.com/"
RUNNER_REGISTRATION_TOKEN=""  # Get from GitLab Settings > CI/CD > Runners
HARBOR_URL="harbor.k8s.local"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"
NAMESPACE="gitlab-runner"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install helm."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    print_info "Prerequisites check passed!"
}

# Function to create namespace
create_namespace() {
    print_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warn "Namespace $NAMESPACE already exists."
    else
        kubectl create namespace $NAMESPACE
        kubectl label namespace $NAMESPACE name=$NAMESPACE component=cicd
        print_info "Namespace created successfully."
    fi
}

# Function to create Harbor secret
create_harbor_secret() {
    print_info "Creating Harbor registry secret..."
    
    if kubectl get secret harbor-registry-secret -n $NAMESPACE &> /dev/null; then
        print_warn "Harbor secret already exists. Deleting and recreating..."
        kubectl delete secret harbor-registry-secret -n $NAMESPACE
    fi
    
    kubectl create secret docker-registry harbor-registry-secret \
        --docker-server=$HARBOR_URL \
        --docker-username=$HARBOR_USERNAME \
        --docker-password=$HARBOR_PASSWORD \
        --docker-email=admin@example.com \
        --namespace=$NAMESPACE
    
    print_info "Harbor secret created successfully."
}

# Function to create RBAC resources
create_rbac() {
    print_info "Creating RBAC resources..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitlab-runner
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/attach"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gitlab-runner
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: $NAMESPACE
EOF
    
    print_info "RBAC resources created successfully."
}

# Function to create Helm values file
create_helm_values() {
    print_info "Creating Helm values file..."
    
    cat > gitlab-runner-values.yaml <<EOF
# GitLab Runner Helm Values
gitlabUrl: $GITLAB_URL
runnerRegistrationToken: "$RUNNER_REGISTRATION_TOKEN"

runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "ubuntu:22.04"
        privileged = false
        
        # Pull secrets for Harbor
        image_pull_secrets = ["harbor-registry-secret"]
        
        # Resource limits per job
        cpu_limit = "2"
        cpu_request = "500m"
        memory_limit = "4Gi"
        memory_request = "1Gi"
        
        # Service account
        service_account = "gitlab-runner"
        
        # Helper image
        helper_image = "gitlab/gitlab-runner-helper:x86_64-latest"
        
        # Build settings
        poll_interval = 3
        builds_dir = "/builds"
        
        # Volume for build cache
        [[runners.kubernetes.volumes.empty_dir]]
          name = "build-cache"
          mount_path = "/cache"
          medium = "Memory"

# Resource allocation for runner manager
resources:
  limits:
    memory: 256Mi
    cpu: 200m
  requests:
    memory: 128Mi
    cpu: 100m

# Concurrent jobs
concurrent: 10
checkInterval: 3

# Logging
logLevel: info
logFormat: json

# RBAC
rbac:
  create: false
  serviceAccountName: gitlab-runner

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 100
  fsGroup: 65533

# Pod annotations for monitoring
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9252"
  prometheus.io/path: "/metrics"

# Metrics
metrics:
  enabled: true
  portName: metrics
  port: 9252

# Anti-affinity for HA
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
EOF
    
    print_info "Helm values file created: gitlab-runner-values.yaml"
}

# Function to add Helm repository
add_helm_repo() {
    print_info "Adding GitLab Helm repository..."
    
    helm repo add gitlab https://charts.gitlab.io
    helm repo update
    
    print_info "Helm repository added and updated."
}

# Function to install GitLab Runner
install_runner() {
    print_info "Installing GitLab Runner..."
    
    if helm list -n $NAMESPACE | grep -q gitlab-runner; then
        print_warn "GitLab Runner already installed. Upgrading..."
        helm upgrade gitlab-runner gitlab/gitlab-runner \
            --namespace $NAMESPACE \
            --values gitlab-runner-values.yaml
    else
        helm install gitlab-runner gitlab/gitlab-runner \
            --namespace $NAMESPACE \
            --values gitlab-runner-values.yaml \
            --version 0.60.0
    fi
    
    print_info "GitLab Runner installation completed."
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying deployment..."
    
    echo ""
    print_info "Waiting for runner pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=gitlab-runner -n $NAMESPACE --timeout=300s
    
    echo ""
    print_info "Runner pods:"
    kubectl get pods -n $NAMESPACE -l app=gitlab-runner
    
    echo ""
    print_info "Runner logs (last 20 lines):"
    kubectl logs -n $NAMESPACE -l app=gitlab-runner --tail=20
    
    echo ""
    print_info "Runner service:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    print_info "Runner secrets:"
    kubectl get secrets -n $NAMESPACE
}

# Function to create sample pipeline
create_sample_pipeline() {
    print_info "Creating sample GitLab CI/CD pipeline..."
    
    cat > sample-gitlab-ci.yml <<'EOF'
# Sample GitLab CI/CD Pipeline
# Place this file as .gitlab-ci.yml in your repository root

image: ubuntu:22.04

stages:
  - build
  - test
  - package

variables:
  HARBOR_REGISTRY: harbor.k8s.local
  HARBOR_PROJECT: library
  IMAGE_NAME: $HARBOR_REGISTRY/$HARBOR_PROJECT/$CI_PROJECT_NAME
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

before_script:
  - apt-get update -qq

build:
  stage: build
  script:
    - echo "Building application..."
    - apt-get install -y build-essential
    - echo "Build completed successfully!"
  artifacts:
    paths:
      - build/
    expire_in: 1 hour

test:
  stage: test
  script:
    - echo "Running tests..."
    - apt-get install -y curl
    - echo "Tests passed!"

package:
  stage: package
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  script:
    - echo "Building Docker image with Kaniko..."
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$HARBOR_REGISTRY\":{\"auth\":\"$(echo -n $HARBOR_USERNAME:$HARBOR_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $IMAGE_NAME:$IMAGE_TAG
      --destination $IMAGE_NAME:latest
      --cache=true
      --cache-repo=$HARBOR_REGISTRY/cache/$CI_PROJECT_NAME
  only:
    - main
    - develop
EOF
    
    print_info "Sample pipeline created: sample-gitlab-ci.yml"
}

# Function to display post-installation instructions
post_install_instructions() {
    echo ""
    echo "=========================================="
    print_info "GitLab Runner Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Verify runner registration in GitLab:"
    echo "   - Go to: $GITLAB_URL (your project/group)"
    echo "   - Navigate to: Settings > CI/CD > Runners"
    echo "   - You should see your runner listed"
    echo ""
    echo "2. Create a sample repository and add the pipeline:"
    echo "   - Copy sample-gitlab-ci.yml to your repository as .gitlab-ci.yml"
    echo "   - Commit and push to trigger the pipeline"
    echo ""
    echo "3. Monitor runner logs:"
    echo "   kubectl logs -n $NAMESPACE -l app=gitlab-runner -f"
    echo ""
    echo "4. Check runner status:"
    echo "   kubectl get pods -n $NAMESPACE"
    echo ""
    echo "5. Access runner metrics (if Prometheus is configured):"
    echo "   kubectl port-forward -n $NAMESPACE svc/gitlab-runner-metrics 9252:9252"
    echo ""
    echo "For more information, see: gitlab-cicd-deployment.md"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "GitLab Runner Deployment Script"
    echo "=========================================="
    echo ""
    
    # Check if registration token is provided
    if [ -z "$RUNNER_REGISTRATION_TOKEN" ]; then
        print_error "RUNNER_REGISTRATION_TOKEN is not set!"
        echo ""
        echo "Please edit this script and set your GitLab runner registration token."
        echo "You can find it at: GitLab > Settings > CI/CD > Runners > New runner"
        echo ""
        exit 1
    fi
    
    check_prerequisites
    create_namespace
    create_harbor_secret
    create_rbac
    create_helm_values
    add_helm_repo
    install_runner
    verify_deployment
    create_sample_pipeline
    post_install_instructions
}

# Run main function
main