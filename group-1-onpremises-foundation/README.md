# Grupo 1: Fundacao On-Premises Automatizada

Primeira fase da jornada de migracao Azure da Contoso do Brasil. A ideia aqui e recriar, via infraestrutura como codigo (scripts PowerShell idempotentes), um ambiente on-premises parecido com o que voce encontra no comeco de um projeto real de migracao pra nuvem.

## O cenario

Antes de migrar qualquer coisa pro Azure, voce precisa entender a infraestrutura que ja existe. Essa etapa serve pra identificar os servicos rodando, as dependencias entre eles e como o ambiente foi organizado antes de qualquer migracao comecar.

A Contoso do Brasil e uma empresa ficticia com infraestrutura hospedada em servidores fisicos, dentro do proprio datacenter. O ambiente tem um controlador de dominio, um servidor de arquivos e um portal interno. Como acontece em muita empresa por ai, essa infraestrutura tem pouca documentacao e quase nenhuma automacao. Esse e o ambiente As Is, o ponto de partida da trilha.

O Grupo 1 recria esse ambiente usando Hyper-V e scripts PowerShell feitos de forma idempotente, ou seja, rodar duas vezes nao gera configuracao duplicada nem quebra nada.

Alem de deixar um ambiente funcional de pe, essa fase cria uma base documentada e reproduzivel pra tudo que vem depois: as fases que vao avaliar, integrar e migrar essa infraestrutura pro Azure.

No final dessa fase a Contoso tem uma floresta funcional do Active Directory com estrutura organizacional, distribuicao automatica de IP e um servidor de arquivos organizado por departamento, e um portal web interno publicado com HTTPS. Tudo criado e validado por script, servindo como o estado inicial da infraestrutura antes das proximas fases.

## Tecnologias usadas

- **PowerShell 7**, pra criar, configurar e validar toda a infraestrutura via script, cortando configuracao manual
- **Hyper-V**, o hypervisor que hospeda todas as VMs, com um vSwitch interno isolado com NAT (sem expor nada pra rede domestica ou corporativa)
- **Windows Server 2022** (Standard Evaluation, Desktop Experience), o sistema usado em todas as VMs dessa fase
- **Active Directory Domain Services + DNS**, pra autenticacao, gerenciamento de identidade e resolucao de nomes
- **DHCP**, distribuindo IP, gateway e DNS automaticamente, autorizado dentro do Active Directory
- **File Server** com NTFS e SMB, compartilhamentos separados por departamento
- **IIS**, hospedando o portal interno com HTTPS e certificado autoassinado

## O que cada lab implementa

**Lab 01, Fundacao Hyper-V**
Provisiona a primeira VM (DC01) no Hyper-V. Cria a estrutura de pastas do projeto, configura o vSwitch interno (Lab-Internal) com NAT na rede 192.168.10.0/24 e sobe a maquina virtual com 4 GB de memoria, 2 vCPUs e Generation 2, deixando tudo pronto pra instalar o Windows Server.

**Lab 02, Active Directory Domain Services e DNS**
A DC01 vira Controlador de Dominio, criando a floresta contoso.local junto com o DNS. Tambem cria cinco Unidades Organizacionais (TI, Vendas, Financeiro, Diretoria e ServiceAccounts) e importa usuarios e grupos automaticamente de um CSV.

**Lab 03, DHCP e Servidor de Arquivos**
A FS01 entra no dominio e assume o papel de servidor DHCP e servidor de arquivos. O DHCP fica autorizado no Active Directory e distribui IP na faixa 192.168.10.100 ate 192.168.10.200. Tambem cria compartilhamentos pra TI, Vendas e Financeiro, protegidos por permissao NTFS e SMB ligada aos grupos do AD do lab anterior.

**Lab 04, Servidor Web IIS**
A WEB01 entra no dominio e hospeda o portal interno intranet.contoso.local via IIS. O site sobe em HTTP e HTTPS com certificado autoassinado, usando um Application Pool dedicado. O registro DNS e criado remotamente na DC01 via `Invoke-Command`, sem precisar mexer direto no controlador de dominio.

## Como rodar os scripts

Todo lab segue o mesmo fluxo. Os scripts sao numerados na ordem certa de execucao, e cada um valida a propria configuracao no final.

Primeiro, os scripts que rodam no host, ou seja, no computador fisico. Eles criam e configuram as VMs no Hyper-V:

```
# Sempre rode o PowerShell 7 como Administrador no host
cd .\lab-0X-nome\scripts\
.\01-estrutura-pastas.ps1
```

Depois de cada execucao, vale conferir a saida antes de ir pro proximo passo.

Depois, os scripts que rodam dentro da VM. Com a maquina ligada, abre o PowerShell como Administrador dentro dela:

```
.\01a-rename-ip.ps1
Restart-Computer -Force
```

Apos reiniciar, roda o proximo script da sequencia.

Por fim, a validacao. Todo script termina mostrando uns `Get-*` pra confirmar que a configuracao pegou:

```
Get-VM | Select-Object Name, State
Get-ADUser -Filter * | Select-Object Name
Get-Website | Format-Table -AutoSize
```

Se a saida nao bater com o esperado, o ideal e corrigir ali mesmo antes de seguir pro proximo lab.

## Resumo

Essa primeira fase recria a infraestrutura on-premises da Contoso do Brasil usando Hyper-V, Windows Server 2022 e PowerShell. Ao longo dos quatro labs sobem um ambiente Hyper-V, uma floresta Active Directory, DHCP e File Server, e um portal interno no IIS com HTTPS.

Tudo criado por script idempotente, entao da pra rodar de novo sempre que precisar. E fica uma infraestrutura reproduzivel, documentada e pronta pras proximas etapas da jornada ate o Azure.
