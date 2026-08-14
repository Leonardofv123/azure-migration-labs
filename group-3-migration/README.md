Grupo 3: Migração

Este é o terceiro e último grupo da trilha. Aqui a Contoso do Brasil deixa o ambiente que estava rodando no Hyper-V e começa, de fato, a migração para o Azure.

Nos dois primeiros grupos, preparei os dois lados desse processo: o Grupo 1 criou o ambiente on-premises completo, com AD, DNS, DHCP, File Server e IIS, enquanto o Grupo 2 montou a base no Azure, incluindo rede, storage, backup, identidade híbrida e monitoramento.

Agora chegou a hora de conectar esses dois ambientes e decidir, para cada carga, o que realmente faz sentido migrar e de que forma.

Contexto
ON-PREMISES (Hyper-V)                    AZURE (eastus2)
contoso-dc01   AD DS + DNS               vnet-contoso-eus2
contoso-fs01   File Server + DHCP        vm-web-prod-eus2
contoso-web01  IIS                       stcontosoeus2lab
contoso-gw01   RRAS                      rsv-contoso-eus2
                                         law-contoso-eus2
       |
       |              MIGRAÇÃO
       +--------------------------------->  vm-web01-migrated
                                             (Lab 11)
Labs
Lab	Título	Status
10	Azure Migrate: Discovery e Assessment	Concluído
11	Rehost: migração da WEB01 para o Azure	Concluído
12	Validação pós-migração e cutover	Concluído
13	Refactor: WEB01 para Azure App Service	Concluído, com limitação documentada
14	Framework de decisão dos 5 Rs	Concluído
O que foi feito neste grupo

Os cinco labs foram pensados para seguir uma sequência lógica:

LAB 10   entender o ambiente e estimar o custo da migração
LAB 11   realizar a migração da WEB01 para o Azure
LAB 12   validar o ambiente migrado e preparar o cutover
LAB 13   comparar o rehost com uma abordagem de refactor
LAB 14   aplicar os critérios dos 5 Rs às demais cargas

Os três primeiros labs estão mais focados na execução. Nos dois últimos, a ideia muda um pouco: em vez de simplesmente migrar tudo, o objetivo é avaliar qual estratégia faz mais sentido para cada carga.

É justamente essa parte que considero mais importante em um projeto de migração. Migrar uma máquina para a nuvem é relativamente simples. O desafio é entender o que deve ser migrado, o que deve ser modernizado e o que talvez nem precise continuar existindo.

Estratégias utilizadas

O Lab 14 reúne a análise feita ao longo do grupo. O resultado foi:

Carga	Estratégia	Motivo
contoso-web01	Refactor	A aplicação não possui dependências específicas do sistema operacional e pode ser executada em PaaS
contoso-fs01	Replace	O Azure Files pode assumir o papel do File Server, aproveitando também o File Sync já configurado
contoso-dc01	Retain	É a base da identidade do ambiente e deve ser uma das últimas cargas a serem retiradas
contoso-gw01	Retire	Com a conectividade sendo feita pelo Azure VPN Gateway, o RRAS deixa de ter uma função necessária

A WEB01 foi migrada inicialmente utilizando a estratégia de Rehost, por ser a opção mais simples e direta para colocar a carga no Azure.

Depois, no Lab 13, comparei esse resultado com uma abordagem de Refactor, utilizando Azure App Service. A comparação mostrou uma redução significativa na quantidade de recursos envolvidos: de 7 recursos no rehost para 3 no refactor, além de uma redução estimada de quase 88% no custo mensal.

Limitações encontradas

Durante os labs, encontrei dois problemas de ambiente. Em vez de simplesmente contornar os erros e seguir em frente, deixei os dois documentados nos respectivos labs.

Lab 10 — Azure Migrate

O Azure Migrate Appliance não conseguia concluir o registro. As conexões HTTPS com payloads maiores estavam sendo interrompidas pela rede residencial utilizada no laboratório. O mesmo comportamento já havia aparecido anteriormente durante a configuração do Entra Connect no Lab 07.

Como alternativa, fiz o discovery utilizando a importação por CSV.

Essa limitação acabou influenciando os próximos labs: o rehost da WEB01 foi feito utilizando IaC em vez de ASR, e o mapa de dependências do Lab 12 precisou ser construído manualmente.

Lab 13 — Azure App Service

No refactor da WEB01, encontrei uma limitação de cota para o App Service Plan na subscription utilizada no laboratório.

Testei seis combinações diferentes, envolvendo Windows/Linux, B1/F1 e as regiões eastus2/brazilsouth, mas todas retornaram o mesmo erro 401.

O Terraform conseguiu validar a configuração normalmente durante o plan, mas o apply ficou bloqueado pela limitação da subscription.

Mesmo com essas limitações, os objetivos dos labs foram alcançados: o assessment foi realizado com sizing e estimativa de custos, a WEB01 foi migrada para o Azure e continuou servindo a mesma aplicação, e a comparação entre Rehost e Refactor foi feita utilizando infraestrutura e código reais.

Ciclo de vida dos recursos

Os recursos utilizados no Lab 11 foram criados, testados e, depois da coleta das evidências, removidos utilizando:

terraform destroy

O código permanece no repositório e permite recriar a infraestrutura novamente quando necessário.

Essa decisão foi intencional. Como este é um ambiente de laboratório, não faz sentido manter recursos cobrando enquanto não estão sendo utilizados.

Em uma migração real, porém, a lógica é diferente: depois do cutover, o objetivo é desligar a infraestrutura de origem e manter o ambiente que foi migrado ou modernizado no Azure.

Custos

Os labs de migração utilizam recursos do Azure que podem gerar cobrança por hora.

Por isso, cada laboratório indica quando os recursos podem ser removidos e quais componentes continuam gerando custo mesmo depois que uma VM é desligada. Um exemplo disso são discos e determinados IPs públicos.

A regra que sigo neste repositório é simples:

Primeiro coleto as evidências, depois destruo os recursos.

Assim, consigo manter o laboratório reproduzível sem deixar recursos desnecessários gerando custos.
