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

resource "google_container_node_pool" "primary_nodes_bluegreen" {
  count = var.use_blue_green ? 1 : 0

  name     = "default-pool"
  location = var.location
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  upgrade_settings {
    strategy = "BLUE_GREEN"

    blue_green_settings {
      node_pool_soak_duration = var.bg_soak_duration # ví dụ "0s" hoặc "300s"

      standard_rollout_policy {
        # Triển khai theo lô (batch)
        batch_percentage    = var.bg_batch_percentage # 0.5 = 50% mỗi batch
        batch_soak_duration = var.bg_batch_soak       # "0s" hoặc "120s"
      }
    }
  }
  timeouts {
    update = var.update_timeout
  }
}

resource "google_container_node_pool" "primary_nodes_surge" {
  count    = var.use_blue_green ? 0 : 1

  name     = "default-pool"
  location = var.location
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  upgrade_settings {
    max_surge       = var.max_surge
    max_unavailable = var.max_unavailable
  }

  timeouts {
    update = var.update_timeout
  }
}

