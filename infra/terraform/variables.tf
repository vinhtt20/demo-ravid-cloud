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
    description = "Cluster location (zone or region). Use a zone for a small test cluster."
    type        = string
    default     = "asia-southeast1-a"
}

variable "cluster_name" {
    type    = string
    default = "demo-ravid-cloud"
}

variable "node_count" {
    type    = number
    default = 2
}

variable "machine_type" {
    type    = string
    default = "e2-standard-8"
}