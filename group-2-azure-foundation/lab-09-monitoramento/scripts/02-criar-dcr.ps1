<#
.SYNOPSIS
    Lab 09 - Cria a Data Collection Rule.
.DESCRIPTION
    A DCR define O QUE coletar e PARA ONDE mandar. E um recurso
    independente, reutilizavel entre varias maquinas.

    Na primeira execucao, o Azure CLI instala automaticamente a extensao
    monitor-control-service e registra o provider microsoft.insights.
.NOTES
    Rodar no HOST, a partir da pasta scripts/ (usa dcr-windows.json).
#>

$ErrorActionPreference = 'Stop'

$rg   = 'rg-monitor-prod-eus2'
$dcr  = 'dcr-windows-contoso'
$json = Join-Path $PSScriptRoot 'dcr-windows.json'

if (-not (Test-Path $json)) {
    Write-Host "Arquivo nao encontrado: $json" -ForegroundColor Red
    return
}

$subId = az account show --query id --output tsv
$conteudo = Get-Content $json -Raw

if ($conteudo -match '<SUB_ID>') {
    Write-Host "Substituindo <SUB_ID> pelo ID da subscription atual..." -ForegroundColor Cyan
    $temp = Join-Path $env:TEMP 'dcr-windows-resolvido.json'
    $conteudo.Replace('<SUB_ID>', $subId) | Set-Content $temp -Encoding utf8
    $json = $temp
}

az monitor data-collection rule create `
    --resource-group $rg `
    --name $dcr `
    --location eastus2 `
    --rule-file $json

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
az monitor data-collection rule show `
    --resource-group $rg `
    --name $dcr `
    --query "{Nome:name, Estado:provisioningState, Local:location}" `
    --output table
