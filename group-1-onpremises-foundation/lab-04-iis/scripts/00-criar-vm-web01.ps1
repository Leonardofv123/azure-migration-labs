<#
    Lab 04 - Script 00: Criacao da VM WEB01
    Executar no HOST (PC fisico), no PowerShell 7 como Administrador.
#>

$vmName     = 'contoso-web01'
$vmPath     = 'D:\Hyper-V\contoso-lab\Virtual Machines'
$vhdPath    = 'D:\Hyper-V\contoso-lab\Virtual Hard Disks\contoso-web01.vhdx'
$isoPath    = 'D:\Hyper-V\contoso-lab\ISOs\SERVER_EVAL_x64FRE_en-us.iso'
$switchName = 'Lab-Internal'

if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {
    $vmParams = @{
        Name               = $vmName
        MemoryStartupBytes = 4GB
        Generation         = 2
        NewVHDPath         = $vhdPath
        NewVHDSizeBytes    = 60GB
        Path               = $vmPath
        SwitchName         = $switchName
    }
    New-VM @vmParams
    Set-VMProcessor -VMName $vmName -Count 2
    Add-VMDvdDrive -VMName $vmName -Path $isoPath
    $dvd = Get-VMDvdDrive -VMName $vmName
    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd
    Write-Host "VM '$vmName' criada e configurada." -ForegroundColor Green
} else {
    Write-Host "VM '$vmName' ja existe." -ForegroundColor Yellow
}

# Validacao
Get-VM -Name $vmName | Select-Object Name, State, Generation, MemoryStartup, ProcessorCount
Get-VMNetworkAdapter -VMName $vmName | Select-Object VMName, SwitchName

<#
    NOTA DE RAM: com 16 GB de RAM total no host, rodar DC01 + FS01 + WEB01
    simultaneamente deixa pouca folga. Se necessario, desligue a FS01
    (nao usada neste lab) antes de ligar a WEB01.
#>
