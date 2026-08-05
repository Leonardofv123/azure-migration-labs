<#
.SYNOPSIS
    Lab 09 - Conecta uma VM on-premises ao Azure Arc.
.DESCRIPTION
    O Arc estende o plano de controle do Azure para maquinas que nao
    estao nele. Depois de conectada, a maquina ganha um Resource ID e
    aceita extensoes, Azure Policy e RBAC como uma VM nativa.

    AJUSTE DE MTU: aplicado ANTES do onboarding, de proposito.
    Com MTU 1500 nesta rede virtual, o download do agente trava sem erro:
    o handshake TCP passa (pacotes pequenos), mas a transferencia morre
    (pacotes cheios sendo fragmentados e descartados). Diagnosticar isso
    custou tempo na FS01. Na WEB01, aplicado preventivamente, rodou limpo.
.NOTES
    Rodar no HOST. Uma VM por vez.
.EXAMPLE
    .\05-instalar-arc.ps1 -VM contoso-dc01 -Dominio
    .\05-instalar-arc.ps1 -VM contoso-fs01 -Dominio
#>

param(
    [Parameter(Mandatory)]
    [string]$VM,

    [switch]$Dominio
)

$ErrorActionPreference = 'Stop'

$subId  = az account show --query id --output tsv
$tenant = az account show --query tenantId --output tsv
$rg     = 'rg-monitor-prod-eus2'
$loc    = 'eastus2'

$msg = if ($Dominio) { "Credencial do dominio (contoso\administrator)" }
       else { "Credencial local da VM (administrator)" }

$cred = Get-Credential -Message $msg

$appId = Read-Host "appId do Service Principal"
$secret = Read-Host "password do Service Principal" -AsSecureString
$secretPlano = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
)

$session = New-PSSession -VMName $VM -Credential $cred

Write-Host "Ajustando MTU para 1400 (antes do onboarding)..." -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -NlMtuBytes 1400
    Get-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 |
        Select-Object InterfaceAlias, NlMtu
}

Write-Host "Baixando e instalando o agente do Arc..." -ForegroundColor Cyan

Invoke-Command -Session $session -ScriptBlock {
    param($app, $sec, $rgName, $tenantId, $location, $subscription)

    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Invoke-WebRequest `
        -UseBasicParsing `
        -Uri 'https://aka.ms/azcmagent-windows' `
        -OutFile "$env:TEMP\install_windows_azcmagent.ps1" `
        -TimeoutSec 120

    & "$env:TEMP\install_windows_azcmagent.ps1"

    & "$env:PROGRAMFILES\AzureConnectedMachineAgent\azcmagent.exe" connect `
        --service-principal-id $app `
        --service-principal-secret $sec `
        --resource-group $rgName `
        --tenant-id $tenantId `
        --location $location `
        --subscription-id $subscription `
        --cloud AzureCloud

} -ArgumentList $appId, $secretPlano, $rg, $tenant, $loc, $subId

$secretPlano = $null
Remove-PSSession $session

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
az connectedmachine list --resource-group $rg --query "[].{Nome:name, Status:status}" --output table
