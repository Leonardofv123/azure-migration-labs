<#
    Lab 03 - Script 01b: Ingressar a FS01 no dominio contoso.local
    Executar DENTRO da VM FS01, apos o reboot do script anterior.

    Pede credencial: use CONTOSO\Administrator (admin do DOMINIO,
    nao o admin local da FS01).
#>

Add-Computer -DomainName 'contoso.local' `
    -Credential (Get-Credential -Message 'Digite as credenciais do dominio (CONTOSO\Administrator)') `
    -Restart

# Apos o reboot, logar como CONTOSO\Administrator (digitar o dominio
# explicitamente - a tela de login pode sugerir a conta local por padrao)
# e validar com:
#   whoami
#   Get-ComputerInfo | Select-Object CsName, CsDomain, CsDomainRole
