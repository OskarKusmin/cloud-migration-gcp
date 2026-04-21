module "cloud_nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  project_id = var.project_id
  region = var.region
  router = "voyager-test-router"
  network = module.vpc.network_id
  create_router = true

  depends_on = [ module.vpc ]
}