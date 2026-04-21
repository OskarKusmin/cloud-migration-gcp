resource "google_secret_manager_secret" "db_credentials" {
  secret_id = "voyager-prod-db-credentials"
  project = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_credentials" {
  secret = google_secret_manager_secret.db_credentials.id

  secret_data = jsonencode({
    username = google_sql_user.main.name
    password = random_password.db_password.result
    database = google_sql_database.main.name
    host = google_sql_database_instance.main.private_ip_address
  })
}

resource "google_secret_manager_secret" "jwt_key" {
  secret_id = "voyager-prod-jwt-key"
  project = var.project_id

  replication {
    auto {}
  }

  depends_on = [ google_project_service.apis ]
}

resource "random_password" "jwt_key" {
  length = 32
  special = false
}

resource "google_secret_manager_secret_version" "jwt_key" {
  secret = google_secret_manager_secret.jwt_key.id
  secret_data = random_password.jwt_key.result
}