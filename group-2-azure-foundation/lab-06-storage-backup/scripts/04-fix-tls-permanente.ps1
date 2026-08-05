<#
.SYNOPSIS
    Lab 06 - Forca TLS 1.2 no .NET Framework, de forma permanente.
.DESCRIPTION
    ESTE E O APRENDIZADO CENTRAL DO LAB 06.

    O ajuste via [Net.ServicePointManager]::SecurityProtocol vale apenas
    para o PROCESSO atual. Cada janela nova do PowerShell reinicia com o
    padrao do .NET Framework, que pode ser TLS 1.0.

    Como a Azure exige TLS 1.2 no minimo, isso quebra chamadas de
    autenticacao de forma silenciosa. E como o comportamento muda entre
    janelas, o problema parece aleatorio.

    Este script aplica o ajuste no registro do Windows, que persiste
    entre sessoes e sobrevive a reinicializacao.
.NOTES
    Rodar DENTRO DA FS01 (ou em qualquer servidor que va falar com a Azure).
    Requer PowerShell como Administrador.
#>

$ErrorActionPreference = 'Stop'

$caminhos = @(
    'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
    'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
)

foreach ($caminho in $caminhos) {
    [Microsoft.Win32.Registry]::SetValue($caminho, 'SchUseStrongCrypto', 1, 'DWord')
    Write-Host "SchUseStrongCrypto aplicado em: $caminho" -ForegroundColor Green
}

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan

Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' `
    -Name SchUseStrongCrypto -ErrorAction SilentlyContinue |
    Select-Object SchUseStrongCrypto

Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' `
    -Name SchUseStrongCrypto -ErrorAction SilentlyContinue |
    Select-Object SchUseStrongCrypto

Write-Host ""
Write-Host "Feche e reabra o PowerShell para o ajuste valer." -ForegroundColor Yellow
