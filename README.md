# Microproyecto: HAProxy + Consul (server dedicado) + 2 apps Node

## Topología
- consul (192.168.56.13): Consul **server** + UI (8500)
- lb     (192.168.56.10): HAProxy (80) + stats (8404)
- app1   (192.168.56.11): Node (3000) + Consul agent
- app2   (192.168.56.12): Node (3000) + Consul agent

## Cómo ejecutar
```bash
vagrant up
```
- HAProxy (a través del host): http://localhost:8080/
- HAProxy stats: http://localhost:8404/haproxy?stats  (usuario: `admin`, pass: `admin`)
- Consul UI: http://localhost:8500/ui/dc1/services  (verás el servicio `web` con 2 instancias)

## Validaciones rápidas
- Refresca `http://localhost:8080/` varias veces: alternan `data_pid`, `data_service`.
- Apaga una app: `vagrant ssh app1 -c "sudo systemctl stop nodeweb"` ⇒ el tráfico sigue fluido.
- Apaga ambas apps ⇒ `http://localhost:8080/` muestra **503** personalizada.
- En app1, agregar dos instancias nuevas (puertos 3001 y 3002):
- vagrant ssh app1 -c "sudo systemd-run --unit nodeweb-3001 /usr/bin/env HOST=192.168.56.11 PORT=3001 /usr/bin/node /opt/web/index.js"
- vagrant ssh app1 -c "sudo systemd-run --unit nodeweb-3002 /usr/bin/env HOST=192.168.56.11 PORT=3002 /usr/bin/node /opt/web/index.js"
- En app2, agregar una instancia nueva (puerto 3001):
-  vagrant ssh app2 -c "sudo systemd-run --unit nodeweb-3001 /usr/bin/env HOST=192.168.56.12 PORT=3001 /usr/bin/node /opt/web/index.js"
- si no actualiza los servicios en haproxy
- vagrant ssh lb -c "sudo systemctl reload haproxy"

## Notas
- Las VMs usan Ubuntu 22.04. Requiere VirtualBox + Vagrant instalados en el host.
- Las redes privadas están en `192.168.56.0/24`. Cambia IPs si ese rango lo usas para otra cosa.