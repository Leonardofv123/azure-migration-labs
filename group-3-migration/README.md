# Grupo 3 - Migracao

Terceiro e ultimo grupo da trilha. Aqui a Contoso do Brasil sai do
Hyper-V e vai para o Azure.

Os dois primeiros grupos construiram os dois lados da ponte: o Grupo 1
montou o ambiente on-premises completo (AD, DNS, DHCP, file server, IIS)
e o Grupo 2 montou a fundacao Azure (rede, storage, backup, identidade
hibrida, monitoramento). Este grupo atravessa - e decide o que vale a
pena atravessar.

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
| 12 | Validacao pos-migracao e cutover | concluido |
| 13 | Refactor: WEB01 para Azure App Service | concluido com limitacao documentada |
| 14 | Framework de decisao dos 5 Rs | concluido |

---

## O arco do grupo

Os cinco labs seguem uma progressao proposital:

```
LAB 10   descobrir o que existe e quanto custa migrar
LAB 11   migrar de fato (rehost)
LAB 12   decidir se a migracao esta pronta para producao
LAB 13   questionar se rehost era o melhor caminho
LAB 14   aplicar o criterio a todas as cargas
```

Os tres primeiros sao execucao. Os dois ultimos sao decisao - e e
onde a diferenca entre migrar e migrar bem aparece.

---

## Estrategias aplicadas

O Lab 14 consolida a analise, mas o resumo e:

| Carga | Estrategia | Justificativa curta |
|-------|-----------|---------------------|
| contoso-web01 | Refactor | site sem dependencia de SO, cabe em PaaS |
| contoso-fs01 | Replace | Azure Files substitui, File Sync ja configurado |
| contoso-dc01 | Retain | raiz de identidade, sai depois de quem depende dela |
| contoso-gw01 | Retire | sem rede local para rotear, VPN Gateway substitui |

O rehost foi executado na WEB01 (Lab 11) como caminho mais direto, e
o Lab 13 comparou com o refactor: 7 recursos contra 3, e reducao de
aproximadamente 88 por cento no custo mensal.

---

## Limitacoes conhecidas

Dois bloqueios de ambiente afetaram este grupo. Ambos estao
documentados em detalhe nos labs onde apareceram.

```
LAB 10   Azure Migrate Appliance nao completa o registro
         Conexoes HTTPS com payload maior caem na rede residencial
         usada no lab - mesmo padrao do Lab 07 com Entra Connect.
         Discovery feito por import CSV.
         Consequencia no Lab 11: rehost por IaC em vez de ASR.
         Consequencia no Lab 12: mapa de dependencias manual.

LAB 13   Cota zerada para App Service Plan na subscription
         Seis combinacoes testadas (Windows/Linux, B1/F1,
         eastus2/brazilsouth) com o mesmo erro 401.
         Terraform validado por plan, apply bloqueado.
```

Em nenhum dos casos o resultado do lab foi perdido: o assessment saiu
com sizing e custo, a WEB01 chegou no Azure servindo a mesma pagina, e
a comparacao rehost x refactor esta fundamentada em codigo real.

---

## Ciclo de vida dos recursos

Os recursos do Lab 11 foram criados, validados e destruidos com
`terraform destroy` apos a coleta das evidencias. O codigo Terraform
continua no repositorio e recria a infraestrutura quando necessario.

Isso e proposital: em ambiente de estudo, manter uma VM de pe sem
ninguem usando e so custo. Em migracao real a logica se inverte -
depois do cutover, quem se desliga e a origem, nao o destino.

---

## Custos

Os labs de migracao criam recursos que cobram por hora. Cada lab avisa
o momento de deletar e o que fica cobrando mesmo com a VM desligada
(IP publico e disco continuam contando).

Regra geral do repositorio: tirar print antes de destruir qualquer coisa.
