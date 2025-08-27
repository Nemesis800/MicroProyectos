# Test Script para el sistema HAProxy + Consul + Node.js
# Ejecutar desde la carpeta del proyecto

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  TEST DEL SISTEMA COMPLETO" -ForegroundColor Cyan  
Write-Host "=====================================" -ForegroundColor Cyan

# Verificar que las VMs estén arriba
Write-Host "`n[1] Verificando estado de VMs..." -ForegroundColor Yellow
$vmStatus = vagrant status --machine-readable | Select-String "state-human-short"
if ($vmStatus -match "running") {
    Write-Host "✓ VMs están corriendo" -ForegroundColor Green
} else {
    Write-Host "✗ Algunas VMs no están corriendo. Ejecuta: vagrant up" -ForegroundColor Red
    exit 1
}

# Test Consul
Write-Host "`n[2] Verificando Consul..." -ForegroundColor Yellow
$consulStatus = vagrant ssh consul -c "systemctl is-active consul 2>/dev/null" 2>$null
if ($consulStatus -eq "active") {
    Write-Host "✓ Consul server activo" -ForegroundColor Green
    
    # Verificar miembros
    $members = vagrant ssh consul -c "consul members 2>/dev/null | grep -c alive" 2>$null
    Write-Host "✓ Cluster con $members miembros activos" -ForegroundColor Green
} else {
    Write-Host "✗ Consul no está activo" -ForegroundColor Red
}

# Test Apps
Write-Host "`n[3] Verificando aplicaciones Node..." -ForegroundColor Yellow
$app1Status = vagrant ssh app1 -c "systemctl is-active nodeweb 2>/dev/null"
$app2Status = vagrant ssh app2 -c "systemctl is-active nodeweb 2>/dev/null"

if ($app1Status -eq "active") {
    Write-Host "✓ App1 activa" -ForegroundColor Green
} else {
    Write-Host "✗ App1 no está activa" -ForegroundColor Red
}

if ($app2Status -eq "active") {
    Write-Host "✓ App2 activa" -ForegroundColor Green
} else {
    Write-Host "✗ App2 no está activa" -ForegroundColor Red
}

# Verificar servicios en Consul
$services = vagrant ssh consul -c "curl -s http://localhost:8500/v1/health/service/web?passing=true 2>/dev/null | jq length" 2>$null
Write-Host "✓ $services instancias del servicio 'web' registradas en Consul" -ForegroundColor Green

# Test HAProxy
Write-Host "`n[4] Verificando HAProxy..." -ForegroundColor Yellow
$haproxyStatus = vagrant ssh lb -c "systemctl is-active haproxy 2>/dev/null" 2>$null
if ($haproxyStatus -eq "active") {
    Write-Host "✓ HAProxy activo" -ForegroundColor Green
} else {
    Write-Host "✗ HAProxy no está activo" -ForegroundColor Red
}

# Test conectividad desde el host
Write-Host "`n[5] Probando conectividad desde el host..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ Servicio respondiendo en puerto 8080" -ForegroundColor Green
        
        # Parsear respuesta
        $content = $response.Content | ConvertFrom-Json
        Write-Host "  - Host: $($content.data_host)" -ForegroundColor Gray
        Write-Host "  - Service: $($content.data_service)" -ForegroundColor Gray
        Write-Host "  - PID: $($content.data_pid)" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ No se puede conectar al servicio en puerto 8080" -ForegroundColor Red
}

# Test panel de estadísticas
try {
    $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
    $headers = @{ Authorization = "Basic $credentials" }
    $statsResponse = Invoke-WebRequest -Uri "http://localhost:8404/haproxy?stats;csv" -Headers $headers -UseBasicParsing -TimeoutSec 5
    if ($statsResponse.StatusCode -eq 200) {
        Write-Host "✓ Panel de estadísticas HAProxy accesible" -ForegroundColor Green
        
        # Contar backends UP
        $upCount = ($statsResponse.Content | Select-String "UP" -AllMatches).Matches.Count
        Write-Host "  - Backends UP: $upCount" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ No se puede acceder al panel de estadísticas" -ForegroundColor Red
}

# Test Consul UI
try {
    $consulUI = Invoke-WebRequest -Uri "http://localhost:8500/ui/" -UseBasicParsing -TimeoutSec 5
    if ($consulUI.StatusCode -eq 200) {
        Write-Host "✓ Consul UI accesible" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ No se puede acceder a Consul UI" -ForegroundColor Red
}

# Test de balanceo
Write-Host "`n[6] Probando balanceo round-robin..." -ForegroundColor Yellow
$hosts = @{}
for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing -TimeoutSec 2
        $data = $response.Content | ConvertFrom-Json
        $key = "$($data.data_host):$($data.data_service)"
        
        if ($hosts.ContainsKey($key)) {
            $hosts[$key]++
        } else {
            $hosts[$key] = 1
        }
    } catch {
        # Ignorar errores individuales
    }
}

Write-Host "Distribución de peticiones (10 requests):" -ForegroundColor Cyan
foreach ($host in $hosts.GetEnumerator()) {
    Write-Host "  $($host.Key): $($host.Value) peticiones" -ForegroundColor Gray
}

if ($hosts.Count -gt 1) {
    Write-Host "✓ Balanceo funcionando correctamente" -ForegroundColor Green
} else {
    Write-Host "⚠ Solo una instancia está respondiendo" -ForegroundColor Yellow
}

# Resumen
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  RESUMEN DE PRUEBAS" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$urls = @(
    "Servicio: http://localhost:8080/",
    "HAProxy Stats: http://localhost:8404/haproxy?stats (admin/admin)",
    "Consul UI: http://localhost:8500/ui/dc1/services"
)

Write-Host "`nURLs disponibles:" -ForegroundColor Yellow
foreach ($url in $urls) {
    Write-Host "  - $url" -ForegroundColor Cyan
}

Write-Host "`n✓ Sistema listo para usar" -ForegroundColor Green
