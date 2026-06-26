<#
    Lab 03 - Script 02: Instalar e autorizar o DHCP
    Executar DENTRO da VM FS01, logado como CONTOSO\Administrator.
#>

# Instala o papel DHCP + ferramentas de gerenciamento
Install-WindowsFeature DHCP -IncludeManagementTools

# Autoriza o servidor DHCP no Active Directory.
# Sem isso, o DHCP fica instalado mas RECUSA distribuir IPs num dominio
# (trava de seguranca contra "DHCP pirata" na rede).
Add-DhcpServerInDC -DnsName 'FS01.contoso.local' -IPAddress 192.168.10.20

# Cria o escopo: a faixa de IPs que o DHCP pode distribuir
Add-DhcpServerv4Scope -Name 'LAN-Contoso' -StartRange 192.168.10.100 -EndRange 192.168.10.200 -SubnetMask 255.255.255.0

# Define as opcoes entregues junto com o IP (gateway, DNS, sufixo de dominio)
Set-DhcpServerv4OptionValue -ScopeId 192.168.10.0 -Router 192.168.10.1 -DnsServer 192.168.10.10 -DnsDomain 'contoso.local'

Write-Host "DHCP instalado, autorizado e com escopo configurado." -ForegroundColor Green

# Validacao
Get-DhcpServerInDC
Get-DhcpServerv4Scope
Get-DhcpServerv4OptionValue -ScopeId 192.168.10.0

<#
    NOTA: ao colar comandos longos com continuacao de linha (crase `),
    o terminal pode quebrar a colagem e tratar parametros como comandos
    separados, abrindo um prompt pedindo os valores um a um. Se isso
    acontecer, rode o comando problematico em UMA UNICA LINHA, sem quebras.
#>
