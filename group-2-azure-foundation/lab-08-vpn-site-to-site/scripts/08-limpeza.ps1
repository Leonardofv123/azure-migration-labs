<#
.SYNOPSIS
    Lab 08 - Remove os recursos do VPN Gateway.
.DESCRIPTION
    RODE ASSIM QUE TERMINAR O LAB. O gateway cobra por hora enquanto existir.

    A ordem importa: a Connection precisa sair antes do Gateway,
    senao a exclusao falha com VirtualNetworkGatewayCannotBeDeleted.

    TIRE OS PRINTS ANTES DE RODAR ISTO.
.NOTES
    Rodar no HOST. A exclusao do gateway leva de 15 a 20 minutos.
#>

Write-Host "AVISO: isto remove a Connection, o Gateway e o Local Network Gateway." -ForegroundColor Yellow
Write-Host "Voce ja tirou os prints de evidencia?" -ForegroundColor Yellow
$confirma = Read-Host "Continuar? (S/N)"

if ($confirma -ne 'S') {
    Write-Host "Abortado." -ForegroundColor Yellow
    return
}

Write-Host "Removendo Connection..." -ForegroundColor Cyan
az network vpn-connection delete `
    --resource-group rg-network-prod-eus2 `
    --name cn-s2s-eus2

Write-Host "Removendo VPN Gateway (15 a 20 minutos)..." -ForegroundColor Cyan
az network vnet-gateway delete `
    --resource-group rg-network-prod-eus2 `
    --name vng-contoso-eus2 `
    --no-wait

Write-Host "Removendo Local Network Gateway..." -ForegroundColor Cyan
az network local-gateway delete `
    --resource-group rg-network-prod-eus2 `
    --name lng-onprem-eus2

Write-Host ""
Write-Host "Confirme a remocao daqui a 20 minutos com:" -ForegroundColor Cyan
Write-Host '  az network vnet-gateway list -g rg-network-prod-eus2 -o table'
Write-Host ""
Write-Host "Enquanto aparecer com provisioningState 'Deleting', ainda cobra." -ForegroundColor Yellow
Write-Host "O Public IP pip-vng-eus2 pode ser mantido para reuso." -ForegroundColor Cyan
