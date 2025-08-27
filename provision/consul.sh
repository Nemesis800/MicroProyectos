#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl unzip jq gpg

# Instalar Consul (APT oficial HashiCorp)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y && apt-get install -y consul

mkdir -p /etc/consul.d /var/lib/consul

# Server con UI habilitada
cat >/etc/consul.d/server.hcl <<'HCL'
server = true
bootstrap_expect = 1
datacenter = "dc1"
node_name = "consul-server"
bind_addr = "192.168.56.13"
advertise_addr = "192.168.56.13"
client_addr = "0.0.0.0"
ui_config { enabled = true }
HCL

cat >/etc/systemd/system/consul.service <<'UNIT'
[Unit]
Description=Consul Server
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d -data-dir=/var/lib/consul
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now consul

echo "Consul UI => http://localhost:8500/ui/dc1/services"