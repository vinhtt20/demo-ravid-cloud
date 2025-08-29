variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources (e.g. asia-southeast1)"
  type        = string
  default     = "asia-southeast1"
}

variable "location" {
  description = "GKE location (zone or regional). Example (zonal): asia-southeast1-a"
  type        = string
  default     = "asia-southeast1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "demo-ravid-cloud"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "GCE machine type for nodes"
  type        = string
  default     = "e2-standard-8"
}

# Artifact Registry
variable "artifact_registry_region" {
  description = "Region for Artifact Registry (must be a region, not a zone). e.g. asia-southeast1"
  type        = string
  default     = "asia-southeast1"
}

variable "artifact_registry_repo" {
  description = "Artifact Registry repository name (Docker format)"
  type        = string
  default     = "backend-images"
}

# Workload Identity Federation (GitHub -> GCP)
variable "github_owner_repo" {
  description = "GitHub repository allowed to assume the service account, in the form <owner>/<repo>"
  type        = string
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "gh-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
  default     = "gh-provider"
}

variable "deploy_sa_name" {
  description = "Service Account name for deployments (short name, without domain)"
  type        = string
  default     = "github-deployer"
}
