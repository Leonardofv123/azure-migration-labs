<#
.SYNOPSIS
    Lab 08 - Cria o Local Network Gateway.
.DESCRIPTION
    O LNG representa, dentro do Azure, o que existe do outro lado do tunel.

    ATENCAO: o --local-address-prefixes e OBRIGATORIO. Sem ele o tunel
    conecta normalmente, reporta Connected dos dois lados, e nenhum trafego
    roteia. Nao ha erro. Essa falha silenciosa custou tempo neste lab.
.NOTES
    Rodar no HOST.
#>

$ipPublico = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()

Write-Host "IP publico detectado: $ipPublico" -ForegroundColor Cyan
$confirma = Read-Host "Usar este IP? (S/N)"

if ($confirma -ne 'S') {
    $ipPublico = Read-Host "Informe o IP publico"
}

az network local-gateway create `
    --resource-group rg-network-prod-eus2 `
    --name lng-onprem-eus2 `
    --gateway-ip-address $ipPublico `
    --local-address-prefixes 192.168.10.0/24 `
    --output table

Write-Host ""
Write-Host "Validacao (use --query, nao --output table):" -ForegroundColor Cyan
Write-Host "O --output table NAO renderiza arrays. O campo aparece vazio" -ForegroundColor Yellow
Write-Host "mesmo quando esta preenchido." -ForegroundColor Yellow
Write-Host ""

az network local-gateway show `
    --resource-group rg-network-prod-eus2 `
    --name lng-onprem-eus2 `
    --query "localNetworkAddressSpace"
