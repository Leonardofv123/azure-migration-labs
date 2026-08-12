# Azure Migration Labs

Trilha hands-on de migracao de uma empresa ficticia (Contoso do Brasil)
de um ambiente on-premises em Hyper-V para o Azure, com automacao em
PowerShell idempotente e infraestrutura como codigo. Do datacenter local
ate a nuvem, passo a passo.

---

## Visao geral

Este repositorio documenta uma jornada pratica de Cloud Engineering e
Azure, organizada em grupos sequenciais de laboratorios. Cada lab parte
de um cenario de negocio real e e resolvido por scripts reproduziveis,
nao por cliques manuais.

Os labs tambem nao sao isolados entre si: os grupos seguintes migram e
evoluem exatamente os recursos criados nos anteriores. O Lab 11 usa a
VNet criada no Lab 05. O Lab 14 usa o custo calculado no Lab 10, o File
Sync configurado no Lab 06 e o Entra Connect que subiu no Lab 07.

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

A trilha cobre os cenarios que o ambiente da Contoso sustenta. Tres
temas ficaram fora do escopo, por decisao consciente:

```
MIGRACAO DE BANCO DE DADOS (DMS)
  O ambiente da Contoso nao tem banco de dados. Criar um SQL Server
  artificialmente so para ter o que migrar seria teatro, nao lab.

AZURE SITE RECOVERY (DR)
  ASR depende do mesmo tipo de conectividade continua que bloqueou o
  Azure Migrate Appliance no Lab 10, e cobra por instancia protegida.
  O conceito de failover e failback esta coberto no Lab 12.

PROJETO CAPSTONE
  A integracao entre os labs acontece ao longo do caminho, nao em um
  projeto final separado. Um capstone aqui seria repetir a trilha.
```

---

## Como navegar

Os laboratorios sao organizados em grupos, que correspondem as fases da
jornada.

O Grupo 1 reune toda a fundacao on-premises:

```
group-1-onpremises-foundation/
├── README.md
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

O Grupo 3 migra, e decide o que vale a pena migrar:

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

## Estado do ambiente ao final da trilha

```
ON-PREMISES (Hyper-V)                     AZURE

contoso-dc01   192.168.10.10              vnet-contoso-eus2 (10.10.0.0/16)
AD DS + DNS, dominio contoso.local          |
+ Entra Connect        (Lab 07)             +-- subnet-web    10.10.1.0/24
+ Azure Arc + AMA      (Lab 09)             |     vm-web-prod-eus2 (Lab 05)
Decisao: Retain        (Lab 14)             |
                                            +-- GatewaySubnet 10.10.255.0/27
contoso-fs01   192.168.10.20
File Server                               stcontosoeus2lab   Storage (Lab 06)
+ Azure File Sync      (Lab 06)             container documentos
+ Azure Arc + AMA      (Lab 09)             file share vendas
Decisao: Replace       (Lab 14)             sync-contoso-eus2

contoso-web01  192.168.10.30              rsv-contoso-eus2   Backup (Lab 06)
IIS                                       law-contoso-eus2   Log Analytics (Lab 09)
+ Azure Arc + AMA      (Lab 09)             dcr-windows-contoso
Migrado                (Lab 11)             DC01, FS01, WEB01 via Arc
Decisao: Refactor      (Lab 14)
                                          Microsoft Entra ID (Lab 07)
contoso-gw01   192.168.10.1                 8 usuarios sincronizados
RRAS, gateway e NAT
+ VPN Site-to-Site     (Lab 08)           migrate-contoso-eus2 (Lab 10)
Decisao: Retire        (Lab 14)             assessment: 4/4 Ready
                                            USD 440,45/mes em rehost puro
```

A WEB01 foi efetivamente migrada no Lab 11 e teve os recursos
destruidos apos a validacao, conforme documentado la. As decisoes de
Retain, Replace e Retire vem do framework aplicado no Lab 14.

---

## Convencoes

Toda infraestrutura nasce de script ou codigo, sempre idempotente:
rodar duas vezes nao quebra.

```
Rede do laboratorio      192.168.10.0/24, vSwitch interno com NAT
Rede do Azure            10.10.0.0/16
Nomes de VM              DC01, FS01, WEB01, GW01
Recursos Azure           <tipo>-<nome>-<ambiente>-<regiao>
```

Segredos nunca sao versionados. Os scripts usam `Read-Host`,
`Get-Credential` ou variaveis marcadas como `sensitive` no Terraform.

Diagramas ficam em ASCII dentro de blocos de codigo, para serem
legiveis e faceis de copiar.

Os READMEs seguem o padrao do repositorio: sem acentuacao e sem
travessao.

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

Um padrao que se repete tres vezes com causas diferentes vale destaque:

```
LAB 05   SkuNotAvailable era cota zerada da familia B na conta
LAB 11   SkuNotAvailable era falta de capacidade da regiao
LAB 13   401 Unauthorized era cota zerada para App Service Plan
```

Mensagens parecidas, causas distintas. Cota se resolve pedindo
aumento. Capacidade se resolve trocando de regiao ou esperando.
Confundir os dois leva a tentar a solucao errada por horas, e o que
separa os casos e testar trocando uma variavel de cada vez.

---

## Autor

Leonardo Fabricio Vieira Fernandes, estudante de Engenharia de Software
no Inatel.

---

## Licenca

MIT. Veja o arquivo LICENSE.
