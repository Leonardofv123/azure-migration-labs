<#
.SYNOPSIS
    Lab 09 - Instala o AMA na VM Azure e associa a DCR.
.DESCRIPTION
    ATENCAO: sao DOIS PASSOS, sempre em par.

    Instalar o agente e criar a DCR nao e suficiente. Sem a ASSOCIACAO,
    o agente roda saudavel mas sem instrucao nenhuma, e nada chega ao
    workspace. Nao ha erro, apenas silencio. Isso custou tempo neste lab.
.NOTES
    Rodar no HOST.
#>

$ErrorActionPreference = 'Stop'

$subId  = az account show --query id --output tsv
$rgVM   = 'rg-network-prod-eus2'
$rgMon  = 'rg-monitor-prod-eus2'
$vm     = 'vm-web-prod-eus2'

Write-Host "1/2 Instalando o Azure Monitor Agent..." -ForegroundColor Cyan

az vm extension set `
    --resource-group $rgVM `
    --vm-name $vm `
    --name AzureMonitorWindowsAgent `
    --publisher Microsoft.Azure.Monitor `
    --enable-auto-upgrade true `
    --output table

Write-Host "2/2 Associando a DCR..." -ForegroundColor Cyan

$ruleId  = "/subscriptions/$subId/resourceGroups/$rgMon/providers/Microsoft.Insights/dataCollectionRules/dcr-windows-contoso"
$vmId    = "/subscriptions/$subId/resourceGroups/$rgVM/providers/Microsoft.Compute/virtualMachines/$vm"

az monitor data-collection rule association create `
    --name dcra-vm-web-prod `
    --rule-id $ruleId `
    --resource $vmId `
    --output table

Write-Host ""
Write-Host "Validacao (o agente roda como PROCESSO, nao como servico):" -ForegroundColor Cyan
Write-Host "Procurar por Get-Service AzureMonitorAgent nao encontra nada." -ForegroundColor Yellow
Write-Host ""

az vm run-command invoke `
    --resource-group $rgVM `
    --name $vm `
    --command-id RunPowerShellScript `
    --scripts "Get-Process | Where-Object { `$_.ProcessName -like '*AMA*' } | Format-Table ProcessName, Id, StartTime -AutoSize"
