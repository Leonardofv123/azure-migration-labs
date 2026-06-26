<#
    Lab 02 - Script 01: Instalar AD DS e promover DC01 a controlador de dominio
    Executar DENTRO da VM (DC01), no PowerShell como Administrador.

    Cria a floresta contoso.local e instala o DNS junto.
    A VM REINICIA sozinha ao final. Ao voltar, login como CONTOSO\Administrator.
#>

# Instala o papel de controlador de dominio + ferramentas graficas (ADUC etc.)
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Cria uma floresta nova (este e o primeiro DC, do zero)
Install-ADDSForest `
    -DomainName 'contoso.local' `                # nome do dominio
    -DomainNetbiosName 'CONTOSO' `               # nome curto (CONTOSO\usuario)
    -InstallDns `                                # instala e configura o DNS junto
    -SafeModeAdministratorPassword (Read-Host -AsSecureString 'Senha DSRM') `
    -Force

# Apos o reboot, validar com:
#   Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
#   Get-ADDomainController | Select-Object Name, Domain, IsGlobalCatalog
#   Resolve-DnsName -Name 'DC01.contoso.local'
#   Resolve-DnsName -Name 'google.com'
