resource "google_dns_managed_zone" "public" {
  name        = "${var.environment}-public"
  dns_name    = "${var.environment}-public.${var.domain}."
  description = "Public DNS zone for ${var.environment} environment"
  project     = var.project_id
  visibility  = "public"
  depends_on  = [ google_project_service.apis ]
}

resource "google_dns_managed_zone" "private" {
  name        = "${var.environment}-private"
  dns_name    = "${var.environment}-private.${var.domain}."
  description = "Private DNS zone for ${var.environment} environment"
  project     = var.project_id
  visibility  = "private"
  private_visibility_config {
    networks { network_url = module.vpc.network_id }
  }
  depends_on  = [ google_project_service.apis ]
}

resource "google_dns_record_set" "db" {
  name         = "db.${var.environment}-private.${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.private.name
  project      = var.project_id
  rrdatas      = [ google_sql_database_instance.main.private_ip_address ]
}