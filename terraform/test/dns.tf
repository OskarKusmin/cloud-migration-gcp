resource "google_dns_managed_zone" "public" {
  name = "test-public"
  dns_name = "test-public.${var.domain}."
  description = "Public DNS zone for test environment"
  project = var.project_id
  visibility = "public"

  depends_on = [ google_project_service.apis ]
}

resource "google_dns_managed_zone" "private" {
  name = "test-private"
  dns_name = "test-private.${var.domain}."
  description = "Private DNS zone for test environment"
  project = var.project_id
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = module.vpc.network_id
    }
  }

  depends_on = [ google_project_service.apis ]
}

resource "google_dns_record_set" "db" {
  name = "db.test-private.${var.domain}."
  type = "A"
  ttl = 300
  managed_zone = google_dns_managed_zone.private.name
  project = var.project_id
  rrdatas = [ google_sql_database_instance.main.private_ip_address ]
}