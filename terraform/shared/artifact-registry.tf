resource "google_artifact_registry_repository" "docker" {
  repository_id = "voyager"
  location = var.region
  format = "DOCKER"
  description = "Docker images for Voyager"
  
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 20
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"    # 7 days
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_artifact_registry_repository" "helm" {
  repository_id = "voyager-helm"
  location = var.region
  format = "DOCKER"
  description = "Helm charts for Voyager"
  depends_on = [google_project_service.apis]
}

