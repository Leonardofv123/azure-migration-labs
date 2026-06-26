<#
    Lab 01 - Script 02: vSwitch interno "Lab-Internal" + NAT (192.168.10.0/24)
    Executar no HOST (PC fisico), no PowerShell 7 como Administrador.

    Conceitos:
      vSwitch Internal = VMs falam entre si e com o host, sem sair direto pra internet.
      Gateway          = o host (192.168.10.1) e a porta de saida da rede do lab.
      NAT              = traduz a rede privada 192.168.10.0/24 para a internet do host.
#>

$switchName = 'Lab-Internal'
$natName    = 'Lab-NAT'
$hostIP     = '192.168.10.1'
$subnet     = '192.168.10.0/24'

# 1) Cria o vSwitch interno (idempotente)
if (-not (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name $switchName -SwitchType Internal
    Write-Host "vSwitch '$switchName' criado." -ForegroundColor Green
} else {
    Write-Host "vSwitch '$switchName' ja existe." -ForegroundColor Yellow
}

# 2) Da ao adaptador virtual do host o IP fixo (vira o gateway das VMs)
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*$switchName*" }
if (-not (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $hostIP -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -IPAddress $hostIP -PrefixLength 24 -InterfaceIndex $adapter.ifIndex
    Write-Host "IP $hostIP atribuido ao adaptador '$($adapter.Name)'." -ForegroundColor Green
} else {
    Write-Host "IP $hostIP ja estava configurado." -ForegroundColor Yellow
}

# 3) Cria o NAT que da internet as VMs atraves do host
if (-not (Get-NetNat -Name $natName -ErrorAction SilentlyContinue)) {
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $subnet
    Write-Host "NAT '$natName' criado para a rede $subnet." -ForegroundColor Green
} else {
    Write-Host "NAT '$natName' ja existe." -ForegroundColor Yellow
}

# Validacao
Get-VMSwitch -Name $switchName | Select-Object Name, SwitchType
Get-NetIPAddress -IPAddress $hostIP | Select-Object IPAddress, InterfaceAlias
Get-NetNat -Name $natName | Select-Object Name, InternalIPInterfaceAddressPrefix
