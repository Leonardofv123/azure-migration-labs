<#
    Lab 02 - Script 03: Criar usuarios e grupos em massa a partir do CSV
    Executar DENTRO da VM (DC01), no PowerShell como Administrador.

    Le o arquivo usuarios-exemplo.csv (formato: Nome,Sobrenome,Departamento,Cargo)
    e cria, para cada linha: o usuario na OU certa + o grupo GG_<Depto> + membership.

    Ajuste o caminho do CSV conforme onde ele estiver na VM.
#>

$csvPath = '.\usuarios-exemplo.csv'

# Senha padrao em formato protegido (SecureString)
$senhaPadrao = ConvertTo-SecureString 'Contoso@2026!' -AsPlainText -Force

Import-Csv $csvPath | ForEach-Object {

    # Login no padrao nome.sobrenome, minusculo
    $login  = ('{0}.{1}' -f $_.Nome, $_.Sobrenome).ToLower()

    # OU do departamento daquele funcionario
    $ouPath = "OU=$($_.Departamento),DC=contoso,DC=local"

    # Atributos do usuario (splatting)
    $params = @{
        Name                  = "$($_.Nome) $($_.Sobrenome)"
        GivenName             = $_.Nome
        Surname               = $_.Sobrenome
        SamAccountName        = $login
        UserPrincipalName     = "$login@contoso.local"
        Path                  = $ouPath
        Title                 = $_.Cargo
        Department            = $_.Departamento
        AccountPassword       = $senhaPadrao
        Enabled               = $true
        ChangePasswordAtLogon = $true   # forca troca de senha no 1o login
    }

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue)) {
        New-ADUser @params

        # Garante o grupo do departamento e adiciona o usuario
        $grupo = "GG_$($_.Departamento)"   # GG = Global Group
        if (-not (Get-ADGroup -Filter "Name -eq '$grupo'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $grupo -GroupScope Global -Path $ouPath
        }
        Add-ADGroupMember -Identity $grupo -Members $login
        Write-Host "Criado: $login -> $($_.Departamento)" -ForegroundColor Green
    } else {
        Write-Host "Ja existe: $login" -ForegroundColor Yellow
    }
}
