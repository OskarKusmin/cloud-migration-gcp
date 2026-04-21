resource "google_compute_network_peering" "test_to_prod" {
  name         = "test-to-prod"
  network      = module.vpc.network_id
  peer_network = "projects/${var.prod_project_id}/global/networks/voyager-prod"
  
  export_custom_routes = true
  import_custom_routes = true
}