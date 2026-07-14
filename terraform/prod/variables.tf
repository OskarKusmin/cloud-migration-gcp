variable "environment" {
  description = "Environment name (test or prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID for prod environment"
  type        = string
}

variable "shared_project_id" {
  description = "GCP project ID for shared resources (Artifact Registry)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "<GCP_REGION>"
}

variable "domain" {
  description = "Root domain name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "voyager-prod"
}

variable "zones" {
  description = "Zones for GKE cluster"
  type        = list(string)
  default     = [ "<GCP_REGION>-b", "<GCP_REGION>-c" ]
}

variable "machine_type" {
  description = "Default machine type for node pools"
  type        = string
  default     = "e2-medium"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "postgres"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "postgres"
}

variable "peer_project_id" {
  description = "Project ID of the peer environment (for VPC peering)"
  type        = string
}

variable "peer_cluster_name" {
  description = "Name of the peer environment's cluster (for VPC peering)"
  type        = string
}