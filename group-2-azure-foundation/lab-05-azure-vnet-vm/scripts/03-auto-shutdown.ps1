<#
.SYNOPSIS
    Lab 05 - Agenda desligamento automatico da VM.
.DESCRIPTION
    Critico nesta VM: ela usa Standard_D2s_v3, fora do tier gratuito.
    Sem auto-shutdown, o credito da subscription some em poucas semanas
    de maquina esquecida ligada.
.NOTES
    Rodar no HOST.
#>

$rg   = 'rg-network-prod-eus2'
$vm   = 'vm-web-prod-eus2'
$hora = '2200'

az vm auto-shutdown `
    --resource-group $rg `
    --name $vm `
    --time $hora

Write-Host "Auto-shutdown configurado para $hora" -ForegroundColor Green
