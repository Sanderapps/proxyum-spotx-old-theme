# Proxyum SpotX Old Theme Installer

Instalador próprio do **Proxyum** para aplicar o perfil Old theme do SpotX ao Spotify Desktop no Windows.

O projeto instala o Spotify `1.2.13.661.ga588f749`, aplica o tema antigo e bloqueia atualizações automáticas — a combinação indicada pelo SpotX para preservar a interface antiga.

## Como usar

1. Baixe o projeto pelo botão **Code → Download ZIP**.
2. Extraia o ZIP.
3. Execute `Install.cmd`.
4. Confirme o aviso do Windows somente se o arquivo veio deste repositório.

Também é possível executar diretamente no PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Install-ProxyumSpotX.ps1
```

## Opções

```powershell
# Ocultar podcasts, episódios e audiolivros da página inicial
.\Install-ProxyumSpotX.ps1 -HidePodcasts

# Abrir o Spotify ao terminar
.\Install-ProxyumSpotX.ps1 -StartSpotify

# Validar download, hash e argumentos sem modificar o Spotify
.\Install-ProxyumSpotX.ps1 -DryRun

# Permitir que o instalador upstream ofereça exclusões no Defender
.\Install-ProxyumSpotX.ps1 -AllowDefenderExclusions
```

Por padrão, podcasts são preservados e as exclusões do Microsoft Defender são desativadas.

## Controles de integridade

- O instalador SpotX está fixado no commit `2a179d3cf0d207cc7a8b4401eaea88b3c290a30e`.
- O arquivo baixado precisa corresponder ao SHA-256 `BCF113D289C8AAF5990887D36AF5D6AE7E1D8FA183A68A819D5892CB99B84AB8`.
- O script é executado como arquivo temporário, sem `Invoke-Expression` sobre a resposta da rede.
- Arquivos temporários são removidos no final.
- Exclusões no Microsoft Defender ficam desativadas por padrão.

O SpotX ainda pode baixar componentes secundários dos serviços upstream durante a instalação. Fixar e validar o script principal reduz o risco, mas não elimina a necessidade de confiar no projeto externo.

## Avisos

- Esta versão do Spotify é de 2023 e não recebe as correções de segurança das versões atuais.
- O patch altera arquivos assinados do Spotify; a assinatura do executável modificado deixa de ser válida.
- Este projeto não é afiliado, patrocinado ou aprovado pelo Spotify.
- Use por sua conta e risco e respeite os termos aplicáveis ao serviço.

## Autoria

Projeto e instalador mantidos por **Proxyum**.

O SpotX é utilizado como dependência externa. Consulte [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) para os avisos técnicos e de licença.

## Licença

O código original deste instalador é disponibilizado sob a licença MIT. Consulte [LICENSE](LICENSE).

