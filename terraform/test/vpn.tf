resource "google_compute_address" "vpn" {
  name = "vpn-static-ip"
  project = var.project_id
  region = var.region
}

resource "google_compute_instance" "vpn" {
  name = "wireguard-vpn"
  machine_type = "e2-micro"
  zone = var.zones[0]
  project = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size = 10
    }
  }

  network_interface {
    subnetwork = module.vpc.subnets_names[0]
    access_config {
      nat_ip = google_compute_address.vpn.address
    }
  }

  can_ip_forward = true

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y wireguard
    
    # Generate server keys
    cd /etc/wireguard
    umask 077
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    
    # Create config (client peer added manually after)
    cat > /etc/wireguard/wg0.conf <<WGCONF
    [Interface]
    PrivateKey = $(cat server_private.key)
    Address = 10.100.0.1/24
    ListenPort = 51820
    PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE
    PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens4 -j MASQUERADE
    WGCONF
    
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
  EOF

  tags = ["vpn-server"]

  depends_on = [ module.vpc ]
}

resource "google_compute_firewall" "vpn_wireguard" {
  name    = "allow-wireguard"
  network = module.vpc.network_name
  project = var.project_id
  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vpn-server"]
}

resource "google_compute_firewall" "vpn_ssh_iap" {
  name    = "allow-ssh-iap"
  network = module.vpc.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["vpn-server"]
}