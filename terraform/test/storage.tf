resource "google_storage_bucket" "logs" {
  name                        = "${var.cluster_name}-logs-${var.project_id}"
  location                    = var.region
  project                     = var.project_id
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  versioning { enabled = true }

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }
}