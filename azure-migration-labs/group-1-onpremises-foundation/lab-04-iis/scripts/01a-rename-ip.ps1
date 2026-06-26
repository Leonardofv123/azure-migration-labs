<#
    Lab 04 - Script 01a: Renomear WEB01 + configurar IP fixo
    Executar DENTRO da VM WEB01, no PowerShell como Administrador.

    Depois de rodar, reiniciar com: Restart-Computer -Force
#>

$novoNome      = 'WEB01'
$nomeAdaptador = 'Ethernet'
$ip            = '192.168.10.30'      # IP fixo da WEB01
$prefixo       = 24
$gateway       = '192.168.10.1'
$dns           = '192.168.10.10'      # aponta para o DC01

if ($env:COMPUTERNAME -ne $novoNome) {
    Rename-Computer -NewName $novoNome -Force
    Write-Host "Nome alterado para '$novoNome'. Reinicializacao necessaria." -ForegroundColor Green
} else {
    Write-Host "Nome ja esta correto." -ForegroundColor Yellow
}

Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias $nomeAdaptador `
                  -IPAddress $ip `
                  -PrefixLength $prefixo `
                  -DefaultGateway $gateway

Set-DnsClientServerAddress -InterfaceAlias $nomeAdaptador -ServerAddresses $dns

Write-Host "Configurado: $novoNome / $ip" -ForegroundColor Green

# Validacao
Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 | Select-Object IPAddress, PrefixLength
Resolve-DnsName -Name 'contoso.local'

Write-Host "`nReinicie a VM para aplicar o nome novo: Restart-Computer -Force" -ForegroundColor Cyan
