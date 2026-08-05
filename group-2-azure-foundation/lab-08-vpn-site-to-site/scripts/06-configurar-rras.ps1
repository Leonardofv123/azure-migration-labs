<#
.SYNOPSIS
    Lab 08 - Configura o RRAS na GW01 como gateway VPN on-premises.
.DESCRIPTION
    Instala RRAS, habilita NAT-T e cria a interface Site-to-Site.

    O NAT-T e necessario porque o protocolo ESP nao tem portas, o que
    impede o NAT tradicional de rastrear sessoes. Ele contorna isso
    encapsulando o ESP dentro de UDP 4500.
.NOTES
    Rodar no HOST. Acessa a GW01 via Invoke-Command.
    A GW01 reinicia ao final.
#>

$cred = Get-Credential -Message "Credencial local da GW01 (administrator)"

$ipGateway = Read-Host "IP publico do VPN Gateway do Azure"

$psk = Read-Host "Pre-Shared Key (a mesma da Connection)" -AsSecureString
$pskPlano = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
)

Invoke-Command -VMName 'contoso-gw01' -Credential $cred -ScriptBlock {
    param($destino, $segredo)

    Write-Host "Instalando RRAS..." -ForegroundColor Cyan
    Install-WindowsFeature -Name RemoteAccess, Routing -IncludeManagementTools

    if ((Get-RemoteAccess -ErrorAction SilentlyContinue).VpnS2SStatus -ne 'Installed') {
        Install-RemoteAccess -VpnType VpnS2S
    }

    Write-Host "Habilitando NAT-T..." -ForegroundColor Cyan
    Set-ItemProperty `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\PolicyAgent' `
        -Name 'AssumeUDPEncapsulationContextOnSendRule' `
        -Value 2 -Type DWord

    Write-Host "Desabilitando firewall (ambiente de lab)..." -ForegroundColor Yellow
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    Write-Host "Ajustando MTU para 1400..." -ForegroundColor Cyan
    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -NlMtuBytes 1400 -ErrorAction SilentlyContinue

    if (-not (Get-VpnS2SInterface -Name 'To-Azure' -ErrorAction SilentlyContinue)) {
        Add-VpnS2SInterface `
            -Name 'To-Azure' `
            -Destination $destino `
            -Protocol IKEv2 `
            -AuthenticationMethod PSKOnly `
            -SharedSecret $segredo `
            -IPv4Subnet '10.10.0.0/16:100' `
            -Persistent
        Write-Host "Interface To-Azure criada" -ForegroundColor Green
    } else {
        Set-VpnS2SInterface -Name 'To-Azure' -Destination $destino -SharedSecret $segredo
        Write-Host "Interface To-Azure atualizada" -ForegroundColor Yellow
    }

} -ArgumentList $ipGateway, $pskPlano

$pskPlano = $null

Write-Host ""
Write-Host "Reinicie a GW01 e depois conecte o tunel:" -ForegroundColor Cyan
Write-Host '  Connect-VpnS2SInterface -Name "To-Azure"'
