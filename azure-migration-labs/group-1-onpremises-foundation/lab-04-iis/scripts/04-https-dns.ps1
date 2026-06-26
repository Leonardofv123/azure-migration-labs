<#
    Lab 04 - Script 04: HTTPS (certificado self-signed) + registro DNS remoto
    Executar DENTRO da VM WEB01, logado como CONTOSO\Administrator.
#>

$site = 'IntranetContoso'

# ────────────────────────────────────────────────────────────────────────
# Parte A - Certificado self-signed + binding HTTPS
# ────────────────────────────────────────────────────────────────────────
$cert = New-SelfSignedCertificate -DnsName 'intranet.contoso.local' -CertStoreLocation 'Cert:\LocalMachine\My'

New-WebBinding -Name $site -Protocol https -Port 443 -HostHeader 'intranet.contoso.local'

(Get-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)") |
    New-Item -Path "IIS:\SslBindings\0.0.0.0!443" | Out-Null

# Validacao do binding
Get-WebBinding -Name $site

# ────────────────────────────────────────────────────────────────────────
# Parte B - Registro DNS criado remotamente na DC01 (sem trocar de VM)
# ────────────────────────────────────────────────────────────────────────
Invoke-Command -ComputerName DC01 -ScriptBlock {
    Add-DnsServerResourceRecordA -ZoneName 'contoso.local' `
        -Name 'intranet' `
        -IPv4Address '192.168.10.30'
}

# Validacao do DNS
Resolve-DnsName -Name 'intranet.contoso.local'

Write-Host "`nAcesse: https://intranet.contoso.local" -ForegroundColor Cyan
Write-Host "O navegador vai exibir aviso de certificado nao confiavel (esperado, e self-signed)." -ForegroundColor Yellow
