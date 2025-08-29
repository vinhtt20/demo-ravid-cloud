variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "location" {
  description = "Cluster location (zone or region). Use a zone for small test clusters."
  type        = string
  default     = "asia-southeast1-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "demo-ravid-cloud"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for the GKE nodes"
  type        = string
  default     = "e2-standard-8"
}

variable "disk_type" {
  description = "Disk type for nodes: pd-standard | pd-ssd | pd-balanced"
  type        = string
  default     = "pd-standard"
}

variable "disk_size_gb" {
  description = "Disk size (in GB) for each node"
  type        = number
  default     = 100
}

variable "deletion_protection" {
  description = "Enable/disable deletion protection for the cluster"
  type        = bool
  default     = false
}

# --- Rollout strategy selection ---
variable "use_blue_green" {
  description = "true = BLUE_GREEN rollout; false = SURGE rollout"
  type        = bool
  default     = true
}

# BLUE_GREEN tuning
variable "bg_soak_duration" {
  description = "Soak duration between Blue/Green phases, e.g., '0s' or '300s'"
  type        = string
  default     = "0s"
}

variable "bg_batch_percentage" {
  description = "Batch percentage for BLUE_GREEN rollout [0..1], e.g., 0.5 = 50% per batch"
  type        = number
  default     = 0.5
}

variable "bg_batch_soak" {
  description = "Soak duration between batches in BLUE_GREEN rollout, e.g., '0s' or '120s'"
  type        = string
  default     = "0s"
}

# SURGE tuning
variable "max_surge" {
  description = "Number of extra nodes to add temporarily during SURGE upgrades"
  type        = number
  default     = 1
}

variable "max_unavailable" {
  description = "Number of nodes that can be unavailable during SURGE upgrades"
  type        = number
  default     = 0
}

# Timeouts
variable "update_timeout" {
  description = "Timeout for updating node pool (changing machine/disk may take a long time)"
  type        = string
  default     = "90m"
}
