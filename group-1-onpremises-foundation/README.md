# Fase 1: Fundacao On-Premises Automatizada

> Grupo 1 da jornada de migracao Azure da Contoso do Brasil: simular, do
> zero, o datacenter legado que um projeto real de migracao herdaria -
> construido inteiramente via Infraestrutura como Codigo (PowerShell
> idempotente), sem cliques manuais soltos.

---

## Cenario de Negocio

Antes de migrar qualquer coisa para o Azure, alguem precisa entender de
verdade o que esta rodando on-premises. Essa e a parte pouco glamourosa de
uma migracao para nuvem que a maioria dos tutoriais ignora - e e exatamente
o que esta fase simula.

A Contoso do Brasil e uma empresa ficticia cuja infraestrutura inteira vive
em servidores fisicos numa sala de TI: um controlador de dominio, um
servidor de arquivos e um portal interno. Sem documentacao, sem automacao,
apenas o que foi configurado anos atras e nunca mais foi tocado. Esse e o
ambiente "As-Is" - o ponto de partida de praticamente qualquer projeto real
de migracao.

O Grupo 1 reconstroi esse ambiente do zero, no Hyper-V, usando somente
scripts PowerShell que podem ser executados novamente com seguranca
(idempotentes: rodar duas vezes nao quebra nem duplica nada). O objetivo nao
e so "fazer funcionar" - e ter uma base documentada e reproduzivel que as
proximas fases deste repositorio vao avaliar, migrar e modernizar para o
Azure.

Ao final desta fase, a Contoso tem:
- Uma floresta funcional do Active Directory com estrutura organizacional real
- Atribuicao automatica de IP e um servidor de arquivos segmentado por departamento
- Um portal web interno rodando com HTTPS

Tudo isso scriptado, validado e pronto para ser a foto do "antes" na
historia de migracao que continua no Grupo 2.

---

## Tecnologias Utilizadas

- **PowerShell 7** - todo recurso desta fase e criado, configurado e validado via script, nunca so por passos manuais na interface grafica.
- **Hyper-V** - o hypervisor on-premises que hospeda todas as VMs, com um vSwitch interno isolado + NAT (sem exposicao a rede domestica/corporativa).
- **Windows Server 2022** (Standard Evaluation, Desktop Experience) - o sistema operacional de cada VM desta fase.
- **Active Directory Domain Services (AD DS) + DNS** - a espinha dorsal de identidade e resolucao de nomes de todo o ambiente.
- **DHCP** - distribuicao automatica de IP, gateway e DNS, autorizado no AD.
- **File Server (NTFS + SMB)** - pastas compartilhadas isoladas por departamento, permissoes aplicadas em duas camadas.
- **IIS (Internet Information Services)** - portal web interno com application pool dedicado e certificado HTTPS autoassinado.

---

## Estrutura de Pastas

```
azure-migration-labs/
└── group-1-onpremises-foundation/
    ├── README.md                          <- este arquivo
    │
    ├── lab-01-hyperv/
    │   ├── README.md
    │   ├── scripts/
    │   │   ├── 01-estrutura-pastas.ps1
    │   │   ├── 02-vswitch-nat.ps1
    │   │   ├── 03-criar-vm.ps1
    │   │   └── 04-rename-ip.ps1
    │   └── screenshots/
    │
    ├── lab-02-active-directory/
    │   ├── README.md
    │   ├── usuarios-exemplo.csv
    │   ├── scripts/
    │   │   ├── 01-promover-dc.ps1
    │   │   ├── 02-criar-ous.ps1
    │   │   ├── 03-criar-usuarios-csv.ps1
    │   │   └── 04-validar.ps1
    │   └── screenshots/
    │
    ├── lab-03-dhcp-fileserver/
    │   ├── README.md
    │   ├── scripts/
    │   │   ├── 00-criar-vm-fs01.ps1
    │   │   ├── 01a-rename-ip.ps1
    │   │   ├── 01b-ingressar-dominio.ps1
    │   │   ├── 02-dhcp.ps1
    │   │   └── 03-fileserver.ps1
    │   └── screenshots/
    │
    └── lab-04-iis/
        ├── README.md
        ├── scripts/
        │   ├── 00-criar-vm-web01.ps1
        │   ├── 01a-rename-ip.ps1
        │   ├── 01b-ingressar-dominio.ps1
        │   ├── 02-instalar-iis.ps1
        │   ├── 03-publicar-site.ps1
        │   └── 04-https-dns.ps1
        └── screenshots/
```

---

## O Que Cada Lab Realmente Constroi

Esta nao e uma lista generica - e o que foi de fato scriptado, executado e
validado neste ambiente, passo a passo.

### Lab 01 - Fundacao Hyper-V
Provisionamento idempotente da primeira VM (`DC01`) no Hyper-V: estrutura
de pastas isolada no disco, vSwitch interno com NAT (`Lab-Internal`,
`192.168.10.0/24`) e a VM em si (4 GB RAM, 2 vCPU, Generation 2), pronta
para a instalacao do Windows Server.

