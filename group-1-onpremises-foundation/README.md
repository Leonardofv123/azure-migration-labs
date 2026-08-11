# Fase 1: Fundação On-Premises Automatizada

> Grupo 1 da jornada de migração Azure da Contoso do Brasil: recriar, por
> meio de Infraestrutura como Código (PowerShell idempotente), um ambiente
> on-premises semelhante ao encontrado no início de um projeto real de
> migração para a nuvem.

---

## Cenário de Negócio

Antes de migrar qualquer ambiente para o Azure, é necessário compreender a
infraestrutura existente. Essa etapa permite identificar os serviços em
execução, suas dependências e a forma como o ambiente foi organizado antes
da migração.

A Contoso do Brasil é uma empresa fictícia cuja infraestrutura está
hospedada em servidores físicos dentro do próprio datacenter. O ambiente é
composto por um controlador de domínio, um servidor de arquivos e um portal
interno. Como acontece em muitas empresas, essa infraestrutura possui pouca
documentação e praticamente nenhuma automação. Esse é o ambiente **As-Is**,
utilizado como ponto de partida para a jornada de migração apresentada neste
repositório.

O Grupo 1 recria esse ambiente utilizando Hyper-V e scripts PowerShell
desenvolvidos de forma idempotente, permitindo que sejam executados mais de
uma vez sem gerar configurações duplicadas ou inconsistências.

Além de disponibilizar um ambiente funcional, esta fase estabelece uma base
documentada e reproduzível para as próximas etapas do projeto, que irão
avaliar, integrar e migrar essa infraestrutura para o Azure.

Ao final desta fase, a Contoso possui:

* Uma floresta funcional do Active Directory com estrutura organizacional.
* Distribuição automática de endereços IP e um servidor de arquivos
  organizado por departamento.
* Um portal web interno publicado com HTTPS.

Todo o ambiente é criado e validado por scripts PowerShell, servindo como o
estado inicial da infraestrutura antes das próximas fases da migração.

---

## Tecnologias Utilizadas

* **PowerShell 7** - utilizado para criar, configurar e validar toda a infraestrutura por meio de scripts, reduzindo configurações manuais.
* **Hyper-V** - hypervisor responsável por hospedar todas as máquinas virtuais, utilizando um vSwitch interno isolado com NAT (sem exposição à rede doméstica ou corporativa).
* **Windows Server 2022** (Standard Evaluation, Desktop Experience) - sistema operacional utilizado em todas as VMs desta fase.
* **Active Directory Domain Services (AD DS) + DNS** - responsáveis pela autenticação, gerenciamento de identidade e resolução de nomes.
* **DHCP** - distribuição automática de endereços IP, gateway e DNS, autorizado no Active Directory.
* **File Server (NTFS + SMB)** - compartilhamentos separados por departamento utilizando permissões NTFS e SMB.
* **IIS (Internet Information Services)** - hospedagem do portal interno utilizando HTTPS com certificado autoassinado.

---

## O Que Cada Lab Implementa

Esta seção descreve o que foi implementado em cada laboratório desta fase.

### Lab 01 - Fundação Hyper-V

Provisionamento da primeira VM (**DC01**) no Hyper-V. O laboratório cria a
estrutura de diretórios do projeto, configura o vSwitch interno
(**Lab-Internal**) com NAT na rede **192.168.10.0/24** e provisiona a máquina
virtual utilizando 4 GB de memória, 2 vCPUs e Generation 2, deixando o
ambiente preparado para a instalação do Windows Server.

### Lab 02 - Active Directory Domain Services e DNS

A máquina **DC01** é promovida a Controlador de Domínio, criando a floresta
**contoso.local** juntamente com o serviço DNS. Também são criadas cinco
Unidades Organizacionais (**TI**, **Vendas**, **Financeiro**, **Diretoria** e
**ServiceAccounts**), além da importação automática de usuários e grupos a
partir de um arquivo CSV.

### Lab 03 - DHCP e Servidor de Arquivos

A máquina **FS01** ingressa no domínio e assume as funções de servidor DHCP
e servidor de arquivos.

O DHCP é autorizado no Active Directory e distribui endereços IP na faixa
**192.168.10.100** até **192.168.10.200**.

Também são criados compartilhamentos para os departamentos de **TI**,
**Vendas** e **Financeiro**, protegidos por permissões NTFS e SMB associadas
aos grupos do Active Directory criados no laboratório anterior.

### Lab 04 - Servidor Web IIS

A máquina **WEB01** ingressa no domínio e hospeda o portal interno
**intranet.contoso.local** utilizando o IIS.

O site é publicado em HTTP e HTTPS por meio de um certificado autoassinado,
utilizando um Application Pool dedicado. O registro DNS é criado
remotamente na **DC01** utilizando **Invoke-Command**, dispensando
configurações manuais diretamente no controlador de domínio.

---

## Como Executar os Scripts (Padrão Geral)

Todos os laboratórios seguem o mesmo fluxo de execução. Os scripts são
numerados na ordem em que devem ser executados, e cada um realiza validações
ao final da configuração.

**1. Scripts executados no HOST (computador físico)**

Esses scripts criam e configuram as máquinas virtuais no Hyper-V.

```powershell
# Sempre execute o PowerShell 7 como Administrador no host
cd .\lab-0X-nome\scripts\
.\01-estrutura-pastas.ps1
```

Após cada execução, verifique a saída do script antes de prosseguir para a
próxima etapa.

**2. Scripts executados dentro da máquina virtual**

Depois que a VM estiver ligada, abra o PowerShell como Administrador dentro
da própria máquina virtual.

```powershell
.\01a-rename-ip.ps1
Restart-Computer -Force
```

Após a reinicialização, execute o próximo script da sequência.

**3. Validação**

Todos os scripts finalizam exibindo comandos **Get-*** para confirmar que
a configuração foi aplicada corretamente.

```powershell
Get-VM | Select-Object Name, State
Get-ADUser -Filter * | Select-Object Name
Get-Website | Format-Table -AutoSize
```

Caso a saída não corresponda ao esperado, recomenda-se corrigir o problema
antes de continuar para o próximo laboratório.

---

## Resumo

Esta primeira fase recria a infraestrutura on-premises da empresa fictícia
Contoso do Brasil utilizando Hyper-V, Windows Server 2022 e PowerShell.

Ao longo dos quatro laboratórios são implementados um ambiente Hyper-V,
uma floresta Active Directory, serviços de DHCP e File Server, além de um
portal interno hospedado no IIS utilizando HTTPS.

Todo o ambiente é criado por scripts idempotentes, permitindo sua execução
novamente sempre que necessário e garantindo uma infraestrutura
reproduzível, documentada e preparada para as próximas etapas da jornada de
migração para o Azure.
