# POP Flow — tudo o que foi implementado (21/10/2026)

Levantamento feito a partir do código, não só da documentação: `git log` de cada
fork contra o `upstream` do pop-os, `git status`/stash/branches, comparação
byte a byte (md5/`cmp`) dos binários instalados com os builds, `dpkg --verify`
nos pacotes do COSMIC, serviços systemd, `~/.config/cosmic` contra
`/usr/share/cosmic` e uma varredura do sistema atrás de ajustes soltos.

**Máquina:** Pop!_OS 24.04, COSMIC **1.9.0** (todos os pacotes).

**Status:**
- ✅ instalado e rodando;
- 🔧 commitado, falta instalar;
- 📋 só planejado.

**Placar.** São 9 componentes: 7 forks do COSMIC e 2 projetos próprios.
- **Commits próprios:** cerca de 125, sem contar os de hoje.
- **Trabalho fora de commit:** nenhum. Todas as árvores estão limpas e sem stash, e tudo foi enviado ao GitHub, inclusive a rodada de hoje.
- **Binários de fábrica substituídos:** 8 (`cosmic-files`, `cosmic-files-applet`, `cosmic-launcher`, `cosmic-term`, `cosmic-app-list`, `cosmic-comp`, `cosmic-workspaces`, `cosmic-settings`), cada um com uma cópia "golden" e um hook do APT que reaplica a versão do POP Flow depois de cada atualização. Todos conferidos com `cmp` contra o build em 21/10.
- **Binários próprios:** 6 em `/usr/local/bin` e 2 em `~/.local/bin`.

---

## 0. Rodada de hoje (21/10) — ✅ instalada e enviada ao GitHub

| O quê | Onde | Commit |
|---|---|---|
| Captura salva **e** copiada (Ctrl+V cola, inclusive no Claude Code). Notificação com botão "Mostrar na pasta" | `pop-flow-capture` (cosmic-applets) | `3bb4a994` |
| Print e o Ctrl+Shift+P passam a chamar a captura nova. O Ctrl+Shift+P estava quebrado: chamava o `gnome-screenshot`, que não está instalado | `setup-desktop.sh` | suíte `5f30ce3` |
| **Canto inferior esquerdo** também mostra a área de trabalho | serviço `cosmic-show-desktop-corner-left` | `3bb4a994` |
| Os dois cantos funcionam **com um item sendo arrastado** | `cosmic-show-desktop-corner` (wl_data_device) | `3bb4a994` |
| *Abrir no terminal* em arquivos, executáveis (abre a **raiz do repo**), `.desktop`, seleção múltipla, área de trabalho, Recentes/busca e **barra de caminho** (também no seletor Abrir/Salvar) | cosmic-files `src/terminal_dir.rs` | `dc84f4b` |
| **Seta ▾ para recolher** a pasta aberta na barra lateral. Enquanto há pasta aberta, *Ejetar* vai para o menu do drive | cosmic-files | `dc84f4b` |
| **Rolagem ao arrastar até a borda**: continua com o mouse parado e acelera; vale na lista, na grade e no desktop | cosmic-files | `dc84f4b` |
| *Abrir no terminal* no botão direito de apps do dock que têm repositório próprio | cosmic-app-list | `ffb3dcaf` |
| Executável no launcher abre o terminal na raiz do repo | cosmic-launcher | `88f29db` |
| *Nova aba na raiz do repositório* no botão direito do terminal | cosmic-term | `371dc68` |

**Testes novos:**
- `terminal_dir`: 8 no Files e 2 no dock;
- curva da rolagem: 1;
- launcher: 1.

Todas as suítes passam: Files 78, terminal 59, canto 19.

**Instalação completa (21/10, noite).** Tudo instalado e conferido byte a byte:
- Files, desktop, launcher, terminal, dock e os dois cantos (serviços ativos);
- `pop-flow-capture` ligado à tecla **Print** e ao Ctrl+Shift+P;
- compositor, overview e Configurações (seções 5–7), depois de trazer para cada fork o código exato do pacote 1.9.0 instalado.

