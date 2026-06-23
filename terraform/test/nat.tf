module "cloud_nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "~> 5.0"
  project_id    = var.project_id
  region        = var.region
  router        = "${var.cluster_name}-router"
  network       = module.vpc.network_id
  create_router = true
  depends_on    = [ module.vpc ]
}