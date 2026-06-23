module "gke" {
  source            = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version           = "~> 35.0"
  project_id        = var.project_id
  name              = var.cluster_name
  region            = var.region
  zones             = var.zones
  network           = module.vpc.network_name
  subnetwork        = module.vpc.subnets_names[0]
  ip_range_pods     = "pods"
  ip_range_services = "services"

  # Private cluster settings
  enable_private_nodes                 = true
  enable_private_endpoint              = false
  master_global_access_enabled         = true
  master_ipv4_cidr_block               = "172.16.1.0/28"  
  monitoring_enable_managed_prometheus = false

  master_authorized_networks = [
    {
      cidr_block   = ""
      display_name = "Test NAT gateway"
    },
    {
    cidr_block   = ""
    display_name = "Admin access"
    }
  ]

  # Cluster config
  regional = true
  create_service_account   = true
  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 0

  node_pools = [
    {
      name         = "main"
      machine_type = var.machine_type
      min_count    = 1
      max_count    = 2
      disk_size_gb = 30
      disk_type    = "pd-standard"
      auto_upgrade = true
      auto_repair  = true
    },
    {
      name         = "tools"
      machine_type = var.machine_type
      min_count    = 1
      max_count    = 1
      disk_size_gb = 30
      disk_type    = "pd-standard"
      auto_upgrade = true
      auto_repair  = true
    },
    {
      name         = "monitoring"
      machine_type = var.machine_type
      min_count    = 1
      max_count    = 1
      disk_size_gb = 30
      disk_type    = "pd-standard"
      auto_upgrade = true
      auto_repair  = true
    },
  ]

  node_pools_labels = {
    main       = { role = "main" }
    tools      = { role = "tools" }
    monitoring = { role = "monitoring"}
  }

  node_pools_taints = {
    tools = [
      {
        key    = "role"
        value  = "tools"
        effect = "NO_SCHEDULE"
      }
    ]
    monitoring = [
      {
        key    = "role"
        value  = "monitoring"
        effect = "NO_SCHEDULE"
      }
    ]
  }
  depends_on = [ module.vpc, module.cloud_nat ]
}