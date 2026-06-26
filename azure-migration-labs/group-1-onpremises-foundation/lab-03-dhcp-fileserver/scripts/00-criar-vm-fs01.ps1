<#
    Lab 03 - Script 00: Criacao da VM FS01 (com 2 discos - sistema + dados)
    Executar no HOST (PC fisico), no PowerShell 7 como Administrador.
#>

$vmName      = 'contoso-fs01'
$vmPath      = 'D:\Hyper-V\contoso-lab\Virtual Machines'
$vhdPathOS   = 'D:\Hyper-V\contoso-lab\Virtual Hard Disks\contoso-fs01.vhdx'
$vhdPathData = 'D:\Hyper-V\contoso-lab\Virtual Hard Disks\contoso-fs01-data.vhdx'
$isoPath     = 'D:\Hyper-V\contoso-lab\ISOs\SERVER_EVAL_x64FRE_en-us.iso'
$switchName  = 'Lab-Internal'

if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {

    $vmParams = @{
        Name               = $vmName
        MemoryStartupBytes = 4GB
        Generation         = 2
        NewVHDPath         = $vhdPathOS
        NewVHDSizeBytes    = 60GB
        Path               = $vmPath
        SwitchName         = $switchName
    }
    New-VM @vmParams
    Write-Host "VM '$vmName' criada." -ForegroundColor Green

    Set-VMProcessor -VMName $vmName -Count 2

    Add-VMDvdDrive -VMName $vmName -Path $isoPath
    $dvd = Get-VMDvdDrive -VMName $vmName
    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

    # Segundo disco (30 GB) - vai virar o E:\ dentro da FS01 (dados)
    New-VHD -Path $vhdPathData -SizeBytes 30GB -Dynamic | Out-Null
    Add-VMHardDiskDrive -VMName $vmName -Path $vhdPathData
    Write-Host "Disco de dados (30 GB) anexado." -ForegroundColor Green

} else {
    Write-Host "VM '$vmName' ja existe - nada a fazer." -ForegroundColor Yellow
}

# Validacao
Get-VM -Name $vmName | Select-Object Name, State, Generation, MemoryStartup, ProcessorCount
Get-VMHardDiskDrive -VMName $vmName | Select-Object VMName, Path, ControllerLocation
Get-VMNetworkAdapter -VMName $vmName | Select-Object VMName, SwitchName
