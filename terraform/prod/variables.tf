variable "project_id" {
  description = "GCP project ID for test environment"
  type = string
}

variable "shared_project_id" {
  description = "GCP project ID for shared resources (Artifact Registry)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type = string
  default = "europe-north1"
}

variable "domain" {
  description = "Root domain name"
  type = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type = string
  default = "voyager-test"
}

variable "zones" {
  description = "Zones for GKE cluster"
  type = list(string)
  default = [ "europe-north1-b" ]
}

variable "machine_type" {
  description = "Default machine type for node pools"
  type = string
  default = "e2-medium"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type = string
  default = "db-f1-micro"
}

variable "db_name" {
  description = "Database name"
  type = string
  default = "postgres"
}

variable "db_user" {
  description = "Database user"
  type = string
  default = "postgres"
}

variable "test_project_id" {
  description = "Test project ID"
  type = string
}