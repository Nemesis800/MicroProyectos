# Microproyecto: HAProxy + Consul + Aplicaciones Node.js con Service Discovery

## 📋 Descripción
Sistema de balanceo de carga dinámico usando HAProxy con descubrimiento de servicios automático vía Consul DNS. Las aplicaciones Node.js se registran automáticamente en Consul y HAProxy las detecta sin necesidad de reconfiguración manual.

## 🏗️ Arquitectura

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   Cliente   │────▶│   HAProxy    │────▶│   Apps Node  │
│  (Browser)  │:8080│   (VM: lb)   │     │  (app1/app2) │
└─────────────┘     └──────────────┘     └──────────────┘
                            │                     │
                            ▼                     ▼
                    ┌──────────────┐     ┌──────────────┐
                    │ Consul DNS   │◀────│Consul Agents │
                    │  (VM:consul) │     │  (app1/app2) │
                    └──────────────┘     └──────────────┘
```

### VMs y Servicios
| VM | IP | Servicios | Puertos expuestos al host |
|----|-----|-----------|---------------------------|
| lb | 192.168.56.10 | HAProxy | 8080 (servicio), 8404 (stats) |
| app1 | 192.168.56.11 | Node app + Consul agent | - |
| app2 | 192.168.56.12 | Node app + Consul agent | - |
| consul | 192.168.56.13 | Consul server + UI | 8500 (UI) |

## ⚙️ Requisitos
- VirtualBox 6.x o superior
- Vagrant 2.x o superior
- 4GB RAM disponible (1GB por VM)
- Windows/Linux/macOS

## 🚀 Inicio Rápido

### 1. Clonar el repositorio
```bash
git clone <tu-repositorio>
cd "Micro Proyecto 1"
```

### 2. Levantar el entorno
```bash
vagrant up
```
Esto creará las 4 VMs y las provisionará automáticamente (toma ~10-15 minutos la primera vez).


### 3. Verificar funcionamiento
- **Servicio balanceado**: http://localhost:8080/
- **HAProxy Stats**: http://localhost:8404/haproxy?stats (usuario: admin, contraseña: admin)
- **Consul UI**: http://localhost:8500/ui/dc1/services

## ✅ Validaciones

### Verificar balanceo round-robin
```powershell
# PowerShell
1..10 | ForEach-Object { 
    curl.exe -s http://localhost:8080/ | ConvertFrom-Json 
} | Select-Object data_host, data_service

# Bash/Linux
for i in {1..10}; do 
    curl -s http://localhost:8080/ | jq '.data_host, .data_service'
done
```

### Probar tolerancia a fallos
```powershell
# Detener una instancia
vagrant ssh app1 -c "sudo systemctl stop nodeweb"

# Verificar que el servicio sigue funcionando
curl.exe http://localhost:8080/

# Reiniciar la instancia
vagrant ssh app1 -c "sudo systemctl start nodeweb"
```

## 🔧 Pruebas de Escalabilidad

### Agregar réplicas adicionales (hasta 5 total)

#### En app1 (agregar 2 réplicas más):
```powershell
vagrant ssh app1 -c "sudo systemd-run --unit nodeweb-3001 /usr/bin/env HOST=192.168.56.11 PORT=3001 /usr/bin/node /opt/web/index.js"
vagrant ssh app1 -c "sudo systemd-run --unit nodeweb-3002 /usr/bin/env HOST=192.168.56.11 PORT=3002 /usr/bin/node /opt/web/index.js"
```

#### En app2 (agregar 1 réplica más):
```powershell
vagrant ssh app2 -c "sudo systemd-run --unit nodeweb-3003 /usr/bin/env HOST=192.168.56.12 PORT=3003 /usr/bin/node /opt/web/index.js"
```

#### Verificar en HAProxy Stats
Abre http://localhost:8404/haproxy?stats y verás 5 servidores activos en el backend.

### Detener réplicas
```powershell
# Detener réplicas en app1
vagrant ssh app1 -c "sudo systemctl stop nodeweb-3001 nodeweb-3002"

# Detener réplica en app2
vagrant ssh app2 -c "sudo systemctl stop nodeweb-3003"
```

## 📊 Pruebas de Carga con Artillery

### Instalar Artillery (en el host)
```bash
npm install -g artillery
```

### Ejecutar prueba
```bash
artillery run artillery.yml
```

El archivo `artillery.yml` incluye 3 fases:
- Warm-up: 60s a 5 req/s
- Carga sostenida: 180s a 25 req/s  
- Spike: 60s a 80 req/s

### Generar reporte HTML
```bash
artillery run artillery.yml --output results.json
artillery report results.json
```

## 🛠️ Solución de Problemas

### Si Consul no arranca (múltiples IPs)
Los archivos ya incluyen la corrección, pero si modificas las IPs, asegúrate de:
- `bind_addr` y `advertise_addr` usen la IP específica de cada VM
- No usar `0.0.0.0` en bind_addr

### Si HAProxy muestra 503
1. Verifica que Consul esté activo:
   ```powershell
   vagrant ssh consul -c "systemctl is-active consul"
   ```
2. Verifica que las apps estén registradas:
   ```powershell
   vagrant ssh consul -c "consul catalog services"
   ```
3. Reinicia HAProxy:
   ```powershell
   vagrant ssh lb -c "sudo systemctl restart haproxy"
   ```

### Verificar logs
```powershell
# Consul server
vagrant ssh consul -c "journalctl -u consul --no-pager -n 50"

# Apps
vagrant ssh app1 -c "journalctl -u nodeweb --no-pager -n 50"

# HAProxy
vagrant ssh lb -c "journalctl -u haproxy --no-pager -n 50"
```

## 📝 Cambios Importantes Aplicados

### 1. **Consul bind_addr fix**
- Especificamos IPs explícitas en lugar de 0.0.0.0 para evitar error de múltiples interfaces

### 2. **HAProxy con SRV records**
- Usa `_web._tcp.service.consul` para obtener puertos dinámicamente
- `resolve-opts allow-dup-ip` permite múltiples servicios en la misma IP

### 3. **Health checks mejorados**
- Endpoint `/health` en cada app
- HAProxy verifica salud antes de enviar tráfico

## 🧹 Limpieza

### Apagar VMs (preserva estado)
```bash
vagrant halt
```

### Destruir VMs (borra todo)
```bash
vagrant destroy -f
```

## 📚 Referencias
- [Consul DNS Interface](https://www.consul.io/docs/discovery/dns)
- [HAProxy Server Templates](http://cbonte.github.io/haproxy-dconv/2.4/configuration.html#server-template)
- [Vagrant Documentation](https://www.vagrantup.com/docs)

## 👥 Autores
Ivan Rodrigo Castillo Cañas 22502346 Dario Fernando Narvaez Guevara 22500268 - Grupo 6 - 2025
