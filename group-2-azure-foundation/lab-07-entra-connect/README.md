# Lab 07 - Microsoft Entra ID + Entra Connect (Identidade Híbrida)

## Objetivo

Configurar identidade híbrida entre o Active Directory on-premises (`contoso.local`, na DC01) e o Microsoft Entra ID, usando Entra Connect Sync com Password Hash Synchronization. Na prática: fazer com que os 8 usuários que existem no AD local passem a existir também na nuvem, com a mesma senha, sem que ninguém precise decorar uma segunda credencial.

O lab levou muito mais tempo do que a configuração em si exigiria. A maior parte do esforço foi consumida por um erro de transporte HTTP que só foi isolado ao trocar a rede de saída — a história completa está em [Desafios encontrados](#desafios-encontrados), e é a parte mais interessante deste lab.

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
              sincronização periódica
              (delta a cada 30 min, ou
               forçada via PowerShell)

    Usuários sincronizados (8):
      Ana Souza          Bruno Lima
      Carla Mendes       Diego Rocha
      Elaine Castro      Felipe Alves
      Gabriela Nunes     Henrique Dias

    Conta de serviço:
      aadconnect-admin@<tenant>.onmicrosoft.com
      (cloud-only, papel: Hybrid Identity Administrator)
```

## Pré-requisitos

- Labs 01 e 02 concluídos (DC01 com AD DS e os 8 usuários).
- Tenant do Microsoft Entra ID ativo.
- Entra Connect 2.6.3.0 ou superior — baixado pelo portal, a Microsoft não distribui mais por link direto.
- Conta cloud-only com papel **Hybrid Identity Administrator** (ver conceitos).

## Conceitos

**Entra Connect Sync** sincroniza objetos e, opcionalmente, hashes de senha entre o AD on-premises e o Entra ID. Roda instalado num servidor da rede local — neste lab, na própria DC01.

**Password Hash Synchronization (PHS)** sincroniza um hash do hash da senha do AD para o Entra ID. A vantagem sobre as alternativas: o login na nuvem funciona mesmo se a infraestrutura on-premises estiver fora do ar, diferente de Pass-through Authentication ou Federation.

**Conta cloud-only vs conta MSA.** Este ponto virou um problema real no lab. Contas pessoais Microsoft (`@outlook.com`, identity provider `live.com`) não são aceitas por todos os componentes do Entra Connect — mesmo quando essa conta é Global Admin do tenant. A prática recomendada, e aqui obrigatória, é usar uma conta nativa do tenant (`usuario@tenant.onmicrosoft.com`) para automação.

**UPN suffix não verificado.** Domínios `.local` não são roteáveis na internet e não podem ser verificados como domínio público no Entra ID. O wizard permite continuar marcando *"Continue without matching all UPN suffixes to verified domains"* — os usuários acabam logando pelo sufixo `.onmicrosoft.com`.

**Endpoint estimateAccess.** Chamada interna que o wizard faz para checar permissões antes de prosseguir. Não é documentada oficialmente e tem instabilidade conhecida. O detalhe que importa: por ser um POST com payload maior, é sensível a problemas de rede que não afetam chamadas GET simples. Foi exatamente aí que este lab travou.

## Como rodar

1. `01-sanity-check-ad.ps1` — confirma que não há contas com UPN conflitante antes de começar.

2. **Criar a conta de serviço cloud-only.** Tecnicamente vem depois no wizard, mas fazer antes economiza retrabalho. Em `entra.microsoft.com` → Entra ID → Users → New user, com UPN `aadconnect-admin@<tenant>.onmicrosoft.com` e papel **Hybrid Identity Administrator**.

3. **Baixar o instalador** em `entra.microsoft.com` → Identity → Hybrid management → Microsoft Entra Connect → Connect Sync → Manage → Download.

4. **Rodar o wizard** com `Customize` → `Password Hash Synchronization`, autenticando com a conta do passo 2.

5. **Conectar ao diretório on-premises.** Na tela *Connect Directories*, adicionar o forest `contoso.local`. Usar o formato UPN completo (`Administrator@contoso.local`) — o NetBIOS curto (`CONTOSO\Administrator`) retorna erro de domínio não encontrado.

6. **Sign-in configuration.** `contoso.local` aparece como *Not Added* — esperado. Marcar *Continue without matching all UPN suffixes*.

7. **Demais telas:** Sync all domains and OUs, Synchronize all users and devices, Password hash synchronization já marcado.

8. `05-teste-password-hash-sync.ps1` — reseta a senha de um usuário no AD, força o ciclo delta e valida com login real.

## Validação

Confirmar que os usuários apareceram **não é suficiente** — isso só prova que os objetos sincronizaram. O teste real é autenticar.

```powershell
# Resetar senha no AD on-premises
Set-ADAccountPassword -Identity "ana.souza" -Reset `
    -NewPassword (ConvertTo-SecureString "<SENHA>" -AsPlainText -Force)
Set-ADUser -Identity "ana.souza" -ChangePasswordAtLogon $false

# Forçar sincronização em vez de esperar 30 minutos
Start-ADSyncSyncCycle -PolicyType Delta
```

Depois, login em `myaccount.microsoft.com` com `ana.souza@<tenant>.onmicrosoft.com` e a nova senha. Login bem-sucedido confirma o hash sincronizando de ponta a ponta.

## Desafios encontrados

Dois problemas distintos. O primeiro foi de identidade e resolveu rápido. O segundo consumiu duas noites e só cedeu quando a rede de saída foi trocada.

### 1. AADSTS50020 — conta pessoal recusada pelo tenant

```
AADSTS50020: User account '<conta>@outlook.com' from identity provider
'live.com' does not exist in tenant 'Microsoft Services'
```

A conta era Global Admin do tenant. Funcionava no portal, funcionava no Az CLI. Só o wizard recusava.

Uma credencial cacheada também estava contribuindo, encontrada e removida com `cmdkey /list` e `cmdkey /delete`.

**Causa:** contas MSA não são aceitas por todos os componentes do Entra Connect, independente do papel atribuído. O componente espera uma identidade nativa do tenant.

> **O que ficou:** ferramenta de sincronização pede conta de serviço nativa do tenant. Isso não é só contorno de erro — é a prática correta também em produção, por separação de responsabilidades.

### 2. HttpRequestException no estimateAccess — o problema longo

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

**O padrão observado**, que orientou toda a investigação:

- Login e aquisição de token funcionavam **sempre**, sem falha
- Gap de ~19 segundos entre obter o token e o erro aparecer
- 100% reproduzível, sempre no mesmo ponto exato
- Persistiu entre sessões, testado em duas noites diferentes

O último ponto foi importante — descartou instabilidade transitória do lado da Microsoft. Era algo do ambiente.

**Hipóteses testadas e eliminadas**, em ordem cronológica:

| # | Hipótese | Teste | Resultado |
|---|---|---|---|
| 1 | Identidade MSA | Conta cloud-only | Resolveu o AADSTS50020, não este erro |
| 2 | TLS 1.2 desatualizado | `SchUseStrongCrypto` | Aplicado, sem efeito |
| 3 | DNS e proxy | `Get-DnsServerForwarder`, `netsh winhttp` | Normais, sem proxy |
| 4 | Conectividade TCP | `Test-NetConnection -Port 443` | `True` nos dois endpoints |
| 5 | Chamada HTTPS real | `Invoke-WebRequest` | Status 200, resposta de 51 KB |
| 6 | RAM do host | `Get-CimInstance` | Baixa, mas não isolada como causa |
| 7 | Versão do Entra Connect | Verificação de versão | 2.6.3.0, acima do mínimo |
| 8 | MTU quebrada | `ping -f -l`, ajuste para 1400 | Inconclusivo |

O item 5 é o mais revelador em retrospecto: chamadas GET passavam perfeitamente, com resposta de 51 KB. Isso já sugeria que o problema não era conectividade genérica, mas algo específico do tipo de requisição.

**Erro evitado no caminho.** Durante os testes de MTU, o vSwitch da DC01 foi trocado temporariamente de `Lab-Internal` para `Default Switch`. Isso quebrou a resolução de DNS da VM na hora — o IP estático dela estava configurado especificamente para a rede Lab-Internal. Revertido imediatamente.

> Não trocar adaptador de rede de um Domain Controller com IP estático como teste exploratório. Se for necessário, fazer numa VM descartável.

**Causa raiz.** O mesmo procedimento, executado com dados móveis em vez do Wi-Fi de casa, funcionou imediatamente. Nenhuma outra alteração.

Isso isola a causa: alguma característica da rede doméstica ou do provedor interferindo em chamadas POST com payload maior. Pode ser inspeção de pacote, política de QoS, ou comportamento do roteador — não dá para determinar com precisão de fora.

O que importa é o padrão: conectividade TCP normal, GET normal, POST maior quebrando. Nenhum checklist padrão de DNS/TLS/firewall pega isso.

> **O que ficou:**
> - Quando todos os testes de rede passam mas uma chamada específica falha de forma reproduzível, a variável a trocar é a própria rede — não mais configuração dentro da máquina.
> - Testes de conectividade genérica (ping, TCP, GET) não cobrem POST com payload maior. São camadas diferentes de comportamento.
> - Ler o log da ferramenta para descobrir **qual** chamada exata falha vale mais que dez tentativas de reconfiguração no escuro.

## Aprendizados

**Identidade**

- Conta MSA pessoal não serve para ferramentas de sincronização, mesmo sendo Global Admin.
- Credenciais cacheadas do Windows (`cmdkey`) podem interferir na autenticação.
- Formato UPN completo funciona onde o NetBIOS curto falha, em várias ferramentas Microsoft.

**Diagnóstico**

- Ler o log da ferramenta para identificar a chamada exata é o atalho mais eficiente.
- Teste de conectividade genérica não cobre todos os tipos de requisição.
- Erro reproduzível entre sessões e dias diferentes indica problema de ambiente, não instabilidade do serviço remoto.
- Quando tudo dentro da máquina foi testado, a variável seguinte é a rede.

**Validação**

- "O wizard terminou sem erro" não é validação. Confirmar que os objetos sincronizaram **e** que a autenticação real funciona.

## Avisos não-bloqueantes

Apareceram durante a instalação e não impedem o funcionamento:

- AD Recycle Bin não habilitado (boas práticas)
- TPM não detectado (recomendação de segurança)
- Source anchor usando `mS-DS-ConsistencyGuid`
- Falha ao instalar o Entra Connect Health Agent (afeta só telemetria)

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

---

**Próximo:** [Lab 08 - VPN Site-to-Site](../lab-08-vpn-site-to-site/) — conectando a rede on-premises à VNet do Azure via túnel IPsec.
