<#
.SYNOPSIS
    Lab 07 - Verifica o AD antes de instalar o Entra Connect.
.DESCRIPTION
    Confere se existem contas com UPN conflitante ou mal formado,
    que causariam erro no meio da sincronizacao.
.NOTES
    Rodar no HOST. Acessa a DC01 via Invoke-Command.
#>

$cred = Get-Credential -Message "Credencial do dominio (contoso\administrator)"

Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {

    Write-Host "Usuarios e seus UPNs:" -ForegroundColor Cyan
    Get-ADUser -Filter * -Properties UserPrincipalName |
        Select-Object Name, SamAccountName, UserPrincipalName |
        Format-Table -AutoSize

    Write-Host "Usuarios SEM UPN definido:" -ForegroundColor Yellow
    Get-ADUser -Filter * -Properties UserPrincipalName |
        Where-Object { -not $_.UserPrincipalName } |
        Select-Object Name, SamAccountName

    Write-Host "Total de usuarios:" -ForegroundColor Cyan
    (Get-ADUser -Filter *).Count
}
