<#
.SYNOPSIS
    Lab 05 - Cria a rede base da Contoso no Azure.
.DESCRIPTION
    Cria o Resource Group, a VNet segmentada em tres sub-redes
    (web, app, dados) e o NSG liberando apenas 80 e 443.
    Idempotente: rodar duas vezes nao quebra.
.NOTES
    Rodar no HOST, nao dentro de VM.
#>

$ErrorActionPreference = 'Stop'

$loc  = 'eastus2'
$rg   = 'rg-network-prod-eus2'
$tags = @{
    Environment = 'Prod'
    Owner       = 'Leo'
    Project     = 'Migration'
    CostCenter  = 'TI'
}

Write-Host "Contexto atual:" -ForegroundColor Cyan
Get-AzContext | Select-Object Name, Subscription, Tenant

$confirma = Read-Host "A subscription acima esta correta? (S/N)"
if ($confirma -ne 'S') {
    Write-Host "Abortado. Use Set-AzContext para trocar." -ForegroundColor Yellow
    return
}

if (-not (Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rg -Location $loc -Tag $tags
    Write-Host "Resource Group criado: $rg" -ForegroundColor Green
} else {
    Write-Host "Resource Group ja existe: $rg" -ForegroundColor Yellow
}

if (-not (Get-AzVirtualNetwork -Name 'vnet-contoso-eus2' -ResourceGroupName $rg -ErrorAction SilentlyContinue)) {

    $web  = New-AzVirtualNetworkSubnetConfig -Name 'snet-web'  -AddressPrefix '10.10.1.0/24'
    $app  = New-AzVirtualNetworkSubnetConfig -Name 'snet-app'  -AddressPrefix '10.10.2.0/24'
    $data = New-AzVirtualNetworkSubnetConfig -Name 'snet-data' -AddressPrefix '10.10.3.0/24'

    New-AzVirtualNetwork `
        -Name 'vnet-contoso-eus2' `
        -ResourceGroupName $rg `
        -Location $loc `
        -AddressPrefix '10.10.0.0/16' `
        -Subnet $web, $app, $data `
        -Tag $tags

    Write-Host "VNet criada com 3 sub-redes" -ForegroundColor Green
} else {
    Write-Host "VNet ja existe" -ForegroundColor Yellow
}

if (-not (Get-AzNetworkSecurityGroup -Name 'nsg-web' -ResourceGroupName $rg -ErrorAction SilentlyContinue)) {

    $nsg = New-AzNetworkSecurityGroup `
        -Name 'nsg-web' `
        -ResourceGroupName $rg `
        -Location $loc `
        -Tag $tags

    $nsg | Add-AzNetworkSecurityRuleConfig `
        -Name 'Allow-Web' `
        -Priority 100 `
        -Direction Inbound `
        -Access Allow `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 80,443 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * |
        Set-AzNetworkSecurityGroup

    Write-Host "NSG criado com a regra Allow-Web" -ForegroundColor Green
} else {
    Write-Host "NSG ja existe" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
Get-AzVirtualNetwork -Name 'vnet-contoso-eus2' -ResourceGroupName $rg |
    Select-Object -ExpandProperty Subnets |
    Select-Object Name, AddressPrefix