⚠ O **compositor novo só vale a partir do próximo login**: a sessão atual ainda roda o antigo, já carregado na memória. Se o login não voltar: Ctrl+Alt+F3 → `cosmic-comp/uninstall.sh` (restaura `cosmic-comp.orig`).

---

## 1. Launcher / Alt+Tab — `cosmic-launcher` (NicoArgo/POP-Flow) ✅

- **Alt+Tab com miniaturas ao vivo**, em grade estilo Windows (screencopy + toplevel-info). Commits `47c936f`, `acfdd75`, `d299cfb`.
- **Botão X por miniatura**: fecha exatamente aquela janela via `Request::Quit(id)`. Commits `fe8c381`, `edb77b9`.
- **Miniatura 1:1** (janelas com o mesmo título não trocam de imagem) e **agrupamento por app**. Commit `edb77b9`.
- **Grade adaptativa sem scroll**: as miniaturas encolhem para caber na tela. Commit `c9c0d58`.
- **Posição fixa na grade**: cada janela mantém a sua célula. Commit `ded4ec4`.
- **Regras de tamanho**: mín. 120×70, máx. 264×156; acima disso pagina com "+N" e detecta escala 1,25. Commit `f862776`.
- **Peek**: a célula em foco cresce 1,2× em 120 ms, com sombra. Commit `f7adf38`.
- **Botão direito enriquecido**: *Abrir no terminal*, *Abrir pasta*, *Copiar caminho*. Entende URI `file://`, caminho literal e consulta + nome, com percent-decoding, e recusa `..`. Commits `6b1d04e`, `f371ddb`.
- **Correções:**
  - vazamento de shm de ~8 MiB por janela a cada abertura, que travava a máquina em ~24 h (`50b5b26`);
  - captura endurecida (`e8ff740`, `f51bd79`);
  - auto-reapply e uninstall (`77b8edd`, `b766903`, `68e8c2b`, `b700579`).

## 2. Files — `cosmic-files` (NicoArgo/cosmic-files) ✅

**Prévias**
- **Prévia ampliada (~240 px) no hover**, que segue o cursor, na grade e na lista. Commits `51ba475`, `78411b5`, `4124ccb`.
- **Miniatura no diálogo de renomear** (~288 px). Commit `0639510`.

**Árvore**
- **Árvore inline na lista**: ▸/▾, setas ←/→, mais as opções *Clique esquerdo expande* e *Manter expandidas*. Commit `9e4a1a4`.
- **Árvore na barra lateral**, como dropdown temporário. Commits `2168dfa`, `ba78dfb`.

**Pastas coloridas e regras**
- **Pastas na cor da regra do terminal**, em todas as visões, no desktop e na barra lateral. Commit `3d3d1c9` (merge `6c1e2ed`).
- **"Regra da pasta..."** no menu da pasta e no da barra lateral: nome, cor, subpastas. Commits `c3271ae`, `59b9cad`.
- **Seletor Abrir/Salvar acompanha as regras ao vivo.** Commit `84d3262`.

**Visão e menus**
- **Cada pasta lembra lista/grade**, com botões no cabeçalho. Commit `bd62b04`.
- **"Copiar caminho" sempre visível.** Commit `8844e45`.
- **"Abrir no terminal" na barra lateral.** Commit `f63865a`.

**Desktop**
- Colunas fixas com rolagem (`d043124`).
- Arrastar para qualquer célula, com posições por monitor (`4f527c9`).
- Barrinha de rolagem na cor de destaque (`224eea6`).
- Nomes em 2 linhas, 3 no hover (`da0f77c`, `9c335e0`).
- Sem bloco escuro atrás do nome (`8a0edde`).
- Ícone cresce no hover (`d5dbf0b`).

