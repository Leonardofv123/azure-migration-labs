<#
.SYNOPSIS
    Lab 08 - Provisiona o VPN Gateway.
.DESCRIPTION
    ATENCAO AO CUSTO: este recurso cobra por hora enquanto existir.
    Demora de 30 a 45 minutos para provisionar e 15 a 20 para deletar.

    SKUs nao-AZ (VpnGw1, VpnGw2...) foram descontinuados. Usar VpnGw1AZ.
.NOTES
    Rodar no HOST. O --no-wait devolve o terminal enquanto provisiona.
#>

Write-Host "AVISO: este recurso cobra por hora." -ForegroundColor Yellow
Write-Host "Provisionamento leva de 30 a 45 minutos." -ForegroundColor Yellow
$confirma = Read-Host "Continuar? (S/N)"

if ($confirma -ne 'S') {
    Write-Host "Abortado." -ForegroundColor Yellow
    return
}

az network vnet-gateway create `
    --resource-group rg-network-prod-eus2 `
    --name vng-contoso-eus2 `
    --public-ip-address pip-vng-eus2 `
    --vnet vnet-contoso-eus2 `
    --gateway-type Vpn `
    --vpn-type RouteBased `
    --sku VpnGw1AZ `
    --no-wait

Write-Host ""
Write-Host "Provisionamento iniciado. Acompanhe com:" -ForegroundColor Cyan
Write-Host '  az network vnet-gateway show -g rg-network-prod-eus2 -n vng-contoso-eus2 --query provisioningState -o tsv'
