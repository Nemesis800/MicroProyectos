#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y haproxy

cat >/etc/haproxy/haproxy.cfg <<'HAP'
global
  log /dev/log local0
  maxconn 2048
defaults
  log global
  mode http
  option httplog
  timeout connect 5s
  timeout client  30s
  timeout server  30s
  errorfile 503 /etc/haproxy/errors/503.http

# Resolver: Consul DNS en 192.168.56.13:8600 (VM 'consul')
resolvers consul
  nameserver dns1 192.168.56.13:8600
  accepted_payload_size 8192
  resolve_retries 3
  timeout retry 1s
  hold valid 5s

frontend fe_http
  bind *:80
  default_backend bk_web

backend bk_web
  balance roundrobin
  option httpchk GET /health
  # Descubre servicios 'web' registrados en Consul (usando SRV records para obtener puertos)
  server-template web 5 _web._tcp.service.consul resolvers consul resolve-prefer ipv4 resolve-opts allow-dup-ip check

listen stats
  bind *:8404
  stats enable
  stats uri /haproxy?stats
  stats auth admin:admin
  stats refresh 5s
HAP

mkdir -p /etc/haproxy/errors
cat >/etc/haproxy/errors/503.http <<'EOF'
HTTP/1.0 503 Servicio No Disponible
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<html><body style="font-family:sans-serif">
<h2>Servicio no disponible</h2>
<p>No hay instancias activas. Intenta mas tarde.</p>
<p>ATT: Ivan y Dario.</p>
</body></html>
EOF

systemctl enable --now haproxy
echo "HAProxy listo: http://localhost:8080  |  Stats: http://localhost:8404/haproxy?stats (admin/admin)"