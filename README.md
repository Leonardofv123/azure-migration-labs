# Azure Migration Labs

Trilha hands-on de migracao de uma empresa ficticia (Contoso do Brasil)
de um ambiente on-premises em Hyper-V para o Azure, com automacao em
PowerShell idempotente e infraestrutura como codigo. Do datacenter local
ate a nuvem, passo a passo.

---

## Visao geral

Este repositorio documenta uma jornada pratica de Cloud Engineering /
Azure, organizada em grupos sequenciais de laboratorios. Cada lab parte
de um cenario de negocio real e e resolvido por scripts reproduziveis,
nao por cliques manuais - e os labs nao sao isolados entre si: os grupos
seguintes migram e evoluem exatamente os recursos criados nos anteriores.

O fio condutor: a Contoso do Brasil precisa sair de servidores locais
(Hyper-V, Active Directory, file server, IIS) e migrar para o Azure
aplicando boas praticas de identidade hibrida, rede, backup,
monitoramento e os 5 Rs de migracao.

---

## Tecnologias

Hyper-V, Windows Server 2022, Active Directory, DNS, PowerShell 7, Azure,
Terraform, Bicep, Azure Arc, Azure Monitor, Log Analytics, Azure Migrate,
Azure App Service, Pester.

---

## Indice dos laboratorios

| Grupo | Lab | Tema | Status |
|-------|-----|------|--------|
| 1 | 01 | Hyper-V + primeira VM Windows Server | Concluido |
| 1 | 02 | Active Directory Domain Services + DNS | Concluido |
| 1 | 03 | DHCP + File Server | Concluido |
| 1 | 04 | IIS Web Server | Concluido |
| 2 | 05 | Azure VMs + Virtual Networks (IaaS base) | Concluido |
| 2 | 06 | Azure Storage + Azure Backup + File Sync | Concluido |
| 2 | 07 | Microsoft Entra ID + Entra Connect | Concluido |
| 2 | 08 | VPN Site-to-Site (rede hibrida) | Concluido com limitacao documentada |
| 2 | 09 | Monitoramento hibrido (Azure Monitor + Arc) | Concluido |
| 3 | 10 | Azure Migrate: Discovery e Assessment | Concluido com limitacao documentada |
| 3 | 11 | Rehost: migracao da WEB01 | Concluido |
| 3 | 12 | Validacao pos-migracao e cutover | Concluido |
| 3 | 13 | Refactor: WEB01 para App Service | Concluido com limitacao documentada |
| 3 | 14 | Framework de decisao dos 5 Rs | Concluido |

---

## Escopo

A trilha cobre os cenarios que o ambiente da Contoso sustenta. Dois
temas ficaram fora do escopo por decisao consciente:

```
MIGRACAO DE BANCO DE DADOS (DMS)
  O ambiente da Contoso nao tem banco de dados. Criar um SQL Server
  artificialmente so para ter o que migrar seria teatro, nao lab.

AZURE SITE RECOVERY (DR)
  ASR depende do mesmo tipo de conectividade continua que bloqueou o
  Azure Migrate Appliance no Lab 10, e cobra por instancia protegida.
  O conceito de failover e failback esta coberto no Lab 12.
```

---

## Como navegar

Os laboratorios sao organizados em grupos (fases da jornada).

O Grupo 1 reune toda a fundacao on-premises:

```
group-1-onpremises-foundation/
├── README.md             visao geral da fase
├── lab-01-hyperv/
├── lab-02-active-directory/
├── lab-03-dhcp-fileserver/
└── lab-04-iis/
```

O Grupo 2 leva a Contoso para a nuvem e constroi as pontes entre os
dois ambientes:

```
group-2-azure-foundation/
├── README.md
├── lab-05-azure-vnet-vm/
├── lab-06-storage-backup/
├── lab-07-entra-connect/
├── lab-08-vpn-site-to-site/
└── lab-09-monitoramento/
```

O Grupo 3 migra e decide o que vale a pena migrar:

```
group-3-migration/
├── README.md
├── lab-10-azure-migrate/
├── lab-11-rehost/
├── lab-12-cutover/
├── lab-13-refactor/
└── lab-14-framework-5rs/
```

Cada pasta `lab-XX-nome/` e autossuficiente e segue o mesmo molde:

```
lab-XX-nome/
├── README.md        objetivo, topologia, passo a passo, desafios
├── scripts/         os .ps1 separados por etapa
├── terraform/       quando aplicavel
└── screenshots/     prints de validacao
```

---

## Estado do ambiente

Ao final do Grupo 2, a Contoso opera nos dois mundos ao mesmo tempo:

```
    ON-PREMISES (Hyper-V)                    AZURE

contoso-dc01   192.168.10.10        vnet-contoso-eus2 (10.10.0.0/16)
AD DS + DNS                           |
+ Entra Connect (Lab 07)              +-- subnet-web  10.10.1.0/24
+ Azure Arc + AMA (Lab 09)            |     vm-web-prod-eus2
                                      |
contoso-fs01   192.168.10.20          +-- GatewaySubnet 10.10.255.0/27
File Server
+ Azure File Sync (Lab 06)          law-contoso-eus2   (Log Analytics)
+ Azure Arc + AMA (Lab 09)          rsv-contoso-eus2   (Backup)
                                    stcontosoeus2lab   (Storage)
contoso-web01  192.168.10.30        Microsoft Entra ID (tenant)
IIS
+ Azure Arc + AMA (Lab 09)

contoso-gw01   192.168.10.1
RRAS (Lab 08)
```

No Grupo 3 a WEB01 atravessa (Lab 11) e o Lab 14 define o destino de
cada uma das outras cargas.

---

## Convencoes

- Toda infraestrutura nasce de script ou codigo (idempotente: rodar
  duas vezes nao quebra).
- Rede do laboratorio: `192.168.10.0/24`, isolada via vSwitch interno
  com NAT.
- Rede do Azure: `10.10.0.0/16`, segmentada em web / app / dados.
- Nomenclatura de VMs: DC01, FS01, WEB01, GW01.
- Nomenclatura de recursos Azure: `<tipo>-<nome>-<ambiente>-<regiao>`.
- Segredos nunca sao versionados. Os scripts usam `Read-Host`,
  `Get-Credential` ou variaveis `sensitive` do Terraform.
- Diagramas em ASCII dentro de blocos de codigo, para ficarem legiveis
  e faceis de copiar.
- READMEs sem acentuacao e sem travessao, seguindo o padrao do repo.

---

## Sobre as secoes de desafios

Cada README de lab tem uma secao documentando os problemas reais
enfrentados, incluindo os diagnosticos que estavam errados e o que
revelou o engano.

Isso e proposital. Os erros mais instrutivos da trilha nao foram de
sintaxe, foram de metodo: trocar de regiao quando a variavel certa era
outra, aplicar um fix que valia so por sessao, ou concluir que uma
mensagem de erro apontava para permissao quando apontava para politica
de dispositivo.

Tres casos que se repetem com causas diferentes valem destaque:

```
COTA x CAPACIDADE
  Lab 05   SkuNotAvailable era cota zerada da familia B
  Lab 11   SkuNotAvailable era falta de capacidade da regiao
  Lab 13   401 Unauthorized era cota zerada para App Service
  
  Mensagens parecidas, causas distintas. O que separa e testar
  trocando uma variavel de cada vez.
```

---

## Autor

Leonardo Fabricio Vieira Fernandes - Engenharia de Software, Inatel.

---

## Licenca

MIT. Veja o arquivo LICENSE.