**Desempenho e instalação**
- Cache de ordenação: de 5 ms para 0,6 ms por quadro com 10 mil itens (`3ac4a14`).
- Install, auto-reapply e uninstall de verdade (`00f4e2b`, `0f2753f`).
- O desktop também é instalado (`d043124`).
- `pkill -f` (`b30cac2`).

## 3. Terminal — `cosmic-term` (NicoArgo/cosmic-term) ✅

**Regras por pasta**
- **T1 — aparência por pasta (`dir_rules`)**, reaplicada ao vivo no `cd`. Commits `8b3fb87`, `f5672ae`, `40a6a1b`, `de46665`.
- **Interface**: Arquivo → *Regras por pasta...* e, no botão direito, *Criar regra para esta pasta*, com seletor de cor. Commits `70c00f8`, `6d70c2f`.
- **T2 — identidade da pasta**:
  - acento da interface, faixa no topo, cursor na cor;
  - `{title}` no título da aba, com o nome em maiúsculas por padrão;
  - `--resolve-rule`.

  Commits `fbd86ba`, `c233d72`, `e28197e`, `3467fc5`.
- **CLI `--set-rule` / `--remove-rule`**, usada pelo Files. Commit `4edd77b`.

**Integração com o resto do desktop**
- **T3 — presença por janela** em `$XDG_RUNTIME_DIR/pop-flow/terminals/`, que alimenta o applet de terminais. Commit `1a93392`.
- **Integração com o Claude Code**: a statusline lê `--resolve-rule`.

**Correções:**
- grava as regras só quando a digitação para (`8aef1d5`);
- não zera regras com config inválida (`4edd77b`);
- regra perdida ao abrir sem `--working-directory` (`1a93392`);
- install/uninstall seguros (`c6e6ce8`, `3b42a48`, `84001e6`, `56abbbe`).

## 4. Painel e dock — `cosmic-applets` (NicoArgo/cosmic-applets)

**Dock e mostrar área de trabalho**
- ✅ **Prévia de janela ao passar o mouse no dock** (350 ms, popup com miniaturas). Commits `06708fd7`, `052887e1`, `188f8a4e`, `6c2beff9`, `f228eaf2`, `ffb217e8`. Mais a correção de vazamento de 2,9 GB (`3446f017`).
- ✅ **Applet "mostrar área de trabalho"**: guarda e restaura exatamente as janelas; `--toggle`, `--scope`, `--output`, `--dry-run`. Commits `de49826a`, `13079f1d`, `a5667103`, `bdfcbcc4`, `24202fe8`.
  - Está instalado, mas **fora do painel** hoje.
- ✅ **Super+D** mostra a área de trabalho.

**Cantos**
- ✅ **Triângulo no canto inferior direito**: clique ou repouso de 600 ms; um por tela; botão direito alterna "esta tela / todas"; entalhe indica o modo. Commits `9ba392f1`, `75444c6c`, `0d767f49`.
- ✅ **Cantos genéricos** (`--corner`, `--dwell-ms`, `--exec`). O canto superior esquerdo → overview está instalado, mas **desligado**. Commit `c5bd62cc`.

**Botões e applets do painel**
- ✅ **Botões Imagens/Downloads** que trazem a janela já aberta, com ícone na cor de destaque e crescimento no hover. Commits `3f378104`, `abd31c82`, `cbffe575`, `f828820a`, `1fcddea6`, `a74aa75f`.
- ✅ **Modo vampiro** (morcego/lua):
  - inibe a tampa no logind e zera a suspensão por inatividade, guardando os valores antigos;
  - **1 h / 3 h** temporário;
  - aviso "tampa fechada, PC acordado".

  Commits `721258ab`, `e8b7cdaa`, `8d354f6d`. **Está ligado agora.**
- ✅ **Applet de terminais**: abre um terminal novo e mostra uma bolinha por janela, na cor da regra da pasta, com menu. Commit `868dcd81`.

