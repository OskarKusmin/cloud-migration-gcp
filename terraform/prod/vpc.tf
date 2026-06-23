module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 10.0"
  project_id   = var.project_id
  network_name = var.cluster_name
  routing_mode = "REGIONAL"
  subnets      = [{
    subnet_name           = "private"
    subnet_ip             = "10.16.0.0/20"
    subnet_region         = var.region
    subnet_private_access = true
  }]

  secondary_ranges = {
    private = [
      {
        range_name = "pods"
        ip_cidr_range = "10.20.0.0/14"
      },
      {
        range_name = "services"
        ip_cidr_range = "10.24.0.0/20"
      }
    ]
  }

  depends_on = [ google_project_service.apis ]
}