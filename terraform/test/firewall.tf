resource "google_compute_firewall" "allow_internal" {
  name = "voyager-test-allow-internal"
  network = module.vpc.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  priority = 1000
}

resource "google_compute_firewall" "allow_health_checks" {
  name = "voyager-test-allow-health-checks"
  network = module.vpc.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  priority = 1000
}