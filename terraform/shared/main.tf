terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "voyager-tf-state"
    prefix = "shared"
  }

  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region = var.region  
}

resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}