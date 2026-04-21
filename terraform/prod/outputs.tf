output "cluster_name" {
    value = module.gke.name
}

output "cluster_endpoint" {
  value = module.gke.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value = module.gke.ca_certificate
  sensitive = true
}

output "db_private_ip" {
  value = google_sql_database_instance.main.private_ip_address
}

output "db_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "db_credentials_secret" {
  value = google_secret_manager_secret.db_credentials.secret_id
}

output "external_secrets_sa_email" {
  value = google_service_account.external_secrets.email
}

output "external_dns_sa_email" {
  value = google_service_account.external_dns.email
}