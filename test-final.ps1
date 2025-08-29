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
if ($test -match "<h1>Servicio WEB Micro Proyecto 1</h1>") {
    Write-Host "  Servicio respondiendo: OK" -ForegroundColor Green
    # Extraer valores del HTML usando regex más flexible
    $hostMatch = [regex]::Match($test, 'Host IP:</span>\s*<span class="value">([^<]+)</span>')
    $serviceMatch = [regex]::Match($test, 'Servicio:</span>\s*<span class="value">([^<]+)</span>')
    
    if ($hostMatch.Success) {
        Write-Host "  - Host: $($hostMatch.Groups[1].Value)"
    }
    if ($serviceMatch.Success) {
        Write-Host "  - Service: $($serviceMatch.Groups[1].Value)"
    }
} elseif ($test -match "<h1>Servicio No Disponible</h1>") {
    Write-Host "  Servicio respondiendo: ERROR 503" -ForegroundColor Red
    Write-Host "  - No hay instancias activas"
} else {
    Write-Host "  Servicio respondiendo: FALLA" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4] Test de balanceo:" -ForegroundColor Yellow
Write-Host "  Realizando 10 peticiones..."
$hosts = @{}
1..10 | ForEach-Object {
    $response = curl.exe -s http://localhost:8080/
    # Extraer host y servicio del HTML
    $hostMatch = [regex]::Match($response, 'Host IP:</span>\s*<span class="value">([^<]+)</span>')
    $serviceMatch = [regex]::Match($response, 'Servicio:</span>\s*<span class="value">([^<]+)</span>')
    
    if ($hostMatch.Success -and $serviceMatch.Success) {
        $hostIP = $hostMatch.Groups[1].Value
        $serviceID = $serviceMatch.Groups[1].Value
        $key = "${hostIP}:${serviceID}"
        
        if ($hosts.ContainsKey($key)) {
            $hosts[$key] = $hosts[$key] + 1
        } else {
            $hosts[$key] = 1
        }
    }
}

Write-Host "  Distribucion:"
if ($hosts.Count -eq 0) {
    Write-Host "    No se pudieron obtener respuestas válidas" -ForegroundColor Red
} else {
    foreach ($h in $hosts.GetEnumerator()) {
        Write-Host "    $($h.Key): $($h.Value) peticiones"
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "URLs del sistema:" -ForegroundColor Yellow
Write-Host "  - Servicio: http://localhost:8080/"
Write-Host "  - HAProxy Stats: http://localhost:8404/haproxy?stats"
Write-Host "  - Consul UI: http://localhost:8500/ui/dc1/services"
Write-Host ""
Write-Host "Pruebas completadas!" -ForegroundColor Green
