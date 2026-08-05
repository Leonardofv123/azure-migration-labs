<#
.SYNOPSIS
    Lab 07 - Forca um ciclo de sincronizacao do Entra Connect.
.DESCRIPTION
    Por padrao o Entra Connect sincroniza a cada 30 minutos.
    Este script dispara um ciclo delta imediato, util para testar
    alteracoes sem esperar.

    Use -Inicial para um ciclo completo (Initial) em vez de delta.
.NOTES
    Rodar no HOST. Acessa a DC01 via Invoke-Command.
#>

param(
    [switch]$Inicial
)

$cred = Get-Credential -Message "Credencial do dominio (contoso\administrator)"
$tipo = if ($Inicial) { 'Initial' } else { 'Delta' }

Write-Host "Disparando ciclo $tipo ..." -ForegroundColor Cyan

Invoke-Command -VMName 'contoso-dc01' -Credential $cred -ScriptBlock {
    param($policyType)
    Start-ADSyncSyncCycle -PolicyType $policyType
} -ArgumentList $tipo

Write-Host "Ciclo disparado. Aguarde alguns minutos e confira no portal." -ForegroundColor Green
