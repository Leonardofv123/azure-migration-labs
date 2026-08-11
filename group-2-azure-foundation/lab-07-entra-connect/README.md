# Lab 07 - Microsoft Entra ID + Entra Connect (Identidade Hibrida)

## Objetivo

Configurar identidade hibrida entre o Active Directory on-premises (`contoso.local`, na DC01) e o Microsoft Entra ID, usando Entra Connect Sync com Password Hash Synchronization. Na pratica: fazer com que os 8 usuarios que existem no AD local passem a existir tambem na nuvem, com a mesma senha, sem que ninguem precise decorar uma segunda credencial.

O lab levou muito mais tempo do que a configuracao em si exigiria. A maior parte do esforco foi consumida por um erro de transporte HTTP que so foi isolado ao trocar a rede de saida. A historia completa esta em [Desafios encontrados](#desafios-encontrados), e e a parte mais interessante deste lab.

## Estrutura criada

```
    ON-PREMISES (Hyper-V)                    MICROSOFT ENTRA ID

    contoso-dc01                             Tenant:
    AD DS + DNS                              <tenant>.onmicrosoft.com
    192.168.10.10
         |                                          ^
         |   Entra Connect Sync                     |
         |   Password Hash Sync                     |
         +------------------------------------------+
              sincronizacao periodica
              (delta a cada 30 min, ou
               forcada via PowerShell)

    Usuarios sincronizados (8):
      Ana Souza          Bruno Lima
      Carla Mendes       Diego Rocha
      Elaine Castro      Felipe Alves
      Gabriela Nunes     Henrique Dias

    Conta de servico:
      aadconnect-admin@<tenant>.onmicrosoft.com
      (cloud-only, papel: Hybrid Identity Administrator)
```

## Pre-requisitos

- Labs 01 e 02 concluidos (DC01 com AD DS e os 8 usuarios).
- Tenant do Microsoft Entra ID ativo.
- Entra Connect 2.6.3.0 ou superior, baixado pelo portal. A Microsoft nao distribui mais por link direto.
- Conta cloud-only com papel Hybrid Identity Administrator (ver conceitos).

## Conceitos

**Entra Connect Sync** sincroniza objetos e, opcionalmente, hashes de senha entre o AD on-premises e o Entra ID. Roda instalado num servidor da rede local, neste lab na propria DC01.

**Password Hash Synchronization (PHS)** sincroniza um hash do hash da senha do AD para o Entra ID. A vantagem sobre as alternativas: o login na nuvem funciona mesmo se a infraestrutura on-premises estiver fora do ar, diferente de Pass-through Authentication ou Federation.

**Conta cloud-only e conta MSA.** Este ponto virou um problema real no lab. Contas pessoais Microsoft (`@outlook.com`, identity provider `live.com`) nao sao aceitas por todos os componentes do Entra Connect, mesmo quando essa conta e Global Admin do tenant. A pratica recomendada, e aqui obrigatoria, e usar uma conta nativa do tenant (`usuario@tenant.onmicrosoft.com`) para automacao.

**UPN suffix nao verificado.** Dominios `.local` nao sao roteaveis na internet e nao podem ser verificados como dominio publico no Entra ID. O wizard permite continuar marcando "Continue without matching all UPN suffixes to verified domains", e os usuarios acabam logando pelo sufixo `.onmicrosoft.com`.

**Endpoint estimateAccess.** Chamada interna que o wizard faz para checar permissoes antes de prosseguir. Nao e documentada oficialmente e tem instabilidade conhecida. O detalhe que importa: por ser um POST com payload maior, e sensivel a problemas de rede que nao afetam chamadas GET simples. Foi exatamente ai que este lab travou.

## Como rodar

1. `01-sanity-check-ad.ps1` confirma que nao ha contas com UPN conflitante antes de comecar.

2. **Criar a conta de servico cloud-only.** Tecnicamente vem depois no wizard, mas fazer antes economiza retrabalho. Em `entra.microsoft.com` > Entra ID > Users > New user, com UPN `aadconnect-admin@<tenant>.onmicrosoft.com` e papel Hybrid Identity Administrator.

3. **Baixar o instalador** em `entra.microsoft.com` > Identity > Hybrid management > Microsoft Entra Connect > Connect Sync > Manage > Download.

4. **Rodar o wizard** com Customize e Password Hash Synchronization, autenticando com a conta do passo 2.

5. **Conectar ao diretorio on-premises.** Na tela Connect Directories, adicionar o forest `contoso.local`. Usar o formato UPN completo (`Administrator@contoso.local`), porque o NetBIOS curto (`CONTOSO\Administrator`) retorna erro de dominio nao encontrado.

6. **Sign-in configuration.** O `contoso.local` aparece como Not Added, o que e esperado. Marcar "Continue without matching all UPN suffixes".

7. **Demais telas:** Sync all domains and OUs, Synchronize all users and devices, Password hash synchronization ja marcado.

8. `05-teste-password-hash-sync.ps1` reseta a senha de um usuario no AD, forca o ciclo delta e instrui a validacao com login real.

## Validacao

Confirmar que os usuarios apareceram nao e suficiente, porque isso so prova que os objetos sincronizaram. O teste real e autenticar.

```powershell
# Resetar senha no AD on-premises
Set-ADAccountPassword -Identity "ana.souza" -Reset `
    -NewPassword (ConvertTo-SecureString "<SENHA>" -AsPlainText -Force)
Set-ADUser -Identity "ana.souza" -ChangePasswordAtLogon $false

# Forcar sincronizacao em vez de esperar 30 minutos
Start-ADSyncSyncCycle -PolicyType Delta
```

Depois, login em `myaccount.microsoft.com` com `ana.souza@<tenant>.onmicrosoft.com` e a nova senha. Login bem-sucedido confirma o hash sincronizando de ponta a ponta.

## Desafios encontrados

Dois problemas distintos. O primeiro foi de identidade e resolveu rapido. O segundo consumiu duas noites e so cedeu quando a rede de saida foi trocada.

### 1. AADSTS50020, conta pessoal recusada pelo tenant

```
AADSTS50020: User account '<conta>@outlook.com' from identity provider
'live.com' does not exist in tenant 'Microsoft Services'
```

A conta era Global Admin do tenant. Funcionava no portal, funcionava no Az CLI. So o wizard recusava.

Uma credencial cacheada tambem estava contribuindo, encontrada e removida com `cmdkey /list` e `cmdkey /delete`.

**Causa:** contas MSA nao sao aceitas por todos os componentes do Entra Connect, independente do papel atribuido. O componente espera uma identidade nativa do tenant.

> **O que ficou:** ferramenta de sincronizacao pede conta de servico nativa do tenant. Isso nao e so contorno de erro, e a pratica correta tambem em producao, por separacao de responsabilidades.

### 2. HttpRequestException no estimateAccess, o problema longo

```
HttpRequestException: An error occurred while sending the request.
---> System.Net.WebException: The underlying connection was closed
---> System.Net.Sockets.SocketException: An existing connection was
     forcibly closed by the remote host
```

O log em `C:\ProgramData\AADConnect\trace-*.log` apontou a chamada exata:

```
POST https://graph.microsoft.com/beta/roleManagement/directory/estimateAccess
```

O padrao observado, que orientou toda a investigacao:

- Login e aquisicao de token funcionavam sempre, sem falha
- Gap de cerca de 19 segundos entre obter o token e o erro aparecer
- 100% reproduzivel, sempre no mesmo ponto exato
- Persistiu entre sessoes, testado em duas noites diferentes

O ultimo ponto foi importante, porque descartou instabilidade transitoria do lado da Microsoft. Era algo do ambiente.

Hipoteses testadas e eliminadas, em ordem cronologica:

| # | Hipotese | Teste | Resultado |
|---|---|---|---|
| 1 | Identidade MSA | Conta cloud-only | Resolveu o AADSTS50020, nao este erro |
| 2 | TLS 1.2 desatualizado | `SchUseStrongCrypto` | Aplicado, sem efeito |
| 3 | DNS e proxy | `Get-DnsServerForwarder`, `netsh winhttp` | Normais, sem proxy |
| 4 | Conectividade TCP | `Test-NetConnection -Port 443` | `True` nos dois endpoints |
| 5 | Chamada HTTPS real | `Invoke-WebRequest` | Status 200, resposta de 51 KB |
| 6 | RAM do host | `Get-CimInstance` | Baixa, mas nao isolada como causa |
| 7 | Versao do Entra Connect | Verificacao de versao | 2.6.3.0, acima do minimo |
| 8 | MTU quebrada | `ping -f -l`, ajuste para 1400 | Inconclusivo |

O item 5 e o mais revelador em retrospecto: chamadas GET passavam perfeitamente, com resposta de 51 KB. Isso ja sugeria que o problema nao era conectividade generica, mas algo especifico do tipo de requisicao.

**Erro evitado no caminho.** Durante os testes de MTU, o vSwitch da DC01 foi trocado temporariamente de `Lab-Internal` para `Default Switch`. Isso quebrou a resolucao de DNS da VM na hora, porque o IP estatico dela estava configurado especificamente para a rede Lab-Internal. Revertido imediatamente.

> Nao trocar adaptador de rede de um Domain Controller com IP estatico como teste exploratorio. Se for necessario, fazer numa VM descartavel.

**Causa raiz.** O mesmo procedimento, executado com dados moveis em vez do Wi-Fi de casa, funcionou imediatamente. Nenhuma outra alteracao.

Isso isola a causa: alguma caracteristica da rede domestica ou do provedor interferindo em chamadas POST com payload maior. Pode ser inspecao de pacote, politica de QoS, ou comportamento do roteador. Nao da para determinar com precisao de fora.

O que importa e o padrao: conectividade TCP normal, GET normal, POST maior quebrando. Nenhum checklist padrao de DNS, TLS ou firewall pega isso.

> **O que ficou:**
> - Quando todos os testes de rede passam mas uma chamada especifica falha de forma reproduzivel, a variavel a trocar e a propria rede, nao mais configuracao dentro da maquina.
> - Testes de conectividade generica (ping, TCP, GET) nao cobrem POST com payload maior. Sao camadas diferentes de comportamento.
> - Ler o log da ferramenta para descobrir qual chamada exata falha vale mais que dez tentativas de reconfiguracao no escuro.

## Aprendizados

**Identidade**

- Conta MSA pessoal nao serve para ferramentas de sincronizacao, mesmo sendo Global Admin.
- Credenciais cacheadas do Windows (`cmdkey`) podem interferir na autenticacao.
- Formato UPN completo funciona onde o NetBIOS curto falha, em varias ferramentas Microsoft.

**Diagnostico**

- Ler o log da ferramenta para identificar a chamada exata e o atalho mais eficiente.
- Teste de conectividade generica nao cobre todos os tipos de requisicao.
- Erro reproduzivel entre sessoes e dias diferentes indica problema de ambiente, nao instabilidade do servico remoto.
- Quando tudo dentro da maquina foi testado, a variavel seguinte e a rede.

**Validacao**

- "O wizard terminou sem erro" nao e validacao. Confirmar que os objetos sincronizaram e que a autenticacao real funciona.

## Avisos nao-bloqueantes

Apareceram durante a instalacao e nao impedem o funcionamento:

- AD Recycle Bin nao habilitado (boas praticas)
- TPM nao detectado (recomendacao de seguranca)
- Source anchor usando `mS-DS-ConsistencyGuid`
- Falha ao instalar o Entra Connect Health Agent (afeta so telemetria)

## Estrutura de arquivos

```
lab-07-entra-connect/
├── README.md
├── scripts/
│   ├── 01-sanity-check-ad.ps1
│   ├── 02-limpar-credenciais.ps1
│   ├── 03-diagnostico-rede.ps1
│   ├── 04-forcar-sync.ps1
│   └── 05-teste-password-hash-sync.ps1
└── screenshots/
```

**Proximo:** [Lab 08 - VPN Site-to-Site](../lab-08-vpn-site-to-site/), conectando a rede on-premises a VNet do Azure via tunel IPsec.
