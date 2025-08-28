# Terraform · GKE · Helm · CI/CD

Tiny backend service deployed to a public **GKE** cluster using **Terraform**, containerized with **Docker**, shipped via **Helm**, automated by **GitHub Actions**, and scaled via **HPA (CPU)** or **KEDA (requests/sec)**.

## Prerequisites

- CLI: `terraform`, `gcloud`, `kubectl`, `helm`, `docker`
- GCP project with **Kubernetes Engine API** (`container.googleapis.com`) enabled
- Permissions to create GKE and load balancer resources
- (Optional for CI/CD) A GitHub repo with Actions enabled

---

## 1. Run Terraform (create GKE)

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve -var="project_id=<YOUR_PROJECT_ID>"

# Kubeconfig
gcloud container clusters get-credentials demo-ravid-cloud   --zone asia-southeast1-a   --project <YOUR_PROJECT_ID>

kubectl get nodes
```

---

## 2. Build & Push Image Locally

Example uses **GitHub Container Registry (GHCR)**. Replace with Docker Hub if preferred.

```bash
# Login to GHCR (use a GitHub Personal Access Token with "write:packages")
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <your_github_username> --password-stdin

# Build & push
cd app
IMAGE=ghcr.io/<owner>/<repo>:dev
docker build -t $IMAGE .
docker push $IMAGE
```

> If using Docker Hub: `docker login`, set `IMAGE=<dockerhub_user>/<repo>:dev`.

---

## 3. Deploy via Helm

### 3.1 Install Istio (base, control plane, ingress)

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# CRDs
helm upgrade --install istio-base istio/base -n istio-system --create-namespace

# Control plane
helm upgrade --install istiod istio/istiod -n istio-system

# Ingress Gateway (public LoadBalancer, map ports appropriately)
helm upgrade --install istio-ingress istio/gateway -n istio-system   --set service.type=LoadBalancer   --set service.ports[0].name=status-port --set service.ports[0].port=15021 --set service.ports[0].targetPort=15021   --set service.ports[1].name=http2       --set service.ports[1].port=80    --set service.ports[1].targetPort=8080    --set service.ports[2].name=https       --set service.ports[2].port=443   --set service.ports[2].targetPort=8443

# Verify CRDs exist
kubectl get crd | grep -E 'istio.io|gateway.networking'
```

> Istio manifests in this repo are **stubs** for routing. Set `charts/backend/values.yaml -> istio.host` and ensure the Istio ingressgateway above is running if you plan to expose externally.

### 3.2 (Optional) Install KEDA and Prometheus stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack   -n monitoring --create-namespace

helm upgrade --install keda kedacore/keda -n keda --create-namespace
```

### 3.3 Deploy the backend chart

```bash
cd charts/backend
helm upgrade --install backend .   --namespace default --create-namespace   --set image.repository=ghcr.io/<owner>/<repo>   --set image.tag=dev

kubectl -n default get pods

# Quick local probe (optional)
kubectl -n default port-forward svc/backend 8080:80 &
curl -sS http://127.0.0.1:8080/healthz
```

---

## 4. CI/CD: How the GitHub Action Is Triggered

- **Workflow:** `.github/workflows/ci-cd.yml`
- **Triggers:**
  - `push` to `main` affecting `app/**`, `charts/**`, or the workflow file
  - Manual `workflow_dispatch` in the Actions tab
- **Required repo secrets:**
  - `GCP_SA_KEY` — Service Account JSON with GKE deploy permissions
  - `GKE_CLUSTER` — e.g. `demo-ravid-cloud`
  - `GKE_ZONE` — e.g. `asia-southeast1-a`
  - `GCP_PROJECT_ID` — your GCP project id
- **What it does:**
  1. Build Docker image tagged `sha-<commitSHA>` and push to GHCR
  2. Authenticate to GKE
  3. `helm upgrade --install` with that image (immutable tag)

---

## 5. Scaling & Thresholds

This repo supports **either** CPU HPA **or** KEDA (RPS via Prometheus/Istio metrics).

### A. CPU-based HPA (default)

Enable and tune in `charts/backend/values.yaml`:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 60
```

Rendered manifest: `charts/backend/templates/hpa.yaml` (API `autoscaling/v2`).

### B. Requests/sec with KEDA (optional)

```bash
# Install prometheus
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo update

# helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
#   -n monitoring --create-namespace

# Install Keda
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm upgrade --install keda kedacore/keda -n keda --create-namespace

```


---

## Cleanup

```bash
helm uninstall backend -n default || true
cd infra/terraform && terraform destroy -auto-approve -var="project_id=<YOUR_PROJECT_ID>"
```