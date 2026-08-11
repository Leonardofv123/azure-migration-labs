# Azure Migration Labs

Trilha hands-on de migracao de uma empresa ficticia (Contoso do Brasil) de um ambiente on-premises em Hyper-V para o Azure, com automacao em PowerShell idempotente. Do datacenter local ate a nuvem, passo a passo.

## Visao geral

Este repositorio documenta uma jornada pratica de Cloud Engineering / Azure, organizada em grupos sequenciais de laboratorios. Cada lab parte de um cenario de negocio real e e resolvido por scripts reproduziveis, nao por cliques manuais - mas os labs nao sao isolados entre si: os grupos seguintes migram e evoluem exatamente os recursos criados nos anteriores.

O fio condutor: a Contoso do Brasil precisa sair de servidores fisicos (Hyper-V, Active Directory, file server, IIS) e migrar para o Azure aplicando boas praticas de identidade hibrida, rede, backup, monitoramento e os 5 Rs de migracao.

## Tecnologias

Hyper-V, Windows Server 2022, Active Directory, DNS, PowerShell 7, Azure, Terraform/Bicep (labs de nuvem), Azure Arc, Log Analytics, Pester (testes).

## Indice dos laboratorios

| Grupo | Lab | Tema | Status |
|---|---|---|---|
| 1 | 01 | Hyper-V + primeira VM Windows Server | Concluido |
| 1 | 02 | Active Directory Domain Services + DNS | Concluido |
| 1 | 03 | DHCP + File Server | Concluido |
| 1 | 04 | IIS Web Server | Concluido |
| 2 | 05 | Azure VMs + Virtual Networks (IaaS base) | Concluido |
| 2 | 06 | Azure Storage + Azure Backup | Concluido |
| 2 | 07 | Microsoft Entra ID + Entra Connect (identidade hibrida) | Concluido |
| 2 | 08 | VPN Site-to-Site (rede hibrida) | Concluido com limitacao documentada |
| 2 | 09 | Monitoramento + Seguranca hibrida | Concluido |
| 3 | 10 | Azure Migrate: Discovery, Assessment e Rehost | Pendente |
| 3 | 11 | Migracao de Aplicacoes (Refactor / Rearchitect) | Pendente |
| 3 | 12 | Migracao de Banco de Dados (DMS) | Pendente |
| 3 | 13 | Azure Site Recovery (Disaster Recovery) | Pendente |
| 3 | 14 | Framework de Decisao dos 5 Rs | Pendente |
| - | Capstone | Migracao completa da Contoso, ponta a ponta | Pendente |

A numeracao de grupos (1, 2, 3) e provisoria e sera confirmada conforme os labs forem sendo desenvolvidos - servem para indicar em qual pasta `group-N-nome/` cada lab vai estar, nao uma divisao definitiva.

## Como navegar

Os laboratorios sao organizados em grupos (fases da jornada).

O **Grupo 1** reune toda a fundacao on-premises:

```
group-1-onpremises-foundation/
├── README.md             visao geral da fase, em portugues
├── lab-01-hyperv/
├── lab-02-active-directory/
├── lab-03-dhcp-fileserver/
└── lab-04-iis/
```

O **Grupo 2** leva a Contoso para a nuvem e constroi as pontes entre os dois ambientes:

```
group-2-azure-foundation/
├── README.md             visao geral da fase, em portugues
├── lab-05-azure-vnet-vm/
├── lab-06-storage-backup/
├── lab-07-entra-connect/
├── lab-08-vpn-site-to-site/
└── lab-09-monitoramento/
```

Cada pasta `lab-XX-nome/` e autossuficiente e segue o mesmo molde:

```
lab-XX-nome/
├── README.md        objetivo, topologia e como rodar
├── scripts/         os .ps1 separados por etapa
└── screenshots/     prints de validacao
```

## Estado do ambiente

Ao final do Grupo 2, a Contoso opera nos dois mundos ao mesmo tempo:

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

## Convencoes

- Toda infraestrutura nasce de script (idempotente: rodar duas vezes nao quebra).
- Rede do laboratorio: `192.168.10.0/24`, isolada via vSwitch interno + NAT.
- Rede do Azure: `10.10.0.0/16`, segmentada em web / app / dados.
- Nomenclatura de VMs: `DC01`, `FS01`, `WEB01`, etc.
- Nomenclatura de recursos Azure: `<tipo>-<nome>-<ambiente>-<regiao>`.
- Segredos nunca sao versionados. Os scripts usam placeholders, `Read-Host` ou `Get-Credential` no lugar de senhas em texto.
- Diagramas em ASCII dentro de blocos de codigo, para ficarem legiveis e faceis de copiar.

## Sobre as secoes de troubleshooting

Cada README de lab tem uma secao de desafios documentando os problemas reais enfrentados, incluindo os diagnosticos que estavam errados e o que revelou o engano.

Isso e proposital. Os erros mais instrutivos da trilha nao foram de sintaxe, foram de metodo: trocar de regiao quando a variavel certa era outra, aplicar um fix que valia so por sessao, ou procurar um servico que nunca existiu com aquele nome.

## Autor

Leonardo Fabricio Vieira Fernandes - Engenharia de Software, Inatel.

## Licenca

MIT. Veja o arquivo [LICENSE](LICENSE).