**Correções e instalação**
- 🔧 **Vazamento no `cosmic-applet-minimize`** (`fb72bf7b`): commitado, mas **não roda**. O minimize vem do binário multiplexado de fábrica, que o fork não troca.
- Instalação: auto-reapply (`72ccce88`), uninstall de verdade (`5c785038`), `.desktop` velhos da home movidos (`679335fc`).

## 5. Compositor — `cosmic-comp` ✅ (vale no próximo login)

- **G3 — gestos de três dedos**: ←→ troca de janela, ↑ overview, ↓ área de trabalho. Commit `30bc899b`.
- Base G0 com scripts que nunca reiniciam o compositor. Commits `a258a397`, `a3ab0649`.
- Atualizado para o código do pacote instalado (`0fbd457`, COSMIC 1.9.0) com o merge `f45ae7b8`, sem conflito. Instalado em 21/10 com backup `cosmic-comp.orig` e auto-reapply.

## 6. Overview do Super — `cosmic-workspaces-epoch` ✅

- **X para fechar cada janela** no overview, ao passar o mouse. Commit `4524bb8`.
- Install/reapply com checagem de versão. Commit `0b35b92`.
- O pacote é 1.0.12, igual à versão do fork. Instalado em 21/10, com auto-reapply.

## 7. Configurações — `cosmic-settings` (branch `pop-flow`) ✅

- **Telas → "Mostrar área de trabalho"**, chave "só esta tela / todas". Commit `0e1ae88`.
- Atualizado para a 1.9.0 (`7421ff0`) com o merge `6c2eaad`; o único conflito, em `pages/display/mod.rs`, manteve as mensagens do POP Flow e a nova do upstream. Instalado em 21/10, com auto-reapply.

## 8. Tema pelo papel de parede — `cosmic-wallsync` (próprio) ✅

- **Acento por k-means em Oklab**, com matiz leve no fundo e no texto, claro e escuro. Papel de parede cinza não mexe no acento.
- **`watch`** reage em menos de 1 s. CLI: `preview`, `apply`, `restore`. Exporta para GTK.
- Recusa pasta de slideshow e não grava nada se a config não fizer parse. Commit `be2f37f`.
- ⚠ Está fixado no `cosmic-theme` da 1.0.7 (config `v1`). Falta conferir com a 1.9.0.

## 9. Histórico da área de transferência — `cosmic-clipboard-history` (próprio) ✅

- **O que guarda**: só texto, até 200 itens, em arquivo 0600. Ignora senhas (hint do KeePassXC), cópias acima de 1 MiB e a seleção primária.
- **Super+V** → busca `cb` no launcher. Enter copia de volta; o botão direito oferece *Remover* e *Limpar tudo*.
- **CLI**: `list`, `copy N`, `clear`, `check`. Commit `b9d8178`.
- ⚠ O `cosmic-ext-applet-clipboard-manager` (flatpak) também está instalado e faz a mesma coisa.

## 10. Suíte (repo guarda-chuva NicoArgo/POP-Flow-Suite)

- **`install-all.sh`**: clona o que falta e instala tudo.
- **`setup-desktop.sh`**: coloca os botões no painel, Super+D, Super+V e, a partir de hoje, a tecla Print. É idempotente e faz backup.
- **Documentação**: ROADMAP, ARCHITECTURE, VISTORIA, relatório de travamento, handoff de sync e os PLANs.

---

## 11. Ajustes de desktop fora dos repos do POP Flow (achados na varredura)

Funcionam, mas não estão em nenhum repo nem no ROADMAP. Desde 21/10 há uma cópia de
todos eles em `Pop Flow/ajustes-do-sistema/` (`capturar.sh` atualiza; o README diz
como reaplicar). A pasta fica fora do repo público da suíte.


