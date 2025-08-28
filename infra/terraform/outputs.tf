output "cluster_name" {
    value = google_container_cluster.primary.name
}

output "kubeconfig_instructions" {
    value = "Run: gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.location} --project ${var.project_id}"
}