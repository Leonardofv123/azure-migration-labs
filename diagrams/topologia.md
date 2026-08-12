# Diagramas (ASCII)

Os diagramas deste repositorio sao mantidos em ASCII, dentro de blocos
de codigo, para serem leves e versionaveis.

Esta pagina reune a visao de conjunto da trilha. Cada lab tem o mesmo
diagrama no seu proprio README, junto do contexto que o explica.

---

## Topologia on-premises (Labs 01 a 04)

```
              Rede do laboratorio: 192.168.10.0/24
                      (isolada via NAT)

  [ DC01 ]              [ FS01 ]                [ WEB01 ]
  192.168.10.10         192.168.10.20           192.168.10.30
  AD DS + DNS           DHCP + File Server      IIS (IntranetContoso)
                        Escopo: .100-.200         porta 80  (HTTP)
                                                  porta 443 (HTTPS)
      |                       |                        |
      +-----------------------+------------------------+
                              |
                  [ vSwitch "Lab-Internal" ]
                              |
              [ Host = 192.168.10.1 = GATEWAY ]
                              |
                    [ NAT "Lab-NAT" ]
                              |
                          Internet

  DNS na DC01: intranet.contoso.local -> A -> 192.168.10.30
```

Estrutura de compartilhamentos criada no Lab 03:

```
E:\Shares\  (na FS01)
     |-- Vendas        -> GG_Vendas     (Modify)
     |-- Financeiro    -> GG_Financeiro (Modify)
     \-- TI            -> GG_TI         (Modify)

(Domain Admins e SYSTEM: Full Control em todas)
```

A partir do Lab 08 o gateway deixa de ser o host e passa a ser uma VM
dedicada, a contoso-gw01, rodando RRAS.

---

## Floresta Active Directory (Lab 02)

```
Floresta: contoso.local
    |
Dominio: contoso.local (CONTOSO)
    |
OUs: TI | Vendas | Financeiro | Diretoria | ServiceAccounts
    |
Grupos: GG_TI | GG_Vendas | GG_Financeiro | GG_Diretoria
```

Oito usuarios distribuidos nas quatro OUs operacionais. A OU
ServiceAccounts fica reservada para contas de servico.

---

## Fundacao Azure (Lab 05)

```
                        AZURE (eastus2)

+---------------------------------------------------------+
|  rg-network-prod-eus2                                    |
|                                                          |
|  vnet-contoso-eus2   10.10.0.0/16                        |
|      |                                                   |
|      +-- subnet-web         10.10.1.0/24                 |
|      |       vm-web-prod-eus2   10.10.1.4                |
|      |       Standard_D2s_v3, Windows Server 2022        |
|      |       auto-shutdown 22h                           |
|      |                                                   |
|      +-- GatewaySubnet      10.10.255.0/27               |
|              reservada para o VPN Gateway (Lab 08)       |
|                                                          |
|  nsg-web        Allow-Web: portas 80 e 443               |
|  pip-web-eus2   IP publico                               |
+---------------------------------------------------------+
```

A GatewaySubnet nao aceita NSG nem recurso comum. E exigencia do
proprio VPN Gateway, que so aceita esse nome exato.

---

## Storage, backup e File Sync (Lab 06)

```
    FS01 (on-prem, Lab 03)          AZURE (Lab 06)

+--------------------------+   +----------------------------+
|  C:\VendasLocal          |   |  Storage Account            |
|  (Server Endpoint)       |<->|  stcontosoeus2xxxx          |
+--------------------------+   |                             |
                          sync |    File Share "vendas"       |
                               |    (Cloud Endpoint)          |
                               |                             |
                               |    Blob Container            |
                               |    "documentos" (privado)    |
                               +----------------------------+

  vm-web-prod-eus2 (Lab 05)        Recovery Services Vault

+--------------------------+   +----------------------------+
|  VM em producao          |-->|  rsv-contoso-eus2           |
+--------------------------+   |  DefaultPolicy              |
                           bkp +----------------------------+

Storage Sync Service: sync-contoso-eus2
Sync Group:           sync-vendas
```

Essa sincronizacao e o que torna o Replace do FS01 viavel no Lab 14:
os arquivos ja estao na nuvem, falta so cortar o lado local.

---

## Identidade hibrida (Lab 07)

```
ON-PREMISES (Hyper-V)              MICROSOFT ENTRA ID

contoso-dc01                       Tenant:
AD DS + DNS                        <tenant>.onmicrosoft.com
192.168.10.10
     |                                          ^
     |   Entra Connect Sync                     |
     |   Password Hash Sync                     |
     +------------------------------------------+
          sincronizacao periodica
          (delta a cada 30 min, ou
           forcada via PowerShell)

Usuarios sincronizados (8):
   Ana Souza            Bruno Lima
   Carla Mendes         Diego Rocha
   Elaine Castro        Felipe Alves
   Gabriela Nunes       Henrique Dias

Conta de servico:
   aadconnect-admin@<tenant>.onmicrosoft.com
   (cloud-only, papel: Hybrid Identity Administrator)
```

