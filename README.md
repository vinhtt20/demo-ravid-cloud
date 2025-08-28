# Terraform · GKE · Helm · CI/CD

This repo demonstrates a tiny backend service deployed to a small public **GKE** cluster using **Terraform**, containerized with **Docker**, shipped via **Helm**, and automated by **GitHub Actions**. It also shows **scaling** via HPA (CPU) or KEDA (requests/sec).

---

## 1) Run Terraform (create GKE)
Prereqs: `terraform`, `gcloud` installed; GCP project with `container.googleapis.com` enabled.

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve -var="project_id=<YOUR_PROJECT_ID>"
# Kubeconfig
gcloud container clusters get-credentials demo-ravid-cloud   --zone asia-southeast1-a --project <YOUR_PROJECT_ID>
kubectl get nodes
```

---

## 2) Build & Push Image Locally
Example uses **GHCR**; replace with Docker Hub if you prefer.

```bash
# Login once to GHCR (or use Docker Hub instead)
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <your_github_username> --password-stdin

# Build & push
cd app
IMAGE=ghcr.io/<owner>/<repo>:dev
docker build -t $IMAGE .
docker push $IMAGE
```

---

## 3) Deploy via Helm
```bash
# Install Istio CRDs to use Gateway/VirtualService
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# CRDs
helm upgrade --install istio-base istio/base -n istio-system --create-namespace

# Control plane (istiod)
helm upgrade --install istiod istio/istiod -n istio-system

# Ingress Gateway (LoadBalancer đúng port)
helm upgrade --install istio-ingress istio/gateway -n istio-system \
  --set service.type=LoadBalancer \
  --set service.ports[0].name=status-port --set service.ports[0].port=15021 --set service.ports[0].targetPort=15021 \
  --set service.ports[1].name=http2       --set service.ports[1].port=80    --set service.ports[1].targetPort=8080  \
  --set service.ports[2].name=https       --set service.ports[2].port=443   --set service.ports[2].targetPort=8443


# Verify CRDs:
kubectl get crd | grep -E 'istio.io|gateway.networking'

# Install CRDs KEDA:
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm upgrade --install keda kedacore/keda -n keda --create-namespace
```
```bash
cd charts/backend
helm upgrade --install backend .   --namespace default --create-namespace   --set image.repository=ghcr.io/<owner>/<repo>   --set image.tag=dev

kubectl get pods -n default
# Optional quick check (port-forward)
kubectl port-forward svc/backend 8080:80 -n default &
curl -sS http://127.0.0.1:8080/healthz
```

> Istio files are a **stub** for routing. Set `values.yaml -> istio.host` and ensure an Istio ingressgateway exists if you expose externally.

---

## 4) How the GitHub Action is Triggered
Workflow: `.github/workflows/ci-cd.yml`  
**Triggers**:
- `push` to `main` touching `app/**`, `charts/**`, or the workflow itself
- Manual `workflow_dispatch` from the Actions tab

**Required repo secrets**:
- `GCP_SA_KEY` — JSON of a service account with GKE deploy permissions
- `GKE_CLUSTER`, `GKE_ZONE`, `GCP_PROJECT_ID`

**What it does**:
1) Builds and pushes Docker image to GHCR with tag `sha-<commitSHA>`  
2) Authenticates to GKE and runs `helm upgrade --install` with that image

---

## 5) Scaling & Where to Configure Thresholds
### A) CPU-based HPA (default)
Edit `charts/backend/values.yaml`:
```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 60
```
Rendered manifest: `charts/backend/templates/hpa.yaml` (API `autoscaling/v2`).

### B) Requests/sec with KEDA (optional)
Install KEDA and enable Prometheus-backed scaling:
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda -n keda --create-namespace
# Then deploy with KEDA enabled
helm upgrade --install backend ./charts/backend -n default   --set keda.enabled=true   --set keda.prometheus.threshold="10"   --set keda.maxReplicas=10
```
Tune thresholds & query under `values.yaml -> keda.prometheus.*`. Template: `templates/keda-scaledobject.yaml`.

---
## Cleanup
```bash
helm uninstall backend -n default || true
cd infra/terraform && terraform destroy -auto-approve -var="project_id=<YOUR_PROJECT_ID>"
```
