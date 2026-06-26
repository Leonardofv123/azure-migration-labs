<#
    Lab 04 - Script 02: Instalar o IIS
    Executar DENTRO da VM WEB01, logado como CONTOSO\Administrator.

    NOTA: o nome de exibicao do feature e "ASP.NET 4.8", mas o nome
    INTERNO usado pelo PowerShell continua sendo Web-Asp-Net45 (mantido
    por compatibilidade historica). Use Get-WindowsFeature *asp* para
    confirmar nomes de features em caso de divergencia.
#>

Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Mgmt-Service -IncludeManagementTools
Import-Module WebAdministration

# Validacao
Get-WindowsFeature Web-Server, Web-Asp-Net45, Web-Mgmt-Service | Select-Object Name, Installed
