#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y haproxy curl

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
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html>
<head>
    <title>Servicio No Disponible - Micro Proyecto 1</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 600px;
            text-align: center;
        }
        h1 { 
            font-size: 28px;
            color: #c0392b;
            border-bottom: 3px solid #e74c3c;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        .error-icon {
            font-size: 64px;
            color: #e74c3c;
            margin-bottom: 20px;
        }
        .message {
            font-size: 18px;
            color: #555;
            line-height: 1.6;
            margin: 20px 0;
        }
        .info {
            margin-top: 30px;
            padding: 20px;
            background: #ffeaa7;
            border-radius: 5px;
            border-left: 4px solid #fdcb6e;
        }
        .info p {
            margin: 10px 0;
            color: #6c5ce7;
            font-weight: bold;
        }
        .footer {
            margin-top: 30px;
            font-size: 14px;
            color: #888;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="error-icon">⚠️</div>
        <h1>Servicio No Disponible</h1>
        <div class="message">
            <p>El servicio web no está disponible en este momento.</p>
            <p>No hay instancias activas del servicio.</p>
        </div>
        <div class="info">
            <p> Por favor, intenta más tarde</p>
            <p> Si el problema persiste, contacta al administrador</p>
        </div>
        <div class="footer">
            <p>Micro Proyecto 1 </p>
            <p> Ivan y Dario</p>
        </div>
    </div>
</body>
</html>
EOF

systemctl enable --now haproxy

# Esperar un momento para que los otros servicios se registren en Consul por problemas en el levantamiento del proyecto cuando es nuevo
sleep 10

# Reiniciar HAProxy para asegurar que detecte los servicios en Consul
systemctl restart haproxy

echo "HAProxy listo: http://localhost:8080  |  Stats: http://localhost:8404/haproxy?stats (admin/admin)"
