resource "google_certificate_manager_certificate" "private" {
  name = "prod-private-cert"
  managed {
    domains = ["*.prod-private.kood-voyager.com"]
    dns_authorizations = [google_certificate_manager_dns_authorization.private.id]
  }
}

resource "google_certificate_manager_dns_authorization" "private" {
  name   = "prod-private-dns-auth"
  domain = "prod-private.kood-voyager.com"
}