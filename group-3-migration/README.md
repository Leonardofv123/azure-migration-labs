# Grupo 3 - Migracao

Terceiro grupo da trilha. Aqui a Contoso do Brasil finalmente sai do
Hyper-V e vai para o Azure de verdade.

Os dois primeiros grupos construiram os dois lados da ponte: o Grupo 1
montou o ambiente on-premises completo (AD, DNS, DHCP, file server, IIS)
e o Grupo 2 montou a fundacao Azure (rede, storage, backup, identidade
hibrida, monitoramento). Este grupo atravessa.

---

## Contexto

```
ON-PREMISES (Hyper-V)                    AZURE (eastus2 / brazilsouth)

contoso-dc01   AD DS + DNS               vnet-contoso-eus2
contoso-fs01   File Server + DHCP        vm-web-prod-eus2
contoso-web01  IIS                       stcontosoeus2lab
contoso-gw01   RRAS                      rsv-contoso-eus2
                                         law-contoso-eus2
       |                                          
       |            MIGRACAO                      
       +--------------------------------->  Azure Migrate
                                            (Grupo 3)
```

---

## Labs

| Lab | Titulo | Status |
|-----|--------|--------|
| 10 | Azure Migrate: Discovery e Assessment | concluido |
| 11 | Rehost: replicacao e migracao da WEB01 | pendente |
| 12 | Validacao pos-migracao e cutover | pendente |

---

## Estrategia de migracao

A trilha usa o rehost (lift and shift) como estrategia principal. E o
caminho mais direto: a VM sai do Hyper-V e chega no Azure praticamente
igual, sem mudanca de arquitetura.

```
REHOST          a VM vai como esta            <- adotado aqui
REPLATFORM      troca componentes por PaaS
REFACTOR        reescreve a aplicacao
```

A ordem de migracao comeca pela WEB01 por dois motivos: ela nao depende
do AD para funcionar (o IIS sobe sem domain join) e e a menos acoplada
ao resto do ambiente. DC01 e FS01 tem dependencia mutua via DNS e File
Sync, e migram depois.

---

## Limitacao conhecida

O registro do Azure Migrate Appliance nao completa neste ambiente. O
diagnostico completo esta no Lab 10, mas o resumo e: conexoes HTTPS com
payload maior caem na rede residencial usada no lab, o mesmo padrao ja
documentado no Lab 07 com o Entra Connect.

O discovery foi feito por import CSV, que entrega assessment valido sem
depender de conectividade continua.

---

## Custos

Diferente dos grupos anteriores, os labs de migracao criam recursos que
cobram por hora durante a replicacao. Cada lab avisa o momento de deletar.

Regra geral do repositorio: tirar print antes de destruir qualquer coisa.
