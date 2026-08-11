# Grupo 2 - Fundacao Azure

Segunda fase da trilha. O Grupo 1 construiu toda a base on-premises da Contoso do Brasil em Hyper-V: Active Directory, DNS, DHCP, File Server e IIS. Esta fase leva a empresa para a nuvem.

Nao e uma migracao ainda. E a construcao do ambiente Azure que vai receber as cargas de trabalho, mais as pontes entre os dois mundos (identidade hibrida, VPN, monitoramento unificado). A migracao propriamente dita vem no Grupo 3, com Azure Migrate.

## Labs desta fase

| Lab | Tema | Status |
|---|---|---|
| [05](lab-05-azure-vnet-vm/) | Rede e VM no Azure (VNet, NSG, Terraform, Bicep) | Concluido |
| [06](lab-06-storage-backup/) | Storage Account, Azure Backup e Azure File Sync | Concluido |
| [07](lab-07-entra-connect/) | Microsoft Entra ID e Entra Connect (identidade hibrida) | Concluido |
| [08](lab-08-vpn-site-to-site/) | VPN Site-to-Site | Concluido com limitacao documentada |
| [09](lab-09-monitoramento/) | Monitoramento hibrido (Azure Monitor, Log Analytics, Arc) | Concluido |

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
Lab 08  VPN Site-to-Site
        |
        |  conecta 192.168.10.0/24 com 10.10.0.0/16
        v
Lab 09  Monitoramento hibrido
        |
        |  Arc + AMA nas 3 VMs on-premises
        |  tudo reportando ao mesmo workspace
        v
Grupo 3  Migracao (Azure Migrate)
```

O Lab 05 e pre-requisito direto do 06. Os demais sao independentes entre si. O 09, por exemplo, nao depende do tunel do 08, porque os agentes se comunicam por HTTPS/443.

## Ambiente ao final desta fase

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

| Resource Group | Conteudo | Lab |
|---|---|---|
| `rg-network-prod-eus2` | VNet, sub-redes, NSG, VM web, VPN Gateway | 05, 08 |
| `rg-storage-prod-eus2` | Storage Account, Storage Sync Service | 06 |
| `rg-backup-prod-eus2` | Recovery Services Vault | 06 |
| `rg-monitor-prod-eus2` | Log Analytics, DCRs, maquinas Arc | 09 |

A separacao por RG segue governanca: rede, storage, backup e monitoramento tem ciclos de vida e responsaveis diferentes em ambiente real.

## Sobre as secoes de troubleshooting

Cada lab desta fase tem uma secao de desafios documentando os problemas reais enfrentados, incluindo os diagnosticos que estavam errados e o que revelou o engano.

Isso e proposital. Os erros mais instrutivos desta fase nao foram de sintaxe, foram de metodo:

- **Lab 05** trocar de regiao tres vezes quando a variavel certa era a familia da VM
- **Lab 06** um fix de TLS que valia por sessao de PowerShell, nao por maquina, fazendo o problema parecer aleatorio
- **Lab 07** oito hipoteses eliminadas dentro da maquina antes de trocar a rede de saida, que era a causa
- **Lab 08** verificar tunel e rota em momentos diferentes, produzindo conclusoes que nao batiam
- **Lab 09** procurar um servico Windows que nao existia, concluindo que o agente estava quebrado quando ele rodava normalmente

## Custos

A maior parte desta fase cabe no tier gratuito ou custa pouco. Duas excecoes merecem atencao.

**VPN Gateway (Lab 08)** cobra por hora enquanto existir, leva 40 minutos para provisionar e 20 para deletar. E o recurso mais caro da trilha por unidade de tempo. Deve ser deletado assim que o objetivo do lab for atingido.

**VM do Lab 05** usa Standard_D2s_v3, fora do tier gratuito por conta de cota zerada para a familia B em subscription nova. Auto-shutdown as 22h configurado como protecao.

Log Analytics, Azure Arc e Azure Monitor Agent sao gratuitos no volume deste lab.

## Convencoes

Seguem as mesmas do repositorio:

- Toda infraestrutura nasce de script, idempotente
- Segredos nunca versionados. Os scripts usam `Read-Host` ou `Get-Credential`
- Diagramas em ASCII dentro de blocos de codigo
- Screenshots de validacao em `screenshots/` de cada lab

## Proxima fase

**Grupo 3, Migracao.** Azure Migrate para discovery e assessment do ambiente on-premises, seguido do rehost das VMs. E onde a Contoso finalmente sai do Hyper-V.
