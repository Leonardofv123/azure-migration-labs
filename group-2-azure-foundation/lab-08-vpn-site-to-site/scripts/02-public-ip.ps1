<#
.SYNOPSIS
    Lab 08 - Cria o Public IP do VPN Gateway.
.DESCRIPTION
    O SKU VpnGw1AZ e zone-redundant e exige Public IP Standard
    com as tres zonas declaradas. Sem isso, a criacao do gateway falha.
.NOTES
    Rodar no HOST.
#>

az network public-ip create `
    --resource-group rg-network-prod-eus2 `
    --name pip-vng-eus2 `
    --sku Standard `
    --allocation-method Static `
    --zone 1 2 3 `
    --output table
