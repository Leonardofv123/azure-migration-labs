<#
.SYNOPSIS
    Lab 08 - Cria a Connection ligando o VPN Gateway ao Local Network Gateway.
.NOTES
    Rodar no HOST. O PSK e pedido em runtime, nunca versionado.
#>

$psk = Read-Host "Pre-Shared Key (PSK)" -AsSecureString
$pskPlano = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
)

az network vpn-connection create `
    --resource-group rg-network-prod-eus2 `
    --name cn-s2s-eus2 `
    --vnet-gateway1 vng-contoso-eus2 `
    --local-gateway2 lng-onprem-eus2 `
    --shared-key $pskPlano `
    --output table

$pskPlano = $null

Write-Host ""
Write-Host "Guarde a mesma PSK, sera usada no RRAS da GW01." -ForegroundColor Yellow
