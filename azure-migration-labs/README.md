# Azure Migration Labs

Trilha hands-on de migracao de uma empresa ficticia (Contoso do Brasil) de um
ambiente on-premises em Hyper-V para o Azure, com automacao em PowerShell
idempotente. Do datacenter local ate a nuvem, passo a passo.

## Visao geral

Este repositorio documenta uma jornada pratica de Cloud Engineering / Azure,
organizada em grupos sequenciais de laboratorios. Cada lab parte de um
cenario de negocio real e e resolvido por scripts reproduziveis, nao por
cliques manuais - mas os labs nao sao isolados entre si: os grupos
seguintes migram e evoluem exatamente os recursos criados nos anteriores.

O fio condutor: a Contoso do Brasil precisa sair de servidores fisicos
(Hyper-V, Active Directory, file server, IIS) e migrar para o Azure aplicando
boas praticas de identidade hibrida, rede, backup, monitoramento e os 5 Rs de
migracao.

## Tecnologias

Hyper-V, Windows Server 2022, Active Directory, DNS, PowerShell 7, Azure,
Terraform/Bicep (labs de nuvem), Pester (testes).

## Indice dos laboratorios

| Grupo | Lab | Tema | Status |
|-------|-----|------|--------|
| 1 | 01 | Hyper-V + primeira VM Windows Server | Concluido |
| 1 | 02 | Active Directory Domain Services + DNS | Concluido |
| 1 | 03 | DHCP + File Server | Concluido |
| 1 | 04 | IIS Web Server | Concluido |
| 2 | 05 | Azure VMs + Virtual Networks (IaaS base) | Pendente |
| 2 | 06 | Azure Storage + Azure Backup | Pendente |
| 2 | 07 | Microsoft Entra ID + Entra Connect (identidade hibrida) | Pendente |
| 2 | 08 | VPN Site-to-Site (rede hibrida) | Pendente |
| 2 | 09 | Monitoramento + Seguranca hibrida | Pendente |
| 3 | 10 | Azure Migrate: Discovery, Assessment e Rehost | Pendente |
| 3 | 11 | Migracao de Aplicacoes (Refactor / Rearchitect) | Pendente |
| 3 | 12 | Migracao de Banco de Dados (DMS) | Pendente |
| 3 | 13 | Azure Site Recovery (Disaster Recovery) | Pendente |
| 3 | 14 | Framework de Decisao dos 5 Rs | Pendente |
| - | Capstone | Migracao completa da Contoso, ponta a ponta | Pendente |

A numeracao de grupos (1, 2, 3) e provisoria e sera confirmada conforme os
labs forem sendo desenvolvidos - servem para indicar em qual pasta
`group-N-nome/` cada lab vai estar, nao uma divisao definitiva.

## Como navegar

Os laboratorios sao organizados em grupos (fases da jornada). O Grupo 1
reune toda a fundacao on-premises:

```
group-1-onpremises-foundation/
├── README.md             visao geral da fase, em portugues
├── lab-01-hyperv/
├── lab-02-active-directory/
├── lab-03-dhcp-fileserver/
└── lab-04-iis/
```

Cada pasta `lab-XX-nome/` e autossuficiente e segue o mesmo molde:

```
lab-XX-nome/
├── README.md        objetivo, topologia e como rodar
├── scripts/         os .ps1 separados por etapa
└── screenshots/     prints de validacao
```

## Convencoes

- Toda infraestrutura nasce de script (idempotente: rodar duas vezes nao quebra).
- Rede do laboratorio: 192.168.10.0/24, isolada via vSwitch interno + NAT.
- Nomenclatura de VMs: DC01, FS01, WEB01, etc.
- Segredos nunca sao versionados. Os scripts usam placeholders, `Read-Host`
  ou `Get-Credential` no lugar de senhas em texto.

## Autor

Leonardo Fabricio Vieira Fernandes - Engenharia de Software, Inatel.

## Licenca

MIT. Veja o arquivo LICENSE.
