<#
.SYNOPSIS
    Lab 06 - Cria o Recovery Services Vault e protege a VM do Lab 05.
.DESCRIPTION
    O Vault fica num Resource Group separado da rede e da VM.
    Isso e governanca: backup e responsabilidade de outro time em
    ambiente real, e separar por RG facilita aplicar permissoes diferentes.
.NOTES
    Rodar no HOST. Requer a VM do Lab 05 existente.
#>

$ErrorActionPreference = 'Stop'

$rgBackup = 'rg-backup-prod-eus2'
$rgVM     = 'rg-network-prod-eus2'
$vm       = 'vm-web-prod-eus2'
$loc      = 'eastus2'

$tags = @{
    Environment = 'Prod'
    Owner       = 'Leo'
    Project     = 'Migration'
    CostCenter  = 'TI'
}

if (-not (Get-AzResourceGroup -Name $rgBackup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rgBackup -Location $loc -Tag $tags
    Write-Host "Resource Group criado: $rgBackup" -ForegroundColor Green
}

$vault = Get-AzRecoveryServicesVault -Name 'rsv-contoso-eus2' -ResourceGroupName $rgBackup -ErrorAction SilentlyContinue

if (-not $vault) {
    $vault = New-AzRecoveryServicesVault `
        -Name 'rsv-contoso-eus2' `
        -ResourceGroupName $rgBackup `
        -Location $loc
    Write-Host "Vault criado: rsv-contoso-eus2" -ForegroundColor Green
}

Set-AzRecoveryServicesVaultContext -Vault $vault

$pol = Get-AzRecoveryServicesBackupProtectionPolicy -Name 'DefaultPolicy'

$jaProtegida = Get-AzRecoveryServicesBackupItem `
    -BackupManagementType AzureVM `
    -WorkloadType AzureVM `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$vm*" }

if (-not $jaProtegida) {
    Enable-AzRecoveryServicesBackupProtection `
        -Policy $pol `
        -Name $vm `
        -ResourceGroupName $rgVM
    Write-Host "Protecao habilitada para $vm" -ForegroundColor Green
} else {
    Write-Host "VM ja protegida" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM |
    Select-Object Name, ProtectionStatus, LastBackupStatus

$rodarAgora = Read-Host "Disparar backup sob demanda agora? (S/N)"
if ($rodarAgora -eq 'S') {
    $item = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM
    Backup-AzRecoveryServicesBackupItem -Item $item
    Write-Host "Backup disparado. Acompanhe com:" -ForegroundColor Green
    Write-Host "  Get-AzRecoveryServicesBackupJob -Status InProgress"
}
