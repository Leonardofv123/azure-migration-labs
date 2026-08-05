<#
.SYNOPSIS
    Lab 09 - Cria o Log Analytics Workspace.
.DESCRIPTION
    O workspace e o destino de todos os logs e metricas do ambiente,
    on-premises e Azure. Diferente do VPN Gateway do Lab 08, ele nao
    cobra por hora provisionada, apenas por volume ingerido.
    O tier gratuito cobre 5 GB por mes.
.NOTES
    Rodar no HOST.
#>

$ErrorActionPreference = 'Stop'

$rg  = 'rg-monitor-prod-eus2'
$ws  = 'law-contoso-eus2'
$loc = 'eastus2'

az group create --name $rg --location $loc --output table

az monitor log-analytics workspace create `
    --resource-group $rg `
    --workspace-name $ws `
    --location $loc `
    --retention-time 31 `
    --sku PerGB2018 `
    --output table

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
az monitor log-analytics workspace show `
    --resource-group $rg `
    --workspace-name $ws `
    --query "{Nome:name, Estado:provisioningState, Retencao:retentionInDays, SKU:sku.name}" `
    --output table

Write-Host ""
Write-Host "GUARDE O WORKSPACE ID abaixo, sera usado em todas as queries:" -ForegroundColor Yellow
az monitor log-analytics workspace show `
    --resource-group $rg `
    --workspace-name $ws `
    --query "customerId" --output tsv
