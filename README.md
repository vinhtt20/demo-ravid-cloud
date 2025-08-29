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

You can push the image to different registries.  

### A. GitHub Container Registry (GHCR)
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

### B. Google Artifact Registry (GCR / AR)

First, authenticate Docker with Artifact Registry:

```bash
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
```

Then build and push:

```bash
cd app
IMAGE=asia-southeast1-docker.pkg.dev/<PROJECT_ID>/<REPO_NAME>/backend:dev
docker build -t $IMAGE .
docker push $IMAGE
```

- `<PROJECT_ID>` = your GCP project ID (e.g. `optimexdev`)
- `<REPO_NAME>` = Artifact Registry repo created by Terraform (e.g. `backend-images`)
- `backend` = image name (matches your Helm chart values)

---

> In this demo we use **Google Artifact Registry** (`asia-southeast1-docker.pkg.dev/PROJECT/backend-images/backend:<tag>`) as the container registry.

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

### 3.2 Install KEDA and Prometheus stack

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

- **Required GitHub Secrets:**
  - `GCP_PROJECT_ID` — GCP project id
  - `GCP_WIF_PROVIDER` — Workload Identity Provider resource name (Terraform output `workload_identity_provider`)
  - `GKE_CLUSTER` — GKE cluster name (e.g. `demo-ravid-cloud`)
  - `GKE_ZONE` — cluster zone (e.g. `asia-southeast1-a`)
  - `AR_REGION` — Artifact Registry region (e.g. `asia-southeast1`)
  - `AR_REPO` — Artifact Registry repo name (e.g. `backend-images`)

- **What it does:**
  1. Builds Docker image tagged `sha-<commitSHA>` and pushes to **Artifact Registry** (`<region>-docker.pkg.dev/<project>/<repo>/<image>`).
  2. Authenticates to GCP using **Workload Identity Federation** (no JSON key needed).
  3. Gets cluster credentials for GKE.
  4. Runs `helm upgrade --install` to deploy the new image (immutable tag).

---

## 5.  How Scaling Works & Where to Configure Thresholds

This backend can be autoscaled in **two modes**:

## A. CPU-based HPA (default)
- Kubernetes **HorizontalPodAutoscaler (HPA)** is enabled by default.  
- It scales the Deployment up or down based on **CPU utilization percentage**.  
- Configurable in [`charts/backend/values.yaml`](charts/backend/values.yaml):

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 60   # threshold (%)
```

- Rendered into [`charts/backend/templates/hpa.yaml`](charts/backend/templates/hpa.yaml) using the `autoscaling/v2` API.  
- When average CPU > 60%, pods scale up (up to 5).  
- When CPU drops below the target, pods gradually scale down (minimum 1).

## B. Request-per-second with KEDA
- If KEDA and Prometheus are installed, scaling can be driven by **incoming request rate**.  
- The metric used is `istio_requests_total` (exported by Istio proxy sidecars).  
- Configuration lives in [`charts/backend/templates/keda-scaledobject.yaml`](charts/backend/templates/keda-scaledobject.yaml).  

```yaml
triggers:
  - type: prometheus
    metadata:
      serverAddress: http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090
      query: |
        sum(rate(istio_requests_total{
          reporter="destination",
          destination_service=~"backend\.default\.svc\.cluster\.local"
        }[1m]))
      threshold: "5"     # scale up when > 5 RPS
```

- Adjust `threshold` to control **RPS per pod** before scaling occurs.  
- Other knobs:
  - `minReplicaCount` / `maxReplicaCount` — floor & ceiling of scaling.  
  - `pollingInterval` — how often KEDA queries Prometheus (default 30s).  
  - `cooldownPeriod` — how long to wait before scaling down (default 300s).  

### Load Testing
To validate scaling behavior, you can:
- Use [`hey`](https://github.com/rakyll/hey) for simple HTTP load tests (e.g. generate RPS to trigger HPA/KEDA).
```bash
# Load test
hey -z 120s -q 50 -c 20 http://demo-ravid-cloud.duckdns.org/ 
```
- Optionally, use [Gremlin](https://www.gremlin.com/) to run more advanced stress/chaos scenarios (CPU, memory, network) that also trigger scaling events.


## C. Switching between modes
- **CPU HPA** is enabled when `autoscaling.enabled=true`.  
- **KEDA** is active if the `ScaledObject` is deployed (requires Prometheus + KEDA installed).  
- Only enable **one** mode at a time for the same Deployment to avoid conflicts.

---

## Cleanup

```bash
helm uninstall backend -n default || true
cd infra/terraform && terraform destroy -auto-approve -var="project_id=<YOUR_PROJECT_ID>"
```