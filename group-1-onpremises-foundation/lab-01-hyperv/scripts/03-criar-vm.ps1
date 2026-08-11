<#
    Lab 01 - Script 03: Criacao da VM contoso-dc01
    Executar no HOST (PC fisico), no PowerShell 7 como Administrador.

    VM: 4 GB RAM, 2 vCPU, Generation 2, disco dinamico de 60 GB,
        conectada ao vSwitch Lab-Internal, com a ISO acoplada para boot.
#>

$vmName     = 'contoso-dc01'
$vmPath     = 'D:\Hyper-V\contoso-lab\Virtual Machines'
$vhdPath    = 'D:\Hyper-V\contoso-lab\Virtual Hard Disks\contoso-dc01.vhdx'
$isoPath    = 'D:\Hyper-V\contoso-lab\ISOs\SERVER_EVAL_x64FRE_en-us.iso'
$switchName = 'Lab-Internal'

if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {

    # Splatting: parametros da New-VM organizados numa hashtable
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
    Write-Host "VM '$vmName' criada." -ForegroundColor Green

    # 2 vCPUs (padrao e 1)
    Set-VMProcessor -VMName $vmName -Count 2

    # Acopla a ISO como DVD virtual
    Add-VMDvdDrive -VMName $vmName -Path $isoPath

    # Boot prioritario pelo DVD (instalador do Windows)
    $dvd = Get-VMDvdDrive -VMName $vmName
    Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

    Write-Host "VM configurada: 2 vCPU, ISO conectada, boot no DVD." -ForegroundColor Green

} else {
    Write-Host "VM '$vmName' ja existe - nada a fazer." -ForegroundColor Yellow
}

# Validacao
Get-VM -Name $vmName | Select-Object Name, State, Generation, MemoryStartup, ProcessorCount
Get-VMNetworkAdapter -VMName $vmName | Select-Object VMName, SwitchName
Get-VMDvdDrive -VMName $vmName | Select-Object VMName, Path