O PHS sincroniza o hash da senha, nao a senha. O usuario autentica no
Entra ID sem que o AD local precise estar acessivel.

A conta de servico precisa ser cloud-only: conta MSA pessoal nao e
aceita pelo Entra Connect, mesmo sendo Global Admin.

---

## VPN Site-to-Site (Lab 08)

```
                  ON-PREMISES (Hyper-V)
+-------------------------------------------------------+
|   contoso-dc01              contoso-fs01              |
|   192.168.10.10             192.168.10.20             |
|        |                          |                    |
|        +----------+---------------+                    |
|                   |                                    |
|           vSwitch Lab-Internal                         |
|              192.168.10.0/24                           |
|                   |                                    |
|           contoso-gw01                                 |
|           192.168.10.1      (RRAS)                     |
|           172.20.129.160    (Default Switch)           |
+-------------------+-----------------------------------+
                    |
                    | IPsec / IKEv2
                    | PSK + NAT-T (UDP 4500)
                    v
          +----------------------+
          |      INTERNET        |
          |  IP publico dinamico |
          +----------+-----------+
                     |
                     v
                   AZURE
+-------------------------------------------------------+
|   pip-vng-eus2           Standard, Zones 1,2,3         |
|        |                                               |
|        v                                               |
|   vng-contoso-eus2       VpnGw1AZ / RouteBased         |
|        |                                               |
|        |  GatewaySubnet 10.10.255.0/27                 |
|        v                                               |
|   vnet-contoso-eus2 (10.10.0.0/16)                     |
|        |                                               |
|        v                                               |
|   subnet-web (10.10.1.0/24)                            |
|   vm-web-prod-eus2 -> 10.10.1.4                        |
|                                                        |
|   lng-onprem-eus2        IP de casa + rede local       |
|   cn-s2s-eus2            Connection IPsec/IKEv2        |
+-------------------------------------------------------+
```

O tunel estabelece e valida no plano de controle, mas o trafego de
dados nao passa por causa de NAT duplo (Hyper-V mais roteador
domestico). Limitacao documentada no Lab 08.

Os recursos do gateway foram deletados apos a validacao, porque
cobram por hora.

---

## Monitoramento hibrido (Lab 09)

```
        ON-PREMISES (Hyper-V)                  AZURE

+-----------------------------------+
|  contoso-dc01   AD DS + DNS       |--+
|  + azcmagent (Arc) + AMA          |  |
|                                   |  |
|  contoso-fs01   File Server       |--+
|  + azcmagent (Arc) + AMA          |  |   HTTPS / 443
|                                   |  +----------------------+
|  contoso-web01  IIS               |--+                      |
|  + azcmagent (Arc) + AMA          |                         v
+-----------------------------------+   +----------------------------+
                                        |  dcr-windows-contoso        |
+-----------------------------------+   |  (Data Collection Rule)     |
|  vm-web-prod-eus2                 |-->|  - 7 perf counters @ 60s    |
|  10.10.1.4                        |   |  - System / Application     |
|  + AMA (extensao nativa)          |   |  - Security (4624, 4625,    |
+-----------------------------------+   |    4720, 4726)              |
                                        +-------------+--------------+
                                                      |
                                                      v
                                        +----------------------------+
                                        |  law-contoso-eus2           |
                                        |  Log Analytics Workspace    |
                                        |  PerGB2018 / 31 dias        |
                                        +-------------+--------------+
                                                      |
                             +------------------------+------------------------+
                             v                        v                        v
                       Queries KQL                Alertas                 Workbooks
```

O Azure Arc estende o plano de controle do Azure ate as maquinas
Hyper-V. O AMA coleta, e a DCR define o que coletar.

Instalar o agente e criar a associacao da DCR sao um par indivisivel:
sem associacao, o agente roda e nao envia nada, em silencio.

---

## Discovery e Assessment (Lab 10)

```
        ON-PREMISES                          AZURE

+-----------------------------+
|  contoso-dc01   .10         |
|  contoso-fs01   .20         |      +---------------------------+
|  contoso-web01  .30         |----->|  migrate-contoso-eus2      |
|  contoso-gw01   .1          |      |  (Brazil South)            |
+-----------------------------+      |                            |
             |                       |  Discovery via import CSV  |
             |  inventario CSV       +-------------+-------------+
             |  4 servidores                       |
             +-------------------------------------+
                                                   v
                                     +---------------------------+
                                     |  assessment-contoso-iaas   |
                                     |                            |
                                     |  4 de 4 servidores Ready   |
                                     |  Standard_A2_v2 sugerido   |
                                     |  USD 440,45/mes            |
                                     |  Sem migration blockers    |
                                     +---------------------------+
```

