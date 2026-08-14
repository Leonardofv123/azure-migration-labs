# Grupo 3: Migracao

Terceiro e ultimo grupo da trilha. Aqui a Contoso do Brasil sai do Hyper-V e vai pro Azure de vez.

Os dois primeiros grupos construiram os dois lados da ponte: o Grupo 1 montou o ambiente on-premises completo (AD, DNS, DHCP, file server, IIS) e o Grupo 2 montou a fundacao Azure (rede, storage, backup, identidade hibrida, monitoramento). Esse grupo atravessa a ponte, e decide o que realmente vale a pena atravessar.

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

## Labs

- **Lab 10**: Azure Migrate, discovery e assessment. Concluido.
- **Lab 11**: rehost, migracao da WEB01 pro Azure. Concluido.
- **Lab 12**: validacao pos-migracao e cutover. Concluido.
- **Lab 13**: refactor, WEB01 pro Azure App Service. Concluido com limitacao documentada.
- **Lab 14**: framework de decisao dos 5 Rs. Concluido.

## O arco do grupo

Os cinco labs seguem uma progressao pensada de proposito:

```
LAB 10   descobrir o que existe e quanto custa migrar
LAB 11   migrar de fato (rehost)
LAB 12   decidir se a migracao esta pronta pra producao
LAB 13   questionar se rehost era o melhor caminho
LAB 14   aplicar o criterio pra todas as cargas
```

Os tres primeiros sao execucao. Os dois ultimos sao decisao, e e ai que a diferenca entre migrar e migrar bem aparece.

## Estrategias aplicadas

O Lab 14 consolida a analise toda, mas resumindo o que aconteceu com cada carga:

- **contoso-web01** virou refactor. O site nao tem dependencia de sistema operacional, entao cabe tranquilo em PaaS.
- **contoso-fs01** virou replace. Azure Files substitui ele direto, e o File Sync ja estava configurado desde o Lab 06.
- **contoso-dc01** ficou em retain. E a raiz de identidade, entao sai por ultimo, depois de todo mundo que depende dele.
- **contoso-gw01** virou retire. Sem rede local pra rotear, o VPN Gateway ja assume o papel dele sozinho.

O rehost foi o caminho executado na WEB01 (Lab 11), por ser o mais direto. Ja o Lab 13 comparou esse resultado com o refactor: 7 recursos contra 3, com reducao de quase 88% no custo mensal.

## Limitacoes conhecidas

Dois bloqueios de ambiente pegaram esse grupo. Os dois estao documentados com detalhe nos labs onde apareceram.

No **Lab 10**, o Azure Migrate Appliance nao completava o registro. Conexoes HTTPS com payload maior caiam na rede residencial que eu uso no lab, o mesmo padrao que ja tinha travado o Entra Connect no Lab 07. Resolvi fazendo o discovery por import de CSV. Isso teve efeito cascata: no Lab 11 o rehost saiu por IaC em vez de ASR, e no Lab 12 o mapa de dependencias ficou manual.

No **Lab 13**, a cota pra App Service Plan estava zerada na subscription. Testei seis combinacoes (Windows/Linux, B1/F1, eastus2/brazilsouth) e todas bateram no mesmo erro 401. O Terraform validou certinho no plan, mas o apply ficou bloqueado.

Em nenhum dos dois casos o lab ficou incompleto: o assessment saiu com sizing e custo calculados, a WEB01 chegou no Azure servindo a mesma pagina, e a comparacao rehost x refactor ta fundamentada em codigo real, nao em suposicao.

## Ciclo de vida dos recursos

Os recursos do Lab 11 foram criados, validados e destruidos com `terraform destroy` logo depois de eu coletar as evidencias. O codigo fica no repositorio e recria a infraestrutura toda vez que precisar.

Isso e proposital. Em ambiente de estudo, manter uma VM de pe sem ninguem usando e so custo desperdicado. Numa migracao real a logica se inverte: depois do cutover, quem se desliga e a origem, nao o destino.

## Custos

Os labs de migracao criam recurso que cobra por hora. Cada lab avisa a hora certa de deletar, e o que continua cobrando mesmo com a VM desligada (IP publico e disco continuam contando, por exemplo).

Regra geral do repositorio: tirar print antes de destruir qualquer coisa.
