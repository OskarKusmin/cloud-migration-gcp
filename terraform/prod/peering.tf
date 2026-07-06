resource "google_compute_network_peering" "prod_to_test" {
  name         = "prod-to-test"
  network      = module.vpc.network_id
  peer_network = "projects/${var.peer_project_id}/global/networks/voyager-test"

  export_custom_routes = true
  import_custom_routes = true
}