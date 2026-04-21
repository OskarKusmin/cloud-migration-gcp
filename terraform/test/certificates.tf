resource "google_certificate_manager_certificate" "private" {
  name = "test-private-cert"
  managed {
    domains = ["*.test-private.kood-voyager.com"]
    dns_authorizations = [google_certificate_manager_dns_authorization.private.id]
  }
}

resource "google_certificate_manager_dns_authorization" "private" {
  name   = "test-private-dns-auth"
  domain = "test-private.kood-voyager.com"
}