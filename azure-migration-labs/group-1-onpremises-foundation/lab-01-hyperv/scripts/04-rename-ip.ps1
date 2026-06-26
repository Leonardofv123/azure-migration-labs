<#
    Lab 01 - Script 04: Renomear a VM + configurar IP fixo
    Executar DENTRO da VM (contoso-dc01), no PowerShell como Administrador.

    Depois de rodar, reiniciar a VM com: Restart-Computer -Force
#>

$novoNome      = 'DC01'
$nomeAdaptador = 'Ethernet'           # confirme com: Get-NetAdapter
$ip            = '192.168.10.10'      # IP fixo do futuro Domain Controller
$prefixo       = 24                   # /24
$gateway       = '192.168.10.1'       # o host, que faz NAT
$dns           = '192.168.10.10'      # ele mesmo (sera servidor DNS no Lab 02)

# 1) Renomeia o computador (exige reboot para aplicar)
if ($env:COMPUTERNAME -ne $novoNome) {
    Rename-Computer -NewName $novoNome -Force
    Write-Host "Nome alterado para '$novoNome'. Reinicializacao necessaria." -ForegroundColor Green
} else {
    Write-Host "Nome ja esta correto." -ForegroundColor Yellow
}

# 2) Remove IP dinamico (DHCP) existente, para nao conflitar
Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# 3) Define o IP fixo e o gateway
New-NetIPAddress -InterfaceAlias $nomeAdaptador `
                  -IPAddress $ip `
                  -PrefixLength $prefixo `
                  -DefaultGateway $gateway

# 4) Define o DNS do adaptador
Set-DnsClientServerAddress -InterfaceAlias $nomeAdaptador -ServerAddresses $dns

Write-Host "IP fixo $ip configurado no adaptador '$nomeAdaptador'." -ForegroundColor Green

# Validacao
Get-NetIPAddress -InterfaceAlias $nomeAdaptador -AddressFamily IPv4 | Select-Object IPAddress, PrefixLength
Get-DnsClientServerAddress -InterfaceAlias $nomeAdaptador | Select-Object InterfaceAlias, ServerAddresses

Write-Host "`nReinicie a VM para aplicar o nome novo: Restart-Computer -Force" -ForegroundColor Cyan
