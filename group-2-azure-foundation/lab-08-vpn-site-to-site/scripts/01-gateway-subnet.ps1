<#
.SYNOPSIS
    Lab 08 - Cria a GatewaySubnet na VNet do Lab 05.
.DESCRIPTION
    O nome precisa ser exatamente "GatewaySubnet". O Azure identifica
    a subnet do gateway pelo nome, nao por configuracao.
.NOTES
    Rodar no HOST.
#>

az network vnet subnet create `
    --resource-group rg-network-prod-eus2 `
    --vnet-name vnet-contoso-eus2 `
    --name GatewaySubnet `
    --address-prefix 10.10.255.0/27 `
    --output table
