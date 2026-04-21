resource "google_dns_managed_zone" "public" {
  name = "prod-public"
  dns_name = "prod-public.${var.domain}."
  description = "Public DNS zone for production environment"
  project = var.project_id
  visibility = "public"

  depends_on = [ google_project_service.apis ]
}

resource "google_dns_managed_zone" "private" {
  name = "prod-private"
  dns_name = "prod-private.${var.domain}."
  description = "Private DNS zone for production environment"
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
  name = "db.prod-private.${var.domain}."
  type = "A"
  ttl = 300
  managed_zone = google_dns_managed_zone.private.name
  project = var.project_id
  rrdatas = [ google_sql_database_instance.main.private_ip_address ]
}