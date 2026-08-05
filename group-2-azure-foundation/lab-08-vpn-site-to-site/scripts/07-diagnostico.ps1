<#
.SYNOPSIS
    Lab 08 - Diagnostico completo do tunel VPN.
.DESCRIPTION
    ESTE SCRIPT EXISTE POR CAUSA DE UM ERRO DE METODO.

    Durante o lab, o estado do tunel e o estado da rota foram verificados
    em MOMENTOS DIFERENTES. Como o tunel caia e voltava, cada verificacao
    pegava um retrato diferente e as conclusoes nao batiam.

    A correcao foi validar tudo na MESMA EXECUCAO. E isso que este
    script faz, e foi assim que a evidencia conclusiva foi obtida.
.NOTES
    Rodar no HOST.
#>

$cred = Get-Credential -Message "Credencial local da GW01 (administrator)"

Write-Host "=== LADO AZURE ===" -ForegroundColor Cyan

az network vpn-connection show `
    --resource-group rg-network-prod-eus2 `
    --name cn-s2s-eus2 `
    --query "{Status:connectionStatus, In:ingressBytesTransferred, Out:egressBytesTransferred}" `
    --output table

Write-Host ""
Write-Host "Parametros IKE negociados:" -ForegroundColor Cyan
az network vpn-connection list-ike-sas `
    --resource-group rg-network-prod-eus2 `
    --name cn-s2s-eus2

Write-Host ""
Write-Host "Caminho no Azure (NSG + rotas):" -ForegroundColor Cyan
az network watcher test-ip-flow `
    --resource-group rg-network-prod-eus2 `
    --vm vm-web-prod-eus2 `
    --direction Inbound `
    --protocol TCP `
    --local 10.10.1.4:80 `
    --remote 192.168.10.10:60000 `
    --output table

Write-Host ""
Write-Host "=== LADO ON-PREMISES (tudo na mesma execucao) ===" -ForegroundColor Cyan

Invoke-Command -VMName 'contoso-gw01' -Credential $cred -ScriptBlock {

    Connect-VpnS2SInterface -Name 'To-Azure' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10

    Write-Host "--- ESTADO DO TUNEL ---" -ForegroundColor Yellow
    Get-VpnS2SInterface -Name 'To-Azure' |
        Select-Object Name, ConnectionState, Destination |
        Format-Table -AutoSize

    Write-Host "--- ROTA PARA AZURE ---" -ForegroundColor Yellow
    Get-NetRoute -AddressFamily IPv4 |
        Where-Object { $_.DestinationPrefix -eq '10.10.0.0/16' } |
        Select-Object DestinationPrefix, InterfaceAlias, InterfaceIndex, NextHop |
        Format-Table -AutoSize

    Write-Host "--- TESTE DE CONECTIVIDADE ---" -ForegroundColor Yellow
    ping 10.10.1.4 -n 4
}

Write-Host ""
Write-Host "Como ler o resultado:" -ForegroundColor Cyan
Write-Host "  InterfaceAlias 'To-Azure'  = rota correta"
Write-Host "  InterfaceAlias 'Loopback'  = rota orfa, o tunel caiu"
Write-Host "  'transmit failed'          = problema local de rota"
Write-Host "  'Request timed out'        = pacote saiu e nao voltou"