O Azure Migrate Appliance foi configurado mas nao completou o
registro, por limitacao de rede documentada no Lab 10. O discovery
foi feito por import CSV, que entrega assessment valido sem depender
de conectividade continua.

---

## Rehost da WEB01 (Lab 11)

```
      ANTES                                DEPOIS

+---------------------+            +---------------------------+
|  contoso-web01      |            |  vm-web01-migrated         |
|  192.168.10.30      |            |  10.10.1.5   (privado)     |
|  Hyper-V local      |    ---->   |  20.114.161.35 (publico)   |
|  Windows Server     |            |  Standard_D2s_v7           |
|  + IIS              |            |  Windows Server 2022 Gen2  |
+---------------------+            |  + IIS                     |
                                   +---------------------------+
                                                |
                                   provisionado por Terraform
                                   dentro da vnet-contoso-eus2
                                   que ja existia do Lab 05

Recursos criados:
   rg-migrated-prod-eus2
     pip-web01-migrated-eus2      IP publico Standard
     nsg-web01-migrated           libera 80, 443 e 3389
     nic-web01-migrated-eus2      na subnet-web existente
     vm-web01-migrated            a VM
     auto-shutdown                22h, horario de Brasilia
```

---

## Cutover (Lab 12)

```
   1. congelar mudancas na origem
              |
              v
   2. sincronizar delta final
              |
              v
   3. validar o destino
              |
              v
   4. mudar apontamento de trafego   <-- ponto de nao retorno
              |
              v
   5. monitorar janela critica
              |
              v
   6. desligar a origem, sem deletar
              |
              v
   7. deletar a origem, dias depois
```

Os passos 6 e 7 sao separados de proposito. Desligar e reversivel em
minutos. Deletar nao e reversivel de jeito nenhum.

---

## Rehost x Refactor (Labs 11 e 13)

```
       REHOST (Lab 11)                    REFACTOR (Lab 13)

+---------------------------+     +---------------------------+
|  azurerm_windows_vm       |     |  azurerm_linux_web_app     |
|  azurerm_network_interface|     |  azurerm_service_plan      |
|  azurerm_nsg              |     |  azurerm_resource_group    |
|  azurerm_public_ip        |     +---------------------------+
|  azurerm_nic_nsg_assoc    |
|  azurerm_resource_group   |            3 recursos
|  azurerm_devtest_shutdown |            ~USD 13/mes (B1)
+---------------------------+
                                    AZURE administra:
       7 recursos                     patch do SO
       ~USD 110/mes                   runtime da aplicacao
                                      disponibilidade
  VOCE administra:                    escala automatica
    patch do Windows
    instalacao do IIS
    configuracao do servico
    escala manual
```

O Terraform do refactor esta validado por `terraform plan`, mas o
provisionamento foi bloqueado por cota da subscription. Detalhes no
Lab 13.

---

## Decisao dos 5 Rs (Lab 14)

```
+------------------+------------+----------------------------------+
|  CARGA           | ESTRATEGIA | DESTINO                          |
+------------------+------------+----------------------------------+
|  contoso-web01   | REFACTOR   | Azure App Service                |
|  IIS             |            | site sem dependencia de SO       |
+------------------+------------+----------------------------------+
|  contoso-fs01    | REPLACE    | Azure Files                      |
|  File Server     |            | File Sync ja configurado (L06)   |
+------------------+------------+----------------------------------+
|  contoso-dc01    | RETAIN     | AD DS local + Entra ID           |
|  AD DS + DNS     |            | sai depois de quem depende dele  |
+------------------+------------+----------------------------------+
|  contoso-gw01    | RETIRE     | nenhum                           |
|  RRAS            |            | sem rede local para rotear       |
+------------------+------------+----------------------------------+
```

Ordem de execucao ditada pelas dependencias, nao pela importancia:

```
   1. WEB01     nao depende de nada
        |
        v
   2. FS01      depende do DC01 para permissoes
        |
        v
   3. DC01      so quando ninguem mais depender dele
        |
        v
   4. GW01      ultimo, quando nao houver rede local
```

Custo comparado:

```
   REHOST DE TUDO          ~USD 440/mes
   ESTRATEGIA MISTA        ~USD  18/mes
```

A diferenca nao vem de negociar preco. Vem de nao migrar o que nao
precisava ser migrado.
