<#
.SYNOPSIS
    Lab 09 - Instala o AMA numa maquina Arc e associa a DCR.
.DESCRIPTION
    Mesmo par indivisivel do script 03, mas usando "az connectedmachine"
    em vez de "az vm", porque a maquina nao e nativa do Azure.
.NOTES
    Rodar no HOST.
.EXAMPLE
    .\06-instalar-ama-arc.ps1 -Maquina DC01
    .\06-instalar-ama-arc.ps1 -Maquina FS01
    .\06-instalar-ama-arc.ps1 -Maquina WEB01
#>

param(
    [Parameter(Mandatory)]
    [string]$Maquina
)

$ErrorActionPreference = 'Stop'

$subId = az account show --query id --output tsv
$rg    = 'rg-monitor-prod-eus2'

Write-Host "1/2 Instalando o Azure Monitor Agent em $Maquina..." -ForegroundColor Cyan

az connectedmachine extension create `
    --resource-group $rg `
    --machine-name $Maquina `
    --name AzureMonitorWindowsAgent `
    --publisher Microsoft.Azure.Monitor `
    --type AzureMonitorWindowsAgent `
    --location eastus2 `
    --output table

Write-Host "2/2 Associando a DCR..." -ForegroundColor Cyan

$ruleId    = "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Insights/dataCollectionRules/dcr-windows-contoso"
$machineId = "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.HybridCompute/machines/$Maquina"

az monitor data-collection rule association create `
    --name "dcra-$($Maquina.ToLower())" `
    --rule-id $ruleId `
    --resource $machineId `
    --output table

Write-Host ""
Write-Host "Aguarde 5 a 10 minutos e valide com 07-validar-heartbeat.ps1" -ForegroundColor Yellow
