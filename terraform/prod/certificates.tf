resource "google_certificate_manager_certificate" "private" {
  name = "${var.environment}-private-cert"
  managed {
    domains            = ["*.${var.environment}-private.${var.domain}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.private.id]
  }
}

resource "google_certificate_manager_dns_authorization" "private" {
  name   = "${var.environment}-private-dns-auth"
  domain = "${var.environment}-private.${var.domain}"
}