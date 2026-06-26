# Lab 01 - Hyper-V + Primeira VM Windows Server

## Objetivo

Preparar o host para virtualizacao, criar a rede isolada do laboratorio e
provisionar a primeira VM (DC01) por codigo, de forma reproduzivel. O cenario
e o engenheiro da Contoso montando um datacenter de bolso, padronizando a
criacao de servidores via script em vez de instalacao manual.

## Topologia

```
[ contoso-dc01 = 192.168.10.10 ]
         |
         v
[ vSwitch "Lab-Internal" (Internal) ]
         |
         v
[ Host = 192.168.10.1 = GATEWAY ]
         |
         v
[ NAT "Lab-NAT" traduz 192.168.10.0/24 ]
         |
         v
     Internet
```

## Pre-requisitos

- Hyper-V instalado e habilitado no host.
- ISO do Windows Server 2022 x64 (versao Evaluation) em
  `D:\Hyper-V\contoso-lab\ISOs\`.
- PowerShell 7 executado como Administrador.
- Host com 16 GB de RAM e SSD com espaco livre (50 GB para este lab).

## Como rodar

Os scripts em `scripts/` sao numerados na ordem de execucao.

1. `01-estrutura-pastas.ps1` (no host): cria as pastas e define os caminhos
   padrao do Hyper-V.
2. `02-vswitch-nat.ps1` (no host): cria o vSwitch interno, da o IP de gateway
   ao host e configura o NAT.
3. `03-criar-vm.ps1` (no host): cria a VM contoso-dc01 com a ISO acoplada.
4. Instalar o Windows Server pela interface grafica (Hyper-V Manager,
   Conectar, Iniciar). Edicao: Standard Evaluation (Desktop Experience).
5. `04-rename-ip.ps1` (dentro da VM): renomeia para DC01 e configura o IP
   fixo. Reiniciar a VM ao final.

## Validacao

Apos o reboot, dentro da VM:

```powershell
$env:COMPUTERNAME                                    # deve ser DC01
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 |
    Select-Object IPAddress, PrefixLength            # 192.168.10.10 / 24
Test-NetConnection -ComputerName 192.168.10.1        # PingSucceeded = True
```

## Resultado

- Pasta isolada no SSD para o projeto.
- vSwitch Lab-Internal com NAT (rede 192.168.10.0/24).
- VM DC01 com 4 GB RAM, 2 vCPU, Generation 2, IP fixo 192.168.10.10.
- Conectividade com o gateway confirmada.

## Pendencia conhecida (esperada)

A internet por nome ainda nao funciona ao final do Lab 01, porque o DNS da VM
aponta para ela mesma e o servico DNS so e instalado no Lab 02. A rede em si
esta saudavel (ping ao gateway funciona). Isso e resolvido no Lab 02 ao
instalar a role DNS.

## Conceitos cobertos

vSwitch (externo, interno, privado), gateway, NAT, IP fixo vs dinamico,
Generation 2, disco dinamico, idempotencia em scripts.
