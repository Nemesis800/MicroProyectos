# Test simplificado del sistema
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  TEST DEL SISTEMA COMPLETO" -ForegroundColor Cyan  
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`n[1] Estado de servicios en las VMs..." -ForegroundColor Yellow

# Consul
$consul = vagrant ssh consul -c "systemctl is-active consul"
Write-Host "  Consul server: $consul" -ForegroundColor $(if($consul -eq "active"){"Green"}else{"Red"})

# HAProxy
$haproxy = vagrant ssh lb -c "systemctl is-active haproxy"
Write-Host "  HAProxy: $haproxy" -ForegroundColor $(if($haproxy -eq "active"){"Green"}else{"Red"})

# Apps
$app1 = vagrant ssh app1 -c "systemctl is-active nodeweb"
Write-Host "  App1: $app1" -ForegroundColor $(if($app1 -eq "active"){"Green"}else{"Red"})

$app2 = vagrant ssh app2 -c "systemctl is-active nodeweb"
Write-Host "  App2: $app2" -ForegroundColor $(if($app2 -eq "active"){"Green"}else{"Red"})

Write-Host "`n[2] Servicios registrados en Consul..." -ForegroundColor Yellow
$services = vagrant ssh consul -c "curl -s http://localhost:8500/v1/health/service/web?passing=true | jq length"
Write-Host "  Instancias del servicio 'web': $services" -ForegroundColor Green

Write-Host "`n[3] Probando conectividad desde el host..." -ForegroundColor Yellow
try {
    $response = curl.exe -s http://localhost:8080/
    if ($response) {
        $data = $response | ConvertFrom-Json
        Write-Host "  ✓ Servicio respondiendo correctamente" -ForegroundColor Green
        Write-Host "    - Host: $($data.data_host)" -ForegroundColor Gray
        Write-Host "    - Service: $($data.data_service)" -ForegroundColor Gray
        Write-Host "    - PID: $($data.data_pid)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error conectando al servicio" -ForegroundColor Red
}

Write-Host "`n[4] Probando balanceo (5 peticiones)..." -ForegroundColor Yellow
$results = @()
1..5 | ForEach-Object {
    $response = curl.exe -s http://localhost:8080/ | ConvertFrom-Json
    $results += "$($response.data_host):$($response.data_service)"
}
$results | Group-Object | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) peticiones" -ForegroundColor Gray
}

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  URLs DISPONIBLES" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Servicio: http://localhost:8080/" -ForegroundColor Yellow
Write-Host "  HAProxy Stats: http://localhost:8404/haproxy?stats (admin/admin)" -ForegroundColor Yellow
Write-Host "  Consul UI: http://localhost:8500/ui/dc1/services" -ForegroundColor Yellow
Write-Host "`n✓ Pruebas completadas" -ForegroundColor Green
