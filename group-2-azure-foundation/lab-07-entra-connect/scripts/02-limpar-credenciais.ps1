<#
.SYNOPSIS
    Lab 07 - Lista e remove credenciais cacheadas do Windows.
.DESCRIPTION
    Credenciais guardadas pelo Windows Credential Manager podem interferir
    na autenticacao do Entra Connect, fazendo o wizard recusar uma conta
    que funciona normalmente em outras ferramentas.

    A que causou problema neste lab:
      WindowsLive:target=virtualapp/didlogical
.NOTES
    Rodar no HOST. Acessa a DC01 via Invoke-Command.
#>

$cred = Get-Credential -Message "Credencial do dominio (contoso\administrator)"

Write-Host "Credenciais cacheadas na DC01:" -ForegroundColor Cyan
Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {
    cmdkey /list
}

$remover = Read-Host "Remover a credencial WindowsLive:target=virtualapp/didlogical? (S/N)"

if ($remover -eq 'S') {
    Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {
        cmdkey /delete:"WindowsLive:target=virtualapp/didlogical"
    }
    Write-Host "Credencial removida" -ForegroundColor Green
}
