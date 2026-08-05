<#
    Lab 03 - Script 03: File Server (disco, pastas, permissoes NTFS + SMB)
    Executar DENTRO da VM FS01, logado como CONTOSO\Administrator.
#>

Install-WindowsFeature FS-FileServer -IncludeManagementTools

# ────────────────────────────────────────────────────────────────────────
# Preparar o segundo disco (vem RAW / sem particao)
# ────────────────────────────────────────────────────────────────────────
Initialize-Disk -Number 1 -PartitionStyle GPT
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E
Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel "Dados" -Confirm:$false

# ────────────────────────────────────────────────────────────────────────
# Criar as pastas por departamento
# ────────────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path "E:\Shares\Vendas" -Force
New-Item -ItemType Directory -Path "E:\Shares\Financeiro" -Force
New-Item -ItemType Directory -Path "E:\Shares\TI" -Force

# ────────────────────────────────────────────────────────────────────────
# Permissoes NTFS - cada pasta isolada pelo grupo do setor (Lab 02)
# /inheritance:r remove a heranca do disco (comeca do zero)
# (OI)(CI) = aplica a objetos e subpastas. M = Modify, F = Full Control
# ────────────────────────────────────────────────────────────────────────

# Vendas
icacls "E:\Shares\Vendas" /inheritance:r
icacls "E:\Shares\Vendas" /grant "CONTOSO\GG_Vendas:(OI)(CI)M"
icacls "E:\Shares\Vendas" /grant "CONTOSO\Domain Admins:(OI)(CI)F"
icacls "E:\Shares\Vendas" /grant "SYSTEM:(OI)(CI)F"

# Financeiro
icacls "E:\Shares\Financeiro" /inheritance:r
icacls "E:\Shares\Financeiro" /grant "CONTOSO\GG_Financeiro:(OI)(CI)M"
icacls "E:\Shares\Financeiro" /grant "CONTOSO\Domain Admins:(OI)(CI)F"
icacls "E:\Shares\Financeiro" /grant "SYSTEM:(OI)(CI)F"

# TI
icacls "E:\Shares\TI" /inheritance:r
icacls "E:\Shares\TI" /grant "CONTOSO\GG_TI:(OI)(CI)M"
icacls "E:\Shares\TI" /grant "CONTOSO\Domain Admins:(OI)(CI)F"
icacls "E:\Shares\TI" /grant "SYSTEM:(OI)(CI)F"

# ────────────────────────────────────────────────────────────────────────
# Compartilhamento SMB (a "porta" de rede - quem realmente trava o
# acesso e o NTFS acima; regra de ouro: "share liberal, NTFS restritivo")
# ────────────────────────────────────────────────────────────────────────
New-SmbShare -Name "Vendas" -Path "E:\Shares\Vendas" -FullAccess "CONTOSO\Domain Admins" -ChangeAccess "CONTOSO\GG_Vendas"
New-SmbShare -Name "Financeiro" -Path "E:\Shares\Financeiro" -FullAccess "CONTOSO\Domain Admins" -ChangeAccess "CONTOSO\GG_Financeiro"
New-SmbShare -Name "TI" -Path "E:\Shares\TI" -FullAccess "CONTOSO\Domain Admins" -ChangeAccess "CONTOSO\GG_TI"

# Validacao
Get-SmbShare
icacls "E:\Shares\Vendas"
icacls "E:\Shares\Financeiro"
icacls "E:\Shares\TI"
