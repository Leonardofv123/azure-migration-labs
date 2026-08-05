# Lab 03 - DHCP + File Server

## Objetivo

Adicionar distribuicao automatica de IP (DHCP) e um servidor de arquivos com
pastas de rede isoladas por departamento. Cenario: os funcionarios da
Contoso precisam pegar IP automaticamente e ter pastas (`\\FS01\Vendas`,
`\\FS01\Financeiro`) onde so o setor certo tem acesso.

## Topologia

```
                    Rede do laboratorio: 192.168.10.0/24

   [ DC01 ]                          [ FS01 ]
   192.168.10.10                     192.168.10.20
   AD DS + DNS                       DHCP + File Server
                                      Escopo: .100-.200
      |                                  |
      +----------------------------------+
                       |
            [ vSwitch "Lab-Internal" ]
                       |
            [ Host = 192.168.10.1 = GATEWAY ]
                       |
            [ NAT "Lab-NAT" ]
                       |
                   Internet

   E:\Shares\ (na FS01)
        |-- Vendas      -> GG_Vendas (Modify)
        |-- Financeiro  -> GG_Financeiro (Modify)
        \-- TI          -> GG_TI (Modify)
   (Domain Admins e SYSTEM: Full Control em todas)
```

## Pre-requisitos

- Labs 01 e 02 concluidos (DC01 funcional, grupos GG_* do Lab 02 existentes).
- Host com RAM suficiente para DC01 + FS01 ligadas ao mesmo tempo (4 GB cada).

## Como rodar

1. `00-criar-vm-fs01.ps1` (no HOST): cria a VM com 2 discos (sistema + dados).
2. Instalar o Windows Server pela interface grafica (mesma rotina do Lab 01).
3. `01a-rename-ip.ps1` (DENTRO da FS01): renomeia, IP fixo, DNS apontando
   para o DC01. Reiniciar ao final.
4. `01b-ingressar-dominio.ps1` (DENTRO da FS01, apos reboot): ingressa no
   dominio contoso.local. A VM reinicia de novo.
5. `02-dhcp.ps1` (DENTRO da FS01, logado como CONTOSO\Administrator):
   instala e autoriza o DHCP, cria o escopo.
6. `03-fileserver.ps1` (DENTRO da FS01): prepara o disco de dados, cria as
   3 pastas, aplica permissoes NTFS + SMB por departamento.

## Validacao

```powershell
# Confirma o ingresso no dominio
Get-ComputerInfo | Select-Object CsName, CsDomain, CsDomainRole

# Confirma o DHCP
Get-DhcpServerInDC
Get-DhcpServerv4Scope

# Confirma os shares e permissoes
Get-SmbShare
icacls "E:\Shares\Vendas"
```

Teste de ponta a ponta: acessar `\\FS01\Vendas` a partir de outra maquina do
dominio, logado como um usuario do grupo certo (deve abrir) e como um
usuario de outro setor (deve negar acesso).

## Observacoes e boas praticas

- O DNS de qualquer maquina que vai ingressar no dominio deve apontar para o
  DC, nunca para si mesma - senao ela nao consegue "achar" o dominio.
- A conta de admin do dominio e `CONTOSO\Administrator`. Ao logar numa
  maquina recem-ingressada, a tela de login pode sugerir a conta LOCAL por
  padrao - digitar o dominio explicitamente evita essa confusao.
- Comandos longos com continuacao de linha (crase `) podem quebrar ao colar
  em bloco no PowerShell. Quando isso acontecer, rodar em uma unica linha.
- Duas politicas de logon sao independentes: "Allow log on locally" e
  "Allow log on through Remote Desktop Services". Liberar uma nao libera a
  outra - e o Hyper-V Connect e tratado como sessao remota para esse fim.

## Conceitos cobertos

Domain Join, DHCP, autorizacao de DHCP no AD, NTFS vs SMB, modelo AGDLP
(simplificado), inicializacao e formatacao de disco, icacls.
