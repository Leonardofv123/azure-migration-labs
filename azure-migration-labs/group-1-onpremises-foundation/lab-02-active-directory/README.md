# Lab 02 - Active Directory Domain Services + DNS

## Objetivo

Promover a VM DC01 a controlador de dominio (criando a floresta
contoso.local), criar a estrutura organizacional por setor (OUs) e
provisionar usuarios e grupos em massa a partir de um arquivo CSV. O DNS sobe
automaticamente junto com o AD. Cenario: o RH entregou a planilha dos
funcionarios e e preciso criar a estrutura e todas as contas sem digitar uma
por uma.

## Estrutura criada

```
Floresta: contoso.local
     |
     v
Dominio: contoso.local  (NetBIOS: CONTOSO)
     |
     v
OUs (setores):
     TI            -> bruno.lima, diego.rocha, henrique.dias
     Vendas        -> ana.souza, felipe.alves
     Financeiro    -> carla.mendes, gabriela.nunes
     Diretoria     -> elaine.castro
     ServiceAccounts (reservada p/ contas de servico)
     |
     v
Grupos globais:
     GG_TI (3)  GG_Vendas (2)  GG_Financeiro (2)  GG_Diretoria (1)
```

## Pre-requisitos

- Lab 01 concluido (DC01 de pe, IP fixo 192.168.10.10).
- 1 VM (DC01), 4 GB RAM, 2 vCPU.

## Como rodar

Todos os scripts rodam DENTRO da VM DC01, no PowerShell como Administrador.

1. `01-promover-dc.ps1`: instala AD DS e cria a floresta. Pede a senha DSRM
   (recuperacao, diferente da senha de login). A VM reinicia sozinha. Ao
   voltar, login como `Administrator` (ingles, nao "Administrador").
2. `02-criar-ous.ps1`: cria as 5 OUs por setor.
3. Copiar o `usuarios-exemplo.csv` para a pasta atual da VM.
4. `03-criar-usuarios-csv.ps1`: le o CSV e cria usuarios + grupos.
5. `04-validar.ps1`: confere usuarios, grupos e zona DNS.

## Validacao

Resultado esperado:

- `Get-ADDomain`: DNSRoot contoso.local, NetBIOS CONTOSO, DomainMode
  Windows2016Domain.
- `Resolve-DnsName DC01.contoso.local`: retorna 192.168.10.10.
- `Resolve-DnsName google.com`: resolve (internet por nome agora funciona; a
  pendencia do Lab 01 fica resolvida aqui).
- Grupos: GG_TI (3), GG_Vendas (2), GG_Financeiro (2), GG_Diretoria (1).

## Formato do CSV

```
Nome,Sobrenome,Departamento,Cargo
Ana,Souza,Vendas,Analista
Bruno,Lima,TI,Administrador
```

O Departamento de cada linha precisa corresponder a uma OU existente
(criada no script 02).

## Observacoes e boas praticas

- A conta de admin e `Administrator` (ingles), mesmo em ambiente em portugues.
- Senha DSRM e diferente da senha de login. Guardar as duas com seguranca.
- Nomes com acento podem dar problema no SamAccountName; normalizar quando
  usar nomes reais.
- Para contar membros de grupo, usar sempre `@(Get-ADGroupMember ...).Count`.
  Um grupo com 1 membro pode exibir contagem errada sem o `@()`.
- O script de usuarios e reaproveitavel: o CSV mensal de admissoes do RH vira
  provisionamento automatico (pode ser agendado no Task Scheduler).

## Conceitos cobertos

Active Directory, floresta, dominio, controlador de dominio, OU, DNS, grupo
global, senha DSRM, provisionamento em massa via CSV, splatting.
