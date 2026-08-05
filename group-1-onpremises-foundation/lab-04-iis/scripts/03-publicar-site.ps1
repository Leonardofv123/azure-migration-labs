<#
    Lab 04 - Script 03: Publicar o site IntranetContoso
    Executar DENTRO da VM WEB01, logado como CONTOSO\Administrator.
#>

$site = 'IntranetContoso'
$pool = 'IntranetPool'
$root = 'C:\inetpub\intranet'

# Cria a pasta e uma pagina inicial simples
New-Item -ItemType Directory -Path $root -Force | Out-Null
'<h1>Intranet Contoso - Migration Lab</h1>' | Out-File "$root\index.html" -Encoding utf8

# App pool dedicado - cada site no seu proprio processo isolado
if (-not (Test-Path "IIS:\AppPools\$pool")) { New-WebAppPool -Name $pool }
Set-ItemProperty "IIS:\AppPools\$pool" managedRuntimeVersion 'v4.0'

# Cria o site, ligado ao app pool, respondendo pelo host header na porta 80
if (-not (Get-Website -Name $site)) {
    New-Website -Name $site -PhysicalPath $root -ApplicationPool $pool `
        -HostHeader 'intranet.contoso.local' -Port 80
}

Write-Host "Site '$site' publicado." -ForegroundColor Green

# Validacao
Get-Website | Format-Table -AutoSize
Get-WebAppPoolState -Name $pool
