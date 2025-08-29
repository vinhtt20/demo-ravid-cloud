#############################
# Terraform + Provider
#############################
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {
  project_id = var.project_id
}

#############################
# Enable Required APIs
#############################
resource "google_project_service" "enable_container" {
  project = var.project_id
  service = "container.googleapis.com"
}

resource "google_project_service" "enable_artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "enable_iamcredentials" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"
}

# Often useful in GKE contexts
resource "google_project_service" "enable_compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

#############################
# GKE Cluster (simple public)
#############################
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.location

  # avoid legacy default pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # use default VPC/subnet; no private cluster to keep it simple
  ip_allocation_policy {}

  depends_on = [
    google_project_service.enable_container,
    google_project_service.enable_compute
  ]
}

resource "time_sleep" "wait_for_cluster_ops" {
  depends_on      = [google_container_cluster.primary]
  create_duration = "180s"
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "default-pool"
  location = var.location
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  depends_on = [time_sleep.wait_for_cluster_ops]
}

#############################
# Artifact Registry (Docker)
#############################
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.artifact_registry_region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  description   = "Docker images for backend service"

  depends_on = [google_project_service.enable_artifactregistry]
}

#############################
# Service Account for GitHub Actions (deployments)
#############################
resource "google_service_account" "deployer" {
  account_id   = var.deploy_sa_name
  display_name = "GitHub Actions deployer"
}

# Broad GKE project-level permissions (simple for demo).
# For stricter least-privilege, scope to specific cluster or bind GKE RBAC instead.
resource "google_project_iam_binding" "deployer_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  members = [
    "serviceAccount:${google_service_account.deployer.email}",
  ]
}

# Allow push/pull to Artifact Registry Docker repo
resource "google_artifact_registry_repository_iam_member" "repo_writer" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

#############################
# Workload Identity Federation (GitHub OIDC)
#############################
resource "google_iam_workload_identity_pool" "gh_pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions Pool"
  description               = "OIDC pool for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "gh_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id

  display_name = "GitHub OIDC Provider"
  description  = "Trust GitHub Actions OIDC tokens"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }
  attribute_condition = "attribute.repository == \"${var.github_owner_repo}\" && attribute.ref == \"refs/heads/main\""
}

# Permit ONLY the specific GitHub repo to impersonate this service account via WIF
resource "google_service_account_iam_binding" "allow_wif" {
  service_account_id = google_service_account.deployer.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id}/attribute.repository/${var.github_owner_repo}"
  ]
}
