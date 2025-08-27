Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  TEST DEL SISTEMA COMPLETO" -ForegroundColor Cyan  
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "[1] Estado de servicios:" -ForegroundColor Yellow

$consul = vagrant ssh consul -c "systemctl is-active consul"
if ($consul -eq "active") {
    Write-Host "  Consul: OK" -ForegroundColor Green
} else {
    Write-Host "  Consul: FALLA" -ForegroundColor Red
}

$haproxy = vagrant ssh lb -c "systemctl is-active haproxy"
if ($haproxy -eq "active") {
    Write-Host "  HAProxy: OK" -ForegroundColor Green
} else {
    Write-Host "  HAProxy: FALLA" -ForegroundColor Red
}

$app1 = vagrant ssh app1 -c "systemctl is-active nodeweb"
if ($app1 -eq "active") {
    Write-Host "  App1: OK" -ForegroundColor Green
} else {
    Write-Host "  App1: FALLA" -ForegroundColor Red
}

$app2 = vagrant ssh app2 -c "systemctl is-active nodeweb"
if ($app2 -eq "active") {
    Write-Host "  App2: OK" -ForegroundColor Green
} else {
    Write-Host "  App2: FALLA" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2] Servicios en Consul:" -ForegroundColor Yellow
$services = vagrant ssh consul -c "curl -s http://localhost:8500/v1/health/service/web?passing=true | jq length"
Write-Host "  Instancias web: $services" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test de conectividad:" -ForegroundColor Yellow
$test = curl.exe -s http://localhost:8080/
if ($test) {
    Write-Host "  Servicio respondiendo: OK" -ForegroundColor Green
    $json = $test | ConvertFrom-Json
    Write-Host "  - Host: $($json.data_host)"
    Write-Host "  - Service: $($json.data_service)"
} else {
    Write-Host "  Servicio respondiendo: FALLA" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4] Test de balanceo:" -ForegroundColor Yellow
Write-Host "  Realizando 6 peticiones..."
$hosts = @{}
1..6 | ForEach-Object {
    $r = curl.exe -s http://localhost:8080/ | ConvertFrom-Json
    $key = "$($r.data_host):$($r.data_service)"
    if ($hosts.ContainsKey($key)) {
        $hosts[$key] = $hosts[$key] + 1
    } else {
        $hosts[$key] = 1
    }
}

Write-Host "  Distribucion:"
foreach ($h in $hosts.GetEnumerator()) {
    Write-Host "    $($h.Key): $($h.Value) peticiones"
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "URLs del sistema:" -ForegroundColor Yellow
Write-Host "  - Servicio: http://localhost:8080/"
Write-Host "  - HAProxy Stats: http://localhost:8404/haproxy?stats"
Write-Host "  - Consul UI: http://localhost:8500/ui/dc1/services"
Write-Host ""
Write-Host "Pruebas completadas!" -ForegroundColor Green
