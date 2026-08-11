<#
.SYNOPSIS
    Lab 07 - Valida o Password Hash Sync de ponta a ponta.
.DESCRIPTION
    Confirmar que os usuarios aparecem no Entra ID NAO e validacao
    suficiente: isso so prova que os objetos sincronizaram.

    O teste real e autenticar. Este script reseta a senha de um usuario
    no AD on-premises, forca o ciclo de sincronizacao, e instrui o login
    de verificacao.
.NOTES
    Rodar no HOST. Acessa a DC01 via Invoke-Command.
#>

param(
    [string]$Usuario = 'ana.souza'
)

$cred = Get-Credential -Message "Credencial do dominio (contoso\administrator)"

$novaSenha = Read-Host "Nova senha para $Usuario" -AsSecureString

Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {
    param($user, $senha)

    Set-ADAccountPassword -Identity $user -Reset -NewPassword $senha
    Set-ADUser -Identity $user -ChangePasswordAtLogon $false

    Write-Host "Senha resetada para $user" -ForegroundColor Green

    Start-ADSyncSyncCycle -PolicyType Delta
    Write-Host "Ciclo de sincronizacao disparado" -ForegroundColor Green

} -ArgumentList $Usuario, $novaSenha

Write-Host ""
Write-Host "Aguarde 2 a 5 minutos, depois:" -ForegroundColor Cyan
Write-Host "  1. Abra myaccount.microsoft.com numa janela anonima"
Write-Host "  2. Faca login com $Usuario@<tenant>.onmicrosoft.com"
Write-Host "  3. Use a nova senha"
Write-Host ""
Write-Host "Login bem-sucedido confirma o hash sincronizando de ponta a ponta." -ForegroundColor Yellow
