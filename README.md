# Proxyum SpotX Old Theme

Instalador do Proxyum para usar o tema antigo do Spotify com SpotX.

## Instalador

Abra o Windows PowerShell e cole:

```powershell
$u='https://github.com/Sanderapps/proxyum-spotx-old-theme/releases/download/v1.1.0/Install-ProxyumSpotX.ps1'; $p=Join-Path $env:TEMP 'Install-ProxyumSpotX.ps1'; curl.exe -L --fail --retry 3 $u -o $p; if ($LASTEXITCODE -ne 0) { throw 'Falha ao baixar o instalador.' }; powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $p
```

O instalador pergunta o que fazer com podcasts, episódios e audiolivros. No final, também pergunta se você quer abrir o Spotify.

## Recomendações

- Feche o Spotify antes de começar.
- Leia as perguntas mostradas durante a instalação.
- Se já tiver um Spotify mais novo, confirme o downgrade somente se quiser usar o tema antigo.
- Não feche a janela enquanto a barra estiver em andamento.

## Avisos

- Usa o Spotify `1.2.13.661`, de 2023, porque versões novas não possuem o tema antigo.
- O SpotX altera arquivos do Spotify e bloqueia atualizações.
- Exclusões no Microsoft Defender ficam desativadas por padrão.
- Projeto sem vínculo com o Spotify. Use por sua conta e risco.
- O instalador usa o [SpotX](https://github.com/SpotX-Official/SpotX) como dependência externa.

## Autoria

Feito e mantido por **Proxyum**.
