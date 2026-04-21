terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "voyager-tf-state"
    prefix = "prod"
  }

  required_providers {
    google = {
        source = "hashicorp/google"
        version = "~> 6.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region = var.region
  user_project_override = true
}

data "google_client_config" "default" {}

provider "helm" {
  kubernetes {
    host = "https://${module.gke.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

provider "kubernetes" {
  host = "https://${module.gke.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "certificatemanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
  ])

  service = each.value
  disable_on_destroy = false
}