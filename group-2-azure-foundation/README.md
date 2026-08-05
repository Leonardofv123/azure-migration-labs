# Grupo 2 — Fundação Azure

Segunda fase da trilha. O Grupo 1 construiu toda a base on-premises da Contoso
do Brasil em Hyper-V — Active Directory, DNS, DHCP, File Server e IIS. Esta
fase leva a empresa para a nuvem.

Não é uma migração ainda: é a construção do ambiente Azure que vai receber as
cargas de trabalho, mais as pontes entre os dois mundos (identidade híbrida,
VPN, monitoramento unificado). A migração propriamente dita vem no Grupo 3, com
Azure Migrate.


## Labs desta fase

| Lab | Tema | Status |
|---|---|---|
| 05 | Rede e VM no Azure (VNet, NSG, Terraform, Bicep) | Concluído |
| 06 | Storage Account, Azure Backup e Azure File Sync | Concluído |
| 07 | Microsoft Entra ID + Entra Connect (identidade híbrida) | Concluído |
| 08 | VPN Site-to-Site | Concluído com limitação documentada |
| 09 | Monitoramento híbrido (Azure Monitor + Log Analytics + Arc) | Concluído |


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
Lab 07  Identidade híbrida
        |
        |  sincroniza o AD do Lab 02 com o Entra ID
        v
Lab 08  VPN Site-to-Site
        |
        |  conecta 192.168.10.0/24 <-> 10.10.0.0/16
        v
Lab 09  Monitoramento híbrido
        |
        |  Arc + AMA nas 3 VMs on-premises
        |  tudo reportando ao mesmo workspace
        v
Grupo 3  Migração (Azure Migrate)
```

O Lab 05 é pré-requisito direto do 06. Os demais são independentes entre si —
o 09, por exemplo, não depende do túnel do 08, porque os agentes se comunicam
por HTTPS/443.


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
    IIS                                 law-contoso-eus2 (Log Analytics)
    + Azure Arc + AMA (Lab 09)          rsv-contoso-eus2 (Backup)
                                        stcontosoeus2xxxx (Storage)
    contoso-gw01   192.168.10.1         Microsoft Entra ID (tenant)
    RRAS (Lab 08)
```


## Resource Groups criados

| Resource Group | Conteúdo | Lab |
|---|---|---|
| `rg-network-prod-eus2` | VNet, sub-redes, NSG, VM web, VPN Gateway | 05, 08 |
| `rg-storage-prod-eus2` | Storage Account, Storage Sync Service | 06 |
| `rg-backup-prod-eus2` | Recovery Services Vault | 06 |
| `rg-monitor-prod-eus2` | Log Analytics, DCRs, máquinas Arc | 09 |

A separação por RG segue governança: rede, storage, backup e monitoramento têm
ciclos de vida e responsáveis diferentes em ambiente real.


## Sobre as seções de troubleshooting

Cada lab desta fase tem uma seção de desafios documentando os problemas reais
enfrentados — incluindo os diagnósticos que estavam errados e o que revelou o
engano.

Isso é proposital. Os erros mais instrutivos desta fase não foram de sintaxe,
foram de método:

- **Lab 05** — trocar de região três vezes quando a variável certa era a
  família da VM
- **Lab 06** — um fix de TLS que valia por sessão de PowerShell, não por
  máquina, fazendo o problema parecer aleatório
- **Lab 07** — oito hipóteses eliminadas dentro da máquina antes de trocar a
  rede de saída, que era a causa
- **Lab 08** — verificar túnel e rota em momentos diferentes, produzindo
  conclusões que não batiam
- **Lab 09** — procurar um serviço Windows que não existia, concluindo que o
  agente estava quebrado quando ele rodava normalmente


## Custos

A maior parte desta fase cabe no tier gratuito ou custa pouco. Duas exceções
merecem atenção:

**VPN Gateway (Lab 08)** — cobra por hora enquanto existir, leva 40 minutos
para provisionar e 20 para deletar. É o recurso mais caro da trilha por
unidade de tempo. Deve ser deletado assim que o objetivo do lab for atingido.

**VM do Lab 05** — Standard_D2s_v3, fora do tier gratuito por conta de cota
zerada para a família B em subscription nova. Auto-shutdown às 22h configurado
como proteção.

Log Analytics, Azure Arc e Azure Monitor Agent são gratuitos no volume deste
lab.


## Convenções

Seguem as mesmas do repositório:

- Toda infraestrutura nasce de script, idempotente
- Segredos nunca versionados — os scripts usam `Read-Host` ou `Get-Credential`
- Diagramas em ASCII dentro de blocos de código
- Screenshots de validação em `screenshots/` de cada lab


## Próxima fase

**Grupo 3 — Migração.** Azure Migrate para discovery e assessment do ambiente
on-premises, seguido do rehost das VMs. É onde a Contoso finalmente sai do
Hyper-V.
