<#
    Testes de higiene do repositorio.

    Nao testam infraestrutura Azure: isso exigiria credenciais e custo.
    Testam o que da para verificar de graca e em segundos, e que quebra
    com mais frequencia do que se imagina.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot

    $script:PowerShellScripts = Get-ChildItem -Path $script:RepoRoot `
        -Filter '*.ps1' -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\tests\\' }

    $script:TerraformFiles = Get-ChildItem -Path $script:RepoRoot `
        -Filter '*.tf' -Recurse -File

    $script:LabFolders = Get-ChildItem -Path $script:RepoRoot -Directory -Recurse |
        Where-Object { $_.Name -match '^lab-\d{2}-' }

    # Os labs do Grupo 1 foram escritos antes da convencao de documentar
    # desafios existir. Mantidos fora do teste em vez de receber secao inventada.
    $script:LabsSemDesafios = @('lab-01-hyperv', 'lab-02-active-directory', 'lab-03-dhcp-fileserver', 'lab-04-iis')
}

Describe 'Sintaxe dos scripts PowerShell' {

    It 'todos os .ps1 fazem parse sem erro' {
        $comErro = @()

        foreach ($script in $script:PowerShellScripts) {
            $erros = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$erros
            )

            if ($erros.Count -gt 0) {
                $comErro += "$($script.Name): $($erros[0].Message)"
            }
        }

        $comErro | Should -BeNullOrEmpty
    }
}

Describe 'Segredos versionados' {

    It 'nenhum script PowerShell tem senha em texto puro' {
        $suspeitos = @()

        $padroes = @(
            '\$password\s*=\s*["''][^"'']{6,}["'']'
            '\$senha\s*=\s*["''][^"'']{6,}["'']'
            '-Password\s+["''][^"'']{6,}["'']'
        )

        foreach ($script in $script:PowerShellScripts) {
            $conteudo = Get-Content $script.FullName -Raw

            foreach ($padrao in $padroes) {
                if ($conteudo -match $padrao) {
                    $suspeitos += "$($script.Name): $($Matches[0])"
                }
            }
        }

        $suspeitos | Should -BeNullOrEmpty
    }

    It 'nenhum arquivo Terraform tem valor default para senha' {
        $suspeitos = @()

        foreach ($arquivo in $script:TerraformFiles) {
            $conteudo = Get-Content $arquivo.FullName -Raw

            if ($conteudo -match '(?s)variable\s+"[^"]*password[^"]*"\s*\{[^}]*default\s*=') {
                $suspeitos += $arquivo.Name
            }
        }

        $suspeitos | Should -BeNullOrEmpty
    }
}

Describe 'Estrutura dos labs' {

    It 'todo lab tem README.md' {
        $semReadme = $script:LabFolders |
            Where-Object { -not (Test-Path (Join-Path $_.FullName 'README.md')) } |
            Select-Object -ExpandProperty Name

        $semReadme | Should -BeNullOrEmpty
    }

    It 'todo README de lab tem secao de desafios ou aprendizados' {
        $semSecao = @()
        # Os labs do Grupo 1 foram escritos antes desta convencao existir.
        # Mantidos fora do teste em vez de receber secao inventada.
        $excecoes = @('lab-01-hyperv', 'lab-02-active-directory',
                      'lab-03-dhcp-fileserver', 'lab-04-iis')


        foreach ($lab in ($script:LabFolders | Where-Object { $_.Name -notin $excecoes })) {
            $readme = Join-Path $lab.FullName 'README.md'

            if (Test-Path $readme) {
                $conteudo = Get-Content $readme -Raw

                if ($conteudo -notmatch '(?i)##\s*(Desafios|Aprendizados)') {
                    $semSecao += $lab.Name
                }
            }
        }

        $semSecao | Should -BeNullOrEmpty
    }

    It 'nenhum README de lab usa travessao' {
        $comTravessao = @()

        foreach ($lab in ($script:LabFolders | Where-Object { $_.Name -notin $excecoes })) {
            $readme = Join-Path $lab.FullName 'README.md'

            if (Test-Path $readme) {
                $conteudo = Get-Content $readme -Raw

                if ($conteudo -match '[\u2013\u2014]') {
                    $comTravessao += $lab.Name
                }
            }
        }

        $comTravessao | Should -BeNullOrEmpty
    }
}

Describe 'Terraform' {

    It 'todo arquivo .tf tem chaves balanceadas' {
        $desbalanceados = @()

        foreach ($arquivo in $script:TerraformFiles) {
            $conteudo = Get-Content $arquivo.FullName -Raw

            $abre  = ([regex]::Matches($conteudo, '\{')).Count
            $fecha = ([regex]::Matches($conteudo, '\}')).Count

            if ($abre -ne $fecha) {
                $desbalanceados += "$($arquivo.Name): $abre abre, $fecha fecha"
            }
        }

        $desbalanceados | Should -BeNullOrEmpty
    }

    It 'toda pasta terraform tem main.tf' {
        $pastasTerraform = Get-ChildItem -Path $script:RepoRoot -Directory -Recurse |
            Where-Object { $_.Name -eq 'terraform' }

        $semMain = $pastasTerraform |
            Where-Object { -not (Test-Path (Join-Path $_.FullName 'main.tf')) } |
            Select-Object -ExpandProperty FullName

        $semMain | Should -BeNullOrEmpty
    }
}

Describe 'Arquivos versionados que nao deveriam estar' {

    <#
        Estes testes verificam o que o Git RASTREIA, nao o que existe
        no disco. Arquivos ignorados pelo .gitignore podem e devem
        existir localmente.
    #>

    BeforeAll {
        $script:ArquivosVersionados = git ls-files
    }

    It 'nenhum terraform.tfstate versionado' {
        $states = $script:ArquivosVersionados | Where-Object { $_ -match '\.tfstate' }
        $states | Should -BeNullOrEmpty
    }

    It 'nenhum disco virtual versionado' {
        $discos = $script:ArquivosVersionados | Where-Object { $_ -match '\.(vhd|vhdx|iso)$' }
        $discos | Should -BeNullOrEmpty
    }

    It 'nenhuma pasta .terraform versionada' {
        $cache = $script:ArquivosVersionados | Where-Object { $_ -match '\.terraform/' }
        $cache | Should -BeNullOrEmpty
    }
}


