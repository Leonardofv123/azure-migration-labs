# Grupo 2: Fundacao Azure

Segunda fase da trilha. No Grupo 1 eu construi toda a base on-premises da Contoso do Brasil em Hyper-V: Active Directory, DNS, DHCP, File Server e IIS. Essa fase leva a empresa pra nuvem.

Ainda nao e migracao. E a construcao do ambiente Azure que vai receber as cargas de trabalho, mais as pontes entre os dois mundos: identidade hibrida, VPN, monitoramento unificado. A migracao de verdade fica pro Grupo 3, com Azure Migrate.

## Labs dessa fase

- **Lab 05**: rede e VM no Azure (VNet, NSG, Terraform, Bicep). Concluido.
- **Lab 06**: Storage Account, Azure Backup e Azure File Sync. Concluido.
- **Lab 07**: Microsoft Entra ID e Entra Connect, identidade hibrida. Concluido.
- **Lab 08**: VPN Site to Site. Concluido com limitacao documentada.
- **Lab 09**: monitoramento hibrido com Azure Monitor, Log Analytics e Arc. Concluido.

## Como os labs se encadeiam

```
Lab 05  Rede e primeira VM
        |
        |  cria vnet-contoso-eus2 e vm-web-prod-eus2
        v
Lab 06  Storage e Backup
        |
        |  protege a VM do Lab 05
        |  conecta a FS01 on-premises via File Sync
        v
Lab 07  Identidade hibrida
        |
        |  sincroniza o AD do Lab 02 com o Entra ID
        v
Lab 08  VPN Site to Site
        |
        |  conecta 192.168.10.0/24 com 10.10.0.0/16
        v
Lab 09  Monitoramento hibrido
        |
        |  Arc + AMA nas 3 VMs on-premises
        |  tudo reportando pro mesmo workspace
        v
Grupo 3  Migracao (Azure Migrate)
```

O Lab 05 e pre requisito direto do 06. Os outros sao independentes entre si. O 09, por exemplo, nem precisa do tunel do 08, porque os agentes conversam por HTTPS na porta 443.

## Como ficou o ambiente no final dessa fase

```
        ON-PREMISES (Hyper-V)                    AZURE

    contoso-dc01   192.168.10.10        vnet-contoso-eus2 (10.10.0.0/16)
    AD DS + DNS                           |
    + Entra Connect (Lab 07)              +-- snet-web    10.10.1.0/24
    + Azure Arc + AMA (Lab 09)            |     vm-web-prod-eus2
                                          |
    contoso-fs01   192.168.10.20          +-- snet-app    10.10.2.0/24
    File Server                           |
    + Azure File Sync (Lab 06)            +-- snet-data   10.10.3.0/24
    + Azure Arc + AMA (Lab 09)            |
                                          +-- GatewaySubnet 10.10.255.0/27
    contoso-web01  192.168.10.30
    IIS                                 law-contoso-eus2   (Log Analytics)
    + Azure Arc + AMA (Lab 09)          rsv-contoso-eus2   (Backup)
                                        stcontosoeus2xxxx  (Storage)
    contoso-gw01   192.168.10.1         Microsoft Entra ID (tenant)
    RRAS (Lab 08)
```

## Resource Groups criados

Separei os recursos em quatro RGs, pensando em governanca (rede, storage, backup e monitoramento tem ciclo de vida e responsavel diferente num ambiente real, entao nao faz sentido misturar tudo):

- **rg-network-prod-eus2**: VNet, sub-redes, NSG, VM web e VPN Gateway. Criado nos labs 05 e 08.
- **rg-storage-prod-eus2**: Storage Account e Storage Sync Service. Lab 06.
- **rg-backup-prod-eus2**: Recovery Services Vault. Lab 06.
- **rg-monitor-prod-eus2**: Log Analytics, DCRs e as maquinas conectadas via Arc. Lab 09.

## Sobre os perrengues

Cada lab dessa fase tem uma secao contando os problemas reais, incluindo os diagnosticos errados que eu fiz antes de achar a causa de verdade.

Isso e proposital. Os erros mais uteis dessa fase nao foram de sintaxe, foram de metodo:

- **Lab 05**: troquei de regiao tres vezes quando o problema de verdade era a familia da VM
- **Lab 06**: apliquei um fix de TLS que valia so pra sessao do PowerShell, nao pra maquina inteira, e isso fez o problema parecer aleatorio por um tempo
- **Lab 07**: eliminei oito hipoteses dentro da maquina antes de pensar em trocar a rede de saida, que era a causa real
- **Lab 08**: verifiquei o tunel e a rota em momentos diferentes, e isso me deu conclusoes que nao batiam entre si
- **Lab 09**: fiquei procurando um servico Windows que nem existia, e quase concluí que o agente estava quebrado quando na verdade ele rodava normal

## Custos

A maior parte dessa fase cabe no tier gratuito ou custa pouco. Duas coisas merecem atencao.

O VPN Gateway (Lab 08) cobra por hora enquanto existir, leva uns 40 minutos pra provisionar e 20 pra deletar. E o recurso mais caro da trilha por unidade de tempo, entao a regra e deletar assim que o objetivo do lab for cumprido.

A VM do Lab 05 usa Standard_D2s_v3, fora do tier gratuito, porque minha subscription nova veio com cota zerada pra familia B. Deixei um auto shutdown configurado as 22h como protecao.

Log Analytics, Azure Arc e Azure Monitor Agent saem de graca no volume que eu uso nesse lab.

## Convencoes

As mesmas do resto do repositorio:

- Toda infraestrutura nasce de script, e idempotente
- Segredo nenhum vai versionado, os scripts usam `Read-Host` ou `Get-Credential`
- Diagramas em ASCII dentro de bloco de codigo
- Screenshots de validacao ficam em `screenshots/` de cada lab

## Proxima fase

Grupo 3, Migracao. Azure Migrate entra pra fazer discovery e assessment do ambiente on-premises, e depois vem o rehost das VMs. E onde a Contoso finalmente sai do Hyper-V de vez.
