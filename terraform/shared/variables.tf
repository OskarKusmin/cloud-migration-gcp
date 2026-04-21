variable "project_id" {
  description = "GCP project ID for shared resources"
  type = string
}

variable "region" {
  description = "GCP region"
  type = string
  default = "europe-north1"
}