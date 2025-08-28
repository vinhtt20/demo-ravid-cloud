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

resource "google_container_cluster" "primary" {
    name     = var.cluster_name
    location = var.location

    remove_default_node_pool = true
    initial_node_count       = 1

    # Keep it public & simple (no private cluster, no extra IAM/VPC complexity)
    ip_allocation_policy {}
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
}
