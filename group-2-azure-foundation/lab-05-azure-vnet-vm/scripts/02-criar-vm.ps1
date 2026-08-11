<#
.SYNOPSIS
    Lab 05 - Cria a VM web na sub-rede web.
.DESCRIPTION
    Provisiona a vm-web-prod-eus2 com Windows Server 2022.
    Dois detalhes deste comando vieram de erro e sao importantes:
      1. --computer-name separado de --name, porque o nome de computador
         Windows (NetBIOS) tem limite de 15 caracteres
      2. ausencia de --os-disk-size-gb, porque a imagem exige no minimo 127 GB
.NOTES
    Rodar no HOST. Requer Azure CLI autenticado (az login).
#>

$rg   = 'rg-network-prod-eus2'
$vm   = 'vm-web-prod-eus2'
$user = 'azureadmin'

$senha = Read-Host "Senha do administrador da VM" -AsSecureString
$senhaPlana = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha)
)

Write-Host "Criando $vm ..." -ForegroundColor Cyan

az vm create `
    --resource-group $rg `
    --name $vm `
    --computer-name 'vmwebprodeus2' `
    --image 'MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest' `
    --size 'Standard_D2s_v3' `
    --vnet-name 'vnet-contoso-eus2' `
    --subnet 'snet-web' `
    --nsg 'nsg-web' `
    --public-ip-sku Standard `
    --storage-sku Premium_LRS `
    --admin-username $user `
    --admin-password $senhaPlana `
    --tags Environment=Prod Owner=Leo Project=Migration CostCenter=TI

$senhaPlana = $null

Write-Host ""
Write-Host "Validacao:" -ForegroundColor Cyan
az vm show `
    --resource-group $rg `
    --name $vm `
    --show-details `
    --query "{Nome:name, Estado:powerState, IP:publicIps, SKU:hardwareProfile.vmSize}" `
    --output table
