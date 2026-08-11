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
ON-PREMISES (Hyper-V)                    AZURE (eastus2)

contoso-dc01   AD DS + DNS               vnet-contoso-eus2
contoso-fs01   File Server + DHCP        vm-web-prod-eus2
contoso-web01  IIS                       stcontosoeus2lab
contoso-gw01   RRAS                      rsv-contoso-eus2
                                         law-contoso-eus2
       |
       |            MIGRACAO
       +--------------------------------->  vm-web01-migrated
                                            (Lab 11)
```

---

## Labs

| Lab | Titulo | Status |
|-----|--------|--------|
| 10 | Azure Migrate: Discovery e Assessment | concluido |
| 11 | Rehost: migracao da WEB01 para o Azure | concluido |
| 12 | Validacao pos-migracao e cutover | pendente |

---

## Estrategia de migracao

A trilha usa o rehost (lift and shift) como estrategia principal. E o
caminho mais direto: a carga de trabalho sai do Hyper-V e chega no Azure
sem mudanca de arquitetura.

```
REHOST          a carga vai como esta         <- adotado aqui
REPLATFORM      troca componentes por PaaS
REFACTOR        reescreve a aplicacao
```

A ordem de migracao comeca pela WEB01 por dois motivos: ela nao depende
do AD para funcionar (o IIS sobe sem domain join) e e a menos acoplada
ao resto do ambiente. DC01 e FS01 tem dependencia mutua via DNS e File
Sync, e migram depois.

---

## Limitacao conhecida e como ela mudou o caminho

O registro do Azure Migrate Appliance nao completa neste ambiente. O
diagnostico completo esta no Lab 10, mas o resumo e: conexoes HTTPS com
payload maior caem na rede residencial usada no lab, o mesmo padrao ja
documentado no Lab 07 com o Entra Connect.

Isso teve consequencia nos dois labs:

```
LAB 10   discovery feito por import CSV em vez do Appliance
LAB 11   rehost feito por IaC em vez de replicacao via ASR
```

Nos dois casos o resultado do lab foi preservado: o assessment saiu
com sizing e custo, e a WEB01 chegou no Azure servindo a mesma pagina.
O que mudou foi o caminho, e cada README diz qual foi e por que.

---

## Custos

Os labs de migracao criam recursos que cobram por hora. Cada lab avisa
o momento de deletar e o que fica cobrando mesmo com a VM desligada
(IP publico e disco continuam contando).

Regra geral do repositorio: tirar print antes de destruir qualquer coisa.
