<#
.SYNOPSIS
    Lab 06 - Cria Storage Account, File Share e Blob Container.
.DESCRIPTION
    O nome da Storage Account precisa ser unico no mundo todo,
    so letras minusculas e numeros. Dai o sufixo aleatorio.
.NOTES
    Rodar no HOST.
#>

$ErrorActionPreference = 'Stop'

$rg   = 'rg-storage-prod-eus2'
$loc  = 'eastus2'
$tags = @{
    Environment = 'Prod'
    Owner       = 'Leo'
    Project     = 'Migration'
    CostCenter  = 'TI'
}

if (-not (Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rg -Location $loc -Tag $tags
    Write-Host "Resource Group criado: $rg" -ForegroundColor Green
}

$existente = Get-AzStorageAccount -ResourceGroupName $rg -ErrorAction SilentlyContinue |
    Where-Object { $_.StorageAccountName -like 'stcontosoeus2*' } |
    Select-Object -First 1

if ($existente) {
    $sa = $existente
    Write-Host "Storage Account ja existe: $($sa.StorageAccountName)" -ForegroundColor Yellow
} else {
    $nome = "stcontosoeus2$(Get-Random -Maximum 9999)"

    $sa = New-AzStorageAccount `
        -ResourceGroupName $rg `
        -Name $nome `
        -Location $loc `
        -SkuName Standard_LRS `
        -Kind StorageV2 `
        -MinimumTlsVersion TLS1_2 `
        -Tag $tags

    Write-Host "Storage Account criada: $nome" -ForegroundColor Green
}

$ctx = $sa.Context

if (-not (Get-AzStorageShare -Name 'vendas' -Context $ctx -ErrorAction SilentlyContinue)) {
    New-AzStorageShare -Name 'vendas' -Context $ctx
    Write-Host "File Share criado: vendas" -ForegroundColor Green
}

if (-not (Get-AzStorageContainer -Name 'documentos' -Context $ctx -ErrorAction SilentlyContinue)) {
    New-AzStorageContainer -Name 'documentos' -Context $ctx -Permission Off
    Write-Host "Blob Container criado: documentos (privado)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
Get-AzStorageAccount -ResourceGroupName $rg -Name $sa.StorageAccountName |
    Select-Object StorageAccountName, @{N='SKU';E={$_.Sku.Name}}, Kind, MinimumTlsVersion

Write-Host "Guarde este nome, sera usado no Lab 09:" -ForegroundColor Cyan
Write-Host "  $($sa.StorageAccountName)"