### Lab 02 - Active Directory Domain Services e DNS
A `DC01` e promovida a Controlador de Dominio, criando a floresta
`contoso.local` com o DNS instalado junto. Cinco Unidades Organizacionais
sao criadas por departamento (TI, Vendas, Financeiro, Diretoria,
ServiceAccounts), e um lote de usuarios + grupos globais e provisionado
direto de um arquivo CSV - sem criacao manual de contas.

### Lab 03 - DHCP e Servidor de Arquivos
Uma segunda VM (`FS01`) ingressa no dominio e assume dois papeis: servidor
DHCP autorizado, distribuindo IPs automaticamente (`192.168.10.100` a
`200`), e servidor de arquivos com pastas compartilhadas isoladas por
departamento (`Vendas`, `Financeiro`, `TI`), cada uma protegida por
permissoes NTFS vinculadas aos grupos do AD criados no Lab 02 - mais o
compartilhamento SMB correspondente.

### Lab 04 - Servidor Web IIS
Uma terceira VM (`WEB01`) ingressa no dominio e hospeda um portal interno
(`intranet.contoso.local`) no IIS, rodando em seu proprio application pool
dedicado, servido tanto em HTTP quanto HTTPS (certificado autoassinado),
com o registro DNS criado remotamente na `DC01` via `Invoke-Command` - sem
precisar logar manualmente no controlador de dominio.

---

## Como Executar os Scripts (Padrao Geral)

Todos os labs desta fase seguem o mesmo padrao de execucao. Os scripts sao
numerados na ordem em que devem ser rodados, e cada um valida a si mesmo no
final - nao avance para o proximo script ate que a saida do anterior
confirme sucesso.

**1. Scripts que rodam no HOST (seu PC fisico)** - criam e configuram as
VMs do Hyper-V:

```powershell
# Sempre execute o PowerShell 7 como Administrador no host
cd .\lab-0X-nome\scripts\
.\01-estrutura-pastas.ps1
# Leia a saida antes de continuar - confirme as linhas verdes "criado",
# investigue qualquer erro vermelho antes de seguir
```

**2. Scripts que rodam DENTRO da VM** - configuram o sistema convidado
(rename, IP fixo, ingresso no dominio, roles e features). Abra a VM pelo
Hyper-V Manager → Conectar → Iniciar, faca login, depois abra o PowerShell
como Administrador dentro dessa sessao:

```powershell
# Dentro da janela do PowerShell da propria VM
.\01a-rename-ip.ps1
Restart-Computer -Force
# Apos reiniciar, faca login novamente e continue com o proximo script
```

**3. Valide antes de seguir.** Todo script termina com alguns comandos
`Get-*` que mostram o estado atual. Trate essa saida como um portao - se
ela nao corresponder ao que o cabecalho do script descreve, pare e
investigue antes de rodar o proximo.

```powershell
# Padrao de validacao usado em toda esta fase
Get-VM | Select-Object Name, State
Get-ADUser -Filter * | Select-Object Name
Get-Website | Format-Table -AutoSize
```

---

## Screenshots

Coloque os prints de validacao dentro da pasta `screenshots/` de cada lab.
Capturas sugeridas para a visao geral desta fase:

- [ ] Gerenciador do Hyper-V mostrando todas as VMs rodando (`DC01`, `FS01`, `WEB01`)
- [ ] Active Directory Users and Computers (`dsa.msc`) - arvore de OUs com usuarios
- [ ] DNS Manager mostrando a zona `contoso.local` e o registro `intranet`
- [ ] Console do DHCP mostrando o escopo ativo e a faixa de leases
- [ ] Explorador de Arquivos - aba Seguranca de uma das pastas de departamento
- [ ] Navegador mostrando `https://intranet.contoso.local` carregado com sucesso

*(Adicione seus proprios prints aqui conforme for capturando - esta secao e
um checklist de referencia, nao o conteudo final.)*

---

## Resumo

Esta primeira fase do repositorio simula, do zero, o "datacenter legado" de
uma empresa ficticia (Contoso do Brasil) inteiramente via PowerShell
idempotente - sem cliques manuais soltos, tudo scriptado e validavel. E o
ambiente "As-Is" que qualquer projeto real de migracao precisa entender
antes de mover qualquer coisa para a nuvem.

Os quatro laboratorios constroem, em sequencia: a primeira VM no Hyper-V com
rede isolada (Lab 01); uma floresta completa do Active Directory com
usuarios e grupos provisionados em massa via CSV (Lab 02); um servidor de
arquivos com DHCP autorizado e pastas isoladas por departamento via
permissoes NTFS + SMB (Lab 03); e um portal interno publicado no IIS com
HTTPS e DNS configurado remotamente entre servidores (Lab 04).

Ao final desta fase, a Contoso tem um ambiente on-premises funcional,
documentado e reproduzivel - a base sobre a qual a Fase 2 (presenca hibrida
e migracao para o Azure) vai trabalhar.
