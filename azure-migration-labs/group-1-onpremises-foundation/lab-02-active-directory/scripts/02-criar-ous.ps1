<#
    Lab 02 - Script 02: Criar as OUs (uma por setor)
    Executar DENTRO da VM (DC01), no PowerShell como Administrador.
#>

# Raiz do dominio em formato LDAP (DC = Domain Component)
$ouBase = 'DC=contoso,DC=local'

# Departamentos que viram OUs
$departamentos = 'TI','Vendas','Financeiro','Diretoria','ServiceAccounts'

foreach ($ou in $departamentos) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $ouBase `
            -ProtectedFromAccidentalDeletion $true   # trava contra exclusao acidental
        Write-Host "OU criada: $ou" -ForegroundColor Green
    } else {
        Write-Host "OU ja existe: $ou" -ForegroundColor Yellow
    }
}

# Validacao
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
