<#
.SYNOPSIS
    Lab 09 - Prepara o onboarding do Azure Arc.
.DESCRIPTION
    Dois pontos que custaram tempo neste lab:

    1. Os resource providers precisam estar REGISTRADOS antes de qualquer
       tentativa. Sem isso, o azcmagent falha com HTTP 403 mesmo com todas
       as permissoes RBAC corretas. A mensagem fala em autorizacao, mas a
       causa e outra.

    2. O role precisa ser "Azure Connected Machine Resource Administrator"
       com escopo de SUBSCRIPTION. O role "Onboarding" nao cobre a acao
       register/action, e escopo de resource group nao e suficiente.
.NOTES
    Rodar no HOST.
#>

$ErrorActionPreference = 'Stop'

$subId = az account show --query id --output tsv

Write-Host "Registrando resource providers..." -ForegroundColor Cyan

az provider register --namespace Microsoft.HybridCompute
az provider register --namespace Microsoft.GuestConfiguration
az provider register --namespace Microsoft.HybridConnectivity

Write-Host "Aguardando o registro completar (2 a 5 minutos)..." -ForegroundColor Yellow

do {
    Start-Sleep -Seconds 20
    $estado = az provider show --namespace Microsoft.HybridCompute --query registrationState --output tsv
    Write-Host "  Microsoft.HybridCompute: $estado"
} while ($estado -ne 'Registered')

Write-Host "Providers registrados." -ForegroundColor Green
Write-Host ""
Write-Host "Criando Service Principal..." -ForegroundColor Cyan

az ad sp create-for-rbac `
    --name "sp-arc-onboarding" `
    --role "Azure Connected Machine Resource Administrator" `
    --scopes "/subscriptions/$subId"

Write-Host ""
Write-Host "GUARDE appId, password e tenant acima." -ForegroundColor Yellow
Write-Host "Apos o onboarding, remova o SP com:" -ForegroundColor Cyan
Write-Host '  az ad sp delete --id "<appId>"'