1. **Watchdog do Wi-Fi MT7921**: `/usr/local/sbin/wifi-watchdog` + serviço, `disable_aspm=Y` no modprobe e powersave desligado no NetworkManager. ✅ ativo.
2. **Tela de boot "nico"**:
   - tema Plymouth;
   - `nico-fb-splash.service` cobre o logo da Acer;
   - `retain-splash`;
   - parâmetros de kernel no kernelstub.

   ✅ ativo. Só há documentação parcial, no README do Ventoy.
3. **Atalhos manuais**:
   - Super+setas move a janela e Super+Shift+setas muda o foco (o inverso do padrão);
   - Ctrl+Alt+←/→ troca de área de trabalho, estilo GNOME;
   - **Super+H bloqueia a tela**;
   - Super+Z abre o MeuZap;
   - Ctrl+Shift+P estava quebrado (corrigido hoje pelo `setup-desktop.sh`).
4. **Painel, dock e compositor configurados à mão**:
   - painel com 28 px;
   - dock XS com opacidade 0,49 e autohide OnOverlap;
   - autotile por workspace, clickfinger, teclado br com compose no Ctrl direito;
   - gaps (0,3) e ícones Colloid-Dark.
5. **MeuZap**: autostart oculto, Super+Z, fixado no dock. É de outro repo.

**Sobras para limpar:**
- applet **CargoWatch** listado no dock, mas desinstalado;
- config do **minimon** sem o app instalado;
- limite de memória do **ZapZap** (já removido);
- em `Pop Flow/.claude/settings.local.json`, a statusLine aponta para o caminho antigo `Apps Workspace/Pop Flow/...`, que não existe mais.

---

## 12. Divergências e riscos encontrados

- ✅ *Resolvido em 21/10 (suíte `a7981fb`): status corrigidos e itens incluídos.* ~~**O ROADMAP marca como "falta instalar" coisas já instaladas**~~: applet de terminais, T3 do terminal, "Regra da pasta...", show-desktop por tela no applet. Não constam nele:
  - peek e regras de grade do launcher;
  - rodada 2 de 06/10 do Files;
  - cantos genéricos;
  - vampiro 1 h / 3 h;
  - CLI do clipboard-history.
- ~~**O desktop do Files está desatualizado**~~: resolvido pela instalação de 21/10.
- **Versões**:
  - ~~o `cosmic-term` instalado é o fork com base 1.5.0, por cima do pacote 1.9.0~~ → fork atualizado para a 1.9.0 (merge `2aac578`, 59 testes passando); **falta rodar `cosmic-term/install.sh`**;
  - ~~`install-all.sh` diz `TESTED_COSMIC=1.0.7`~~ → agora 1.9.0 (suíte `7119673`);
  - ~~comp e settings precisam de rebase antes de instalar~~ → atualizados e instalados em 21/10.
- ✅ ~~**Uninstall do launcher** sem trava de versão~~ → agora compara o backup com o checksum que o dpkg registrou e recusa um backup velho (launcher `15373b8`). O do Files tinha o mesmo problema e ganhou a mesma trava (`17725e7`).
- ✅ ~~**`setup-desktop.sh` devolve o botão "mostrar área de trabalho" ao painel**~~ → foi o que aconteceu na instalação das 18:45; o painel voltou ao estado anterior e o script agora lembra os botões que já colocou (`~/.local/state/pop-flow/panel-added`) e não recoloca um que você tirou (suíte `a7981fb`).
- Os binários `cosmic-launcher-baseline-7c5140f` e `cosmic-launcher-system-backup` na pasta da suíte são sobras de julho e podem ir para a lixeira (pendente: a limpeza precisa da sua confirmação).

---

## 13. Pendências do plano de qualidade de vida

- *Abrir no terminal* no **botão direito das abas** do Files: o tab bar não tem menu de contexto hoje.
- Rolagem ao arrastar na **barra lateral**.
- Seta **←** recolhendo a árvore da barra lateral.
- Para apps do launcher sem caminho, o pop-launcher não informa o executável.
- Sugestões **S1–S20** do plano, aguardando escolha.
