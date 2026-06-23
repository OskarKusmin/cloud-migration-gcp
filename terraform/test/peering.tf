resource "google_compute_network_peering" "test_to_prod" {
  name                 = "${var.environment}-to-peer"
  network              = module.vpc.network_id
  peer_network         = "projects/${var.peer_project_id}/global/networks/${var.peer_cluster_name}"
  export_custom_routes = true
  import_custom_routes = true
}