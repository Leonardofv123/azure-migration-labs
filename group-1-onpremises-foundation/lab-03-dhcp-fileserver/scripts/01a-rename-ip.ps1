<#
    Lab 03 - Script 01a: Renomear FS01 + configurar IP fixo
    Executar DENTRO da VM FS01, no PowerShell como Administrador.

    Depois de rodar, reiniciar com: Restart-Computer -Force
#>

$novoNome      = 'FS01'
$nomeAdaptador = 'Ethernet'           # confirme com: Get-NetAdapter
$ip            = '192.168.10.20'      # IP fixo da FS01
$prefixo       = 24
$gateway       = '192.168.10.1'       # o host, que faz NAT
$dns           = '192.168.10.10'      # aponta para o DC01 (nao para si mesma!)

# 1) Renomeia o computador
if ($env:COMPUTERNAME -ne $novoNome) {
    Rename-Computer -NewName $novoNome -Force
    Write-Host "Nome alterado para '$novoNome'. Reinicializacao necessaria." -ForegroundColor Green
} else {
    Write-Host "Nome ja esta correto." -ForegroundColor Yellow
}

# 2) Remove IP dinamico existente
Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# 3) Define o IP fixo e o gateway
New-NetIPAddress -InterfaceAlias $nomeAdaptador `
                  -IPAddress $ip `
                  -PrefixLength $prefixo `
                  -DefaultGateway $gateway

# 4) Define o DNS - aponta para o DC01, essencial para achar o dominio
Set-DnsClientServerAddress -InterfaceAlias $nomeAdaptador -ServerAddresses $dns

Write-Host "IP fixo $ip configurado, DNS apontando para DC01 ($dns)." -ForegroundColor Green

# Validacao
Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 | Select-Object IPAddress, PrefixLength
Get-DnsClientServerAddress -InterfaceAlias $nomeAdaptador | Select-Object InterfaceAlias, ServerAddresses
Resolve-DnsName -Name 'contoso.local'

Write-Host "`nReinicie a VM para aplicar o nome novo: Restart-Computer -Force" -ForegroundColor Cyan
