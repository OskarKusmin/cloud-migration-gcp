# IP range for Google-managed services (Private Service Access)
resource "google_compute_global_address" "private_ip_range" {
  name = "google-managed-services"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length = 16
  network = module.vpc.network_id
  project = var.project_id
}

# The peering connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network = module.vpc.network_id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [ google_compute_global_address.private_ip_range.name ]
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "main" {
  name = "${var.cluster_name}-db"
  database_version = "POSTGRES_15"
  region = var.region
  project = var.project_id
  deletion_protection = false
  depends_on = [ google_service_networking_connection.private_vpc_connection ]

  settings {
    tier = var.db_tier
    availability_type = "ZONAL"
    disk_size = 10
    disk_type = "PD_SSD"

    ip_configuration {
      ipv4_enabled = false
      private_network = module.vpc.network_id
    }

    backup_configuration {
      enabled = true
      start_time = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 1

      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day = 7
      hour = 4
    }
  }
}

# The database
resource "google_sql_database" "main" {
  name = var.db_name
  instance = google_sql_database_instance.main.name
  project = var.project_id
}

# Database random password
resource "random_password" "db_password" {
  length = 24
  special = false
}

# Database user
resource "google_sql_user" "main" {
  name = var.db_user
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
  project = var.project_id
}