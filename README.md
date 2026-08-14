# Azure Migration Labs

Esse repo documenta uma migracao (fake, mas feita do jeito serio) de uma empresa ficticia, a Contoso do Brasil, saindo de um ambiente on-premises em Hyper-V e indo pro Azure. Tudo automatizado em PowerShell e Terraform, nada de clicar em portal e fingir que foi trabalho.

A ideia surgiu porque eu queria aprender Azure migration de verdade, nao so passar em certificacao. Entao montei um datacenter local fake com Hyper-V (AD, DHCP, file server, IIS) e fui migrando peca por peca pra nuvem, documentando os perrengues no caminho.

## Como os labs se conectam

Nao é uma lista de exercicios soltos. Um lab usa o que o outro deixou pronto: o Lab 11 migra a VNet que o Lab 05 criou, o Lab 14 fecha a decisao usando o custo calculado no Lab 10, o File Sync do Lab 06 e o Entra Connect do Lab 07. Entao faz mais sentido ler em ordem do que pular direto pro que interessa.

## Os labs

**Grupo 1: Fundacao on-premises**
- Lab 01: Hyper-V + primeira VM Windows Server
- Lab 02: Active Directory + DNS
- Lab 03: DHCP + File Server
- Lab 04: IIS

**Grupo 2: Chegando no Azure**
- Lab 05: VMs e Virtual Networks
- Lab 06: Storage, Backup e File Sync
- Lab 07: Entra ID + Entra Connect (identidade hibrida)
- Lab 08: VPN Site-to-Site *(fechei com uma limitacao documentada, ve o README do lab)*
- Lab 09: Monitoramento hibrido com Azure Monitor + Arc

**Grupo 3: Migrando de verdade**
- Lab 10: Azure Migrate, discovery e assessment *(tambem com limitacao documentada)*
- Lab 11: Rehost da WEB01
- Lab 12: Validacao pos-migracao e cutover
- Lab 13: Refactor da WEB01 pra App Service *(limitacao documentada aqui tambem)*
- Lab 14: Framework de decisao dos 5 Rs, decidindo o destino de cada servidor

## O que ficou de fora, e por que

Nao tem migracao de banco de dados (DMS) porque a Contoso simplesmente nao tem banco. Criar um SQL Server so pra ter o que migrar seria forcar a barra.

Nao tem Azure Site Recovery porque esbarra na mesma limitacao de conectividade continua que ja pegou o Azure Migrate Appliance no Lab 10. O conceito de failover/failback ja fica coberto no Lab 12.

E nao tem projeto capstone separado porque, na pratica, a integracao entre os labs JA é o capstone. Fazer mais um projeto no final seria repetir a trilha.

## Estrutura de pastas

```
group-1-onpremises-foundation/
├── lab-01-hyperv/
├── lab-02-active-directory/
├── lab-03-dhcp-fileserver/
└── lab-04-iis/

group-2-azure-foundation/
├── lab-05-azure-vnet-vm/
├── lab-06-storage-backup/
├── lab-07-entra-connect/
├── lab-08-vpn-site-to-site/
└── lab-09-monitoramento/

group-3-migration/
├── lab-10-azure-migrate/
├── lab-11-rehost/
├── lab-12-cutover/
├── lab-13-refactor/
└── lab-14-framework-5rs/
```

Cada lab segue o mesmo molde: README com objetivo/topologia/passo a passo/desafios, pasta de scripts, terraform quando tem, e screenshots de validacao.

## Como ficou o ambiente no final

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

A WEB01 foi migrada de verdade no Lab 11 e os recursos foram destruidos logo depois da validacao (documentado la). As decisoes finais de Retain, Replace e Retire saem do framework aplicado no Lab 14.

## Algumas convencoes que segui

- Tudo nasce de script ou codigo, e idempotente (rodar duas vezes nao pode quebrar nada)
- Rede do lab: `192.168.10.0/24` (vSwitch interno com NAT) | Rede do Azure: `10.10.0.0/16`
- VMs sempre DC01, FS01, WEB01, GW01
- Recursos Azure seguem `<tipo>-<nome>-<ambiente>-<regiao>`
- Segredo nenhum vai versionado, sempre `Read-Host`, `Get-Credential` ou variavel `sensitive` no Terraform
- Diagramas em ASCII dentro de bloco de codigo, pra dar pra copiar sem sofrer

## Sobre os perrengues

Cada lab tem uma secao contando os problemas reais que apareceram, inclusive os diagnosticos errados que eu fiz antes de achar a causa certa. Isso e proposital: os erros mais uteis dessa trilha nao foram de sintaxe, foram de metodo. Trocar de regiao quando o problema era outra variavel, aplicar um fix que so durava a sessao, ou ler um erro de permissao onde na verdade era politica de dispositivo.

Tem um padrao que se repetiu com a mesma mensagem de erro e causas completamente diferentes, e acho que vale registrar:

```
LAB 05   SkuNotAvailable -> cota zerada da familia B na conta
LAB 11   SkuNotAvailable -> falta de capacidade na regiao
LAB 13   401 Unauthorized -> cota zerada pro App Service Plan
```

Mensagem parecida, causa diferente. Cota se resolve pedindo aumento; capacidade se resolve trocando de regiao ou esperando. Confundir os dois te faz perder horas tentando a solucao errada. O que resolve e testar mudando uma variavel de cada vez, nao varias ao mesmo tempo.

Feito por Leonardo Fabricio Vieira Fernandes, estudante de Engenharia de Software no Inatel.

Licenca MIT, arquivo LICENSE tem os detalhes.
