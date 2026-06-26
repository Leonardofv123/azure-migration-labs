<#
    Lab 01 - Script 01: Estrutura de pastas + configuracao de caminhos padrao
    Executar no HOST (PC fisico), no PowerShell 7 como Administrador.
#>

# Caminho base do projeto (ajuste o drive se necessario)
$base = 'D:\Hyper-V\contoso-lab'

# Subdiretorios que vamos precisar
$subpastas = @(
    "$base\Virtual Machines",      # configuracao (.vmcx) de cada VM
    "$base\Virtual Hard Disks",    # discos virtuais (.vhdx)
    "$base\ISOs"                   # ISO do Windows Server fica aqui
)

# Cria cada pasta, so se ainda nao existir (idempotencia)
foreach ($pasta in $subpastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -Path $pasta -ItemType Directory -Force | Out-Null
        Write-Host "Criada: $pasta" -ForegroundColor Green
    } else {
        Write-Host "Ja existe: $pasta" -ForegroundColor Yellow
    }
}

# Define essas pastas como padrao do Hyper-V para novas VMs.
# Nao move VMs existentes; so afeta as proximas criadas.
Set-VMHost -VirtualMachinePath "$base\Virtual Machines" `
           -VirtualHardDiskPath "$base\Virtual Hard Disks"

# Validacao
Get-VMHost | Select-Object VirtualMachinePath, VirtualHardDiskPath
