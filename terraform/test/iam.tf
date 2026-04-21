# --- External secrets ---

resource "google_service_account" "external_secrets" {
  account_id = "external-secrets"
  display_name = "External Secrets"
  project = var.project_id
}

resource "google_project_iam_member" "external_secrets_accessor" {
  project = var.project_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.external_secrets.email}"
}

resource "google_service_account_iam_member" "external_secrets_wi" {
  service_account_id = google_service_account.external_secrets.name
  role = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# --- External DNS ---

resource "google_service_account" "external_dns" {
  account_id = "external-dns"
  display_name = "External DNS"
  project = var.project_id
}

resource "google_project_iam_member" "external_dns_admin" {
  project = var.project_id
  role = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.external_dns.email}"
}

resource "google_service_account_iam_member" "external_dns_wi" {
  service_account_id = google_service_account.external_dns.name
  role = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[external-dns/external-dns]"
}

# --- Grafana ---

resource "google_service_account" "grafana" {
  account_id = "grafana"
  display_name = "Grafana"
  project = var.project_id
}

resource "google_project_iam_member" "grafana_monitoring_viewer" {
  project = var.project_id
  role = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

resource "google_service_account_iam_member" "grafana_wi" {
  service_account_id = google_service_account.grafana.name
  role = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/kube-prometheus-stack-grafana]"
}

# --- Artifact Registry cross-project access ---

resource "google_project_iam_member" "gke_artifact_registry_reader" {
  project = var.shared_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${module.gke.service_account}"
}