<#
    Lab 02 - Script 04: Validacao final
    Executar DENTRO da VM (DC01), no PowerShell como Administrador.
#>

# 1) Usuarios por OU
Write-Host "`n=== USUARIOS POR OU ===" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase 'DC=contoso,DC=local' -Properties Department |
    Where-Object { $_.DistinguishedName -notlike '*Users*' -and $_.DistinguishedName -notlike '*Domain Controllers*' } |
    Select-Object SamAccountName, Department |
    Sort-Object Department |
    Format-Table -AutoSize

# 2) Grupos GG_ e contagem de membros (com @() para contagem robusta)
Write-Host "=== GRUPOS DE DEPARTAMENTO ===" -ForegroundColor Cyan
Get-ADGroup -Filter "Name -like 'GG_*'" |
    ForEach-Object {
        $membros = @(Get-ADGroupMember -Identity $_.Name).Count
        [PSCustomObject]@{ Grupo = $_.Name; Membros = $membros }
    } | Format-Table -AutoSize

# 3) Zona DNS
Write-Host "=== ZONA DNS ===" -ForegroundColor Cyan
Get-DnsServerZone -Name 'contoso.local' | Select-Object ZoneName, ZoneType, IsDsIntegrated
