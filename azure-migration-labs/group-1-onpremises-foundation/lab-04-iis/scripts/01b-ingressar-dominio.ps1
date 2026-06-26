<#
    Lab 04 - Script 01b: Ingressar a WEB01 no dominio contoso.local
    Executar DENTRO da VM WEB01, apos o reboot do script anterior.
#>

Add-Computer -DomainName 'contoso.local' `
    -Credential (Get-Credential -Message 'CONTOSO\Administrator') `
    -Restart

# Apos o reboot, logar como CONTOSO\Administrator (digitar o dominio
# explicitamente) e validar com:
#   whoami
#   Get-ComputerInfo | Select-Object CsName, CsDomain, CsDomainRole
