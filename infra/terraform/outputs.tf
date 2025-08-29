output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "kubeconfig_instructions" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.location} --project ${var.project_id}"
  description = "Run this to populate kubeconfig for kubectl/helm"
}

output "service_account_email" {
  value       = google_service_account.deployer.email
  description = "Service Account used by GitHub Actions"
}

output "workload_identity_provider" {
  value       = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.gh_provider.workload_identity_pool_provider_id}"
  description = "Paste this into google-github-actions/auth as workload_identity_provider"
}

output "artifact_registry_repo_path" {
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
  description = "Base registry path to tag/push images (e.g. asia-southeast1-docker.pkg.dev/PROJECT/backend-images)"
}
