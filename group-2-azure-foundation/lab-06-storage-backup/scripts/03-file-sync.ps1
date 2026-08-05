<#
.SYNOPSIS
    Lab 06 - Configura o Azure File Sync.
.DESCRIPTION
    Parte roda no HOST (Storage Sync Service e Sync Group),
    parte roda DENTRO DA FS01 (registro do servidor).

    IMPORTANTE: rode 04-fix-tls-permanente.ps1 na FS01 ANTES deste script.
    Sem isso o registro falha de forma intermitente, porque o .NET Framework
    usa TLS 1.0 por padrao e a Azure exige 1.2 no minimo.
.NOTES
    O agente StorageSyncAgent_WS2022.msi (42,1 MB) precisa estar instalado
    na FS01. Atencao: um arquivo chamado UpdateDetails.xml de 3,3 KB aparece
    nas buscas e NAO e o instalador.
#>

$ErrorActionPreference = 'Stop'

$rg  = 'rg-storage-prod-eus2'
$loc = 'eastus2'

# ---- PARTE 1: no HOST ----

$syncService = Get-AzStorageSyncService -ResourceGroupName $rg -Name 'sync-contoso-eus2' -ErrorAction SilentlyContinue

if (-not $syncService) {
    New-AzStorageSyncService `
        -ResourceGroupName $rg `
        -Name 'sync-contoso-eus2' `
        -Location $loc
    Write-Host "Storage Sync Service criado" -ForegroundColor Green

    $syncService = Get-AzStorageSyncService -ResourceGroupName $rg -Name 'sync-contoso-eus2'
}

if (-not (Get-AzStorageSyncGroup -ParentObject $syncService -Name 'sync-vendas' -ErrorAction SilentlyContinue)) {
    New-AzStorageSyncGroup -ParentObject $syncService -Name 'sync-vendas'
    Write-Host "Sync Group criado: sync-vendas" -ForegroundColor Green
}

Write-Host ""
Write-Host "PARTE 1 concluida no host." -ForegroundColor Green
Write-Host ""
Write-Host "PARTE 2: rode o bloco abaixo DENTRO DA FS01," -ForegroundColor Cyan
Write-Host "na MESMA janela do PowerShell:" -ForegroundColor Cyan
Write-Host ""
Write-Host '    New-Item -ItemType Directory -Path "C:\VendasLocal" -Force'
Write-Host '    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
Write-Host '    Connect-AzAccount'
Write-Host '    Register-AzStorageSyncServer -ResourceGroupName "rg-storage-prod-eus2" -StorageSyncServiceName "sync-contoso-eus2"'
Write-Host ""
Write-Host "Depois, crie no portal:" -ForegroundColor Cyan
Write-Host "  Cloud Endpoint  -> file share 'vendas'"
Write-Host "  Server Endpoint -> C:\VendasLocal (cloud tiering desabilitado)"
