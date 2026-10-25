# ============================================================
# Banco Internacional EV-2 - escaneos con OWASP ZAP (Windows)
#
# Equivalente a run-zap-scans.sh para PowerShell. ZAP corre como
# demonio dentro de su contenedor y expone el API en el puerto
# 8080, asi que los escaneos se manejan por HTTP.
#
#   Escaner 1 - baseline : rastreo (spider) y reglas pasivas.
#   Escaner 2 - full     : rastreo y escaneo activo completo.
#
# Uso:  .\scripts\run-zap-scans.ps1 baseline
#       .\scripts\run-zap-scans.ps1 full
#       .\scripts\run-zap-scans.ps1 ambos
# ============================================================

param(
  [ValidateSet('baseline', 'full', 'ambos')]
  [string]$Modo = 'ambos'
)

$ErrorActionPreference = 'Stop'

$Raiz     = Split-Path -Parent $PSScriptRoot
$Salida   = Join-Path $Raiz 'scans'
$Api      = 'http://127.0.0.1:8080'
$Objetivo = 'http://webapp:8088'

New-Item -ItemType Directory -Force -Path $Salida | Out-Null

function Invoke-Zap {
  param([string]$Ruta)
  Invoke-RestMethod -Uri "$Api/$Ruta" -TimeoutSec 120
}

function Esperar-Zap {
  $inicio = Get-Date
  while ($true) {
    try {
      $null = Invoke-Zap 'JSON/core/view/version/'
      return
    } catch {
      if (((Get-Date) - $inicio).TotalSeconds -gt 120) {
        throw "ZAP no responde en $Api"
      }
      Start-Sleep -Seconds 5
    }
  }
}

function Esperar-Progreso {
  param(
    [string]$Clave,
    [string]$Etiqueta,
    [int]$Limite = 3600
  )
  $inicio = Get-Date
  while ($true) {
    $valor = 0
    try { $valor = [int](Invoke-Zap "JSON/$Clave").status } catch { }
    Write-Host "  $Etiqueta`: $valor%"
    if ($valor -ge 100) { return }
    if (((Get-Date) - $inicio).TotalSeconds -gt $Limite) {
      Write-Host "  Tiempo agotado esperando $Etiqueta"
      return
    }
    Start-Sleep -Seconds 10
  }
}

function Exportar {
  param([string]$Nombre)
  Invoke-WebRequest -Uri "$Api/OTHER/core/other/jsonreport/" -OutFile (Join-Path $Salida "$Nombre.json") -TimeoutSec 300
  Invoke-WebRequest -Uri "$Api/OTHER/core/other/htmlreport/" -OutFile (Join-Path $Salida "$Nombre.html") -TimeoutSec 300
  Write-Host "  Reporte escrito: scans/$Nombre.json y scans/$Nombre.html"
}

function Iniciar-Baseline {
  Write-Host ''
  Write-Host "=== Escaner 1: baseline contra $Objetivo ==="
  $null = Invoke-Zap 'JSON/core/action/newSession/?name=baseline&overwrite=true'

  Write-Host '  Iniciando rastreo...'
  $null = Invoke-Zap "JSON/spider/action/scan/?url=$Objetivo&recurse=true&maxChildren=10"
  Esperar-Progreso -Clave 'spider/view/status/' -Etiqueta 'rastreo' -Limite 900

  Write-Host '  Esperando reglas pasivas...'
  Start-Sleep -Seconds 15

  Exportar -Nombre 'zap-baseline'
}

function Iniciar-Full {
  Write-Host ''
  Write-Host "=== Escaner 2: full contra $Objetivo ==="
  Write-Host '  Este escaneo puede tardar entre 20 y 60 minutos.'
  $null = Invoke-Zap 'JSON/core/action/newSession/?name=full&overwrite=true'

  Write-Host '  Iniciando rastreo...'
  $null = Invoke-Zap "JSON/spider/action/scan/?url=$Objetivo&recurse=true&maxChildren=20"
  Esperar-Progreso -Clave 'spider/view/status/' -Etiqueta 'rastreo' -Limite 1800

  Write-Host '  Iniciando escaneo activo...'
  $null = Invoke-Zap "JSON/ascan/action/scan/?url=$Objetivo&recurse=true&inScopeOnly=false"
  Esperar-Progreso -Clave 'ascan/view/status/' -Etiqueta 'escaneo activo' -Limite 5400

  Write-Host '  Esperando reglas pasivas...'
  Start-Sleep -Seconds 20

  Exportar -Nombre 'zap-full'
}

Esperar-Zap
Write-Host "ZAP operativo: $((Invoke-Zap 'JSON/core/view/version/').version)"

switch ($Modo) {
  'baseline' { Iniciar-Baseline }
  'full'     { Iniciar-Full }
  'ambos'    { Iniciar-Baseline; Iniciar-Full }
}

Write-Host ''
Write-Host "Escaneos terminados. Reportes en $Salida"
