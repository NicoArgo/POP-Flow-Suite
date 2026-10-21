# Plano — qualidade de vida (21/10/2026)

Três pedidos: **"Abrir no terminal" em todo botão direito possível**, **rolar
ao arrastar até a borda** e **o canto "mostrar área de trabalho" funcionar com
um item sendo arrastado**. Mais sugestões no fim.

Legenda: ✅ já existe · 📋 a fazer · 💡 sugestão

---

## 0. O que já existe (vistoria)

| Onde | Estado |
|---|---|
| Files, espaço vazio da pasta | ✅ *Abrir no terminal* (upstream) |
| Files, **uma pasta** selecionada | ✅ *Abrir no terminal* (`menu.rs`, só com 1 pasta) |
| Files, barra lateral | ✅ (`f63865a`) |
| Launcher (Alt+Tab / busca) | ✅ para resultados com caminho |
| Files, rolar arrastando | ✅ só no **modo desktop** (`Message::DndMotion`, `tab.rs`), e só enquanto o mouse **se mexe**; ✅ no laço de seleção (`on_auto_scroll`) |
| Files, pasta que abre ao segurar um item em cima dela | ✅ (`DndEnter` → `DndHover`, `HOVER_DURATION`) |
| Canto "mostrar área de trabalho" | ✅ por clique e hover de 600 ms — **mas fica no canto inferior _direito_** e ignora o mouse durante um arrasto |

---

## 1. "Abrir no terminal" em todo menu de botão direito

### 1.1 Regra de qual pasta abrir (uma função só, `terminal_dir_for(path)`)

| Item clicado | Abre em |
|---|---|
| Pasta | a própria pasta |
| **Executável** (ELF, script com `+x`, `.AppImage`, `.sh`) | **raiz do repositório** do item (sobe até achar `.git`); sem repo → pasta do item |
| Atalho `.desktop` | resolve o `Exec=` (segue symlinks, ex. `/usr/local/bin/x` → fonte); raiz do repo dele; sem repo → pasta do binário |
| Arquivo comum | pasta do arquivo |
| Unidade montada / rede montada | ponto de montagem |
| Lixeira, Recentes sem caminho | não mostra |

A busca da raiz é feita em Rust (sobe os pais procurando `.git`, arquivo ou
pasta — cobre worktrees e submódulos), sem chamar `git`. Abre com o terminal
padrão e `--working-directory`, para o `cosmic-term` aplicar a cor da regra da
pasta.

💡 Pasta **dentro** de um repo (mas não na raiz): mostrar um segundo item
*Abrir raiz do repositório no terminal*. Só aparece quando a raiz ≠ pasta.

### 1.2 Onde adicionar — `cosmic-files`

1. 📋 **Arquivos** (hoje só pastas): menu de item, com a regra acima.
2. 📋 **Seleção múltipla**: se todos os itens caem na mesma pasta, um terminal;
   senão o item não aparece (nunca abrir N terminais).
3. 📋 **Área de trabalho**: o ramo de atalho `.desktop` (`selected_desktop_entry`)
   não tem o item — adicionar.
4. 📋 **Busca e Recentes**: abre na pasta de origem do resultado.
5. 📋 **Barra de caminho (breadcrumb)**: botão direito num segmento → terminal
   naquela pasta.
6. 📋 **Abas**: botão direito na aba → terminal na pasta da aba.
7. 📋 **Unidades / rede** na barra lateral (hoje só locais que são pasta).
8. 📋 **Diálogo Abrir/Salvar** (`dialog.rs`, usado por outros apps via portal):
   mesmo menu.

### 1.3 Onde adicionar — fora do Files

9. 📋 **Dock / lista de apps** (`cosmic-applets`, app-list): botão direito num
   app → *Abrir no terminal* na raiz do repo do binário. Útil para os apps da
   própria suíte (`/usr/local/bin/cosmic-*` → fonte em `Pop Flow/`). Para apps do
   sistema sem repo, o item não aparece.
10. 📋 **Launcher**: ideia já no roadmap — apps sem caminho resolvem o `Exec=`
    pela mesma regra.
11. 💡 **Terminal**: botão direito na aba → *Nova aba na raiz do repositório*.

**Fora de alcance:** apps de terceiros (Chrome, VS Code, Electron) — o menu deles
não é nosso.

---

## 2. Rolar ao arrastar até a borda (Files, grade e lista)

Hoje só o desktop rola, e só enquanto o mouse se mexe. Com o mouse **parado** na
borda, nada acontece — e é aí que a intenção é mais clara.

1. 📋 Ligar o `DndMotion` também no **modo App** (grade, lista, árvore inline).
2. 📋 **Rolagem contínua por timer** (~60 fps) enquanto o ponteiro estiver na
   faixa da borda, mesmo parado; para ao sair da faixa, ao soltar
   (`Drop`) ou ao sair da janela (`DndLeave`).
3. 📋 **Velocidade proporcional à profundidade** na faixa (faixa de ~64 px:
   na entrada devagar, encostado na borda rápido) + aceleração leve após ~1 s
   parado. Mesma curva para cima e para baixo.
4. 📋 Mesma rolagem na **barra lateral** (a árvore dela fica longa).
5. 📋 Desktop passa a usar o mesmo timer (corrige o "só rola se mexer").
6. 📋 Pasta que abre ao segurar em cima (já existe) continua valendo durante a
   rolagem: o item sob o ponteiro muda, o timer do hover recomeça.

Testes: curva de velocidade pura (`edge_speed(y, altura) → px/s`) com teste
unitário; o resto validar a olho.

---

## 3. Canto "mostrar área de trabalho" durante um arrasto

**Por que hoje não funciona:** no Wayland, enquanto um item é arrastado o
compositor não manda eventos de ponteiro para as outras superfícies — manda
eventos de *drag-and-drop* (`wl_data_device` enter/motion/leave). O triângulo só
escuta o ponteiro, então não vê nada.

1. 📋 `cosmic-show-desktop-corner` passa a ser também **alvo de DnD**: escuta
   `enter`/`motion`/`leave` do `wl_data_device`, **nunca aceita o drop** (o
   item não "cai" no triângulo).
2. 📋 No `enter` de DnD: mesmo hover de 600 ms, mesmo crescimento visual, roda o
   mesmo `--toggle`. Uma vez por visita, como hoje.
3. 📋 Garantir que **minimizar a janela de origem não cancela o arrasto** — o
   arrasto pertence ao cliente, não à janela, mas precisa ser testado
   (Files → desktop, Files → outra janela, Chrome → desktop).
4. 📋 Com as janelas minimizadas, soltar no desktop copia/move como um drop
   normal no Files-desktop (já funciona; validar a posição da célula).
5. 💡 Ao soltar, **não** restaurar as janelas sozinho (comportamento do
   Windows); o canto/Super+D trazem de volta.

---

## 4. Sugestões (escolher quais entram)

| # | Sugestão | Onde | Custo |
|---|---|---|---|
| S1 | **Abrir no editor / VS Code** ao lado de *Abrir no terminal*, também na raiz do repo | Files | baixo |
| S2 | **Copiar caminho relativo à raiz do repo** (para colar no Claude/commit) | Files | baixo |
| S3 | **Emblema de git** no ícone da pasta-raiz de repo (e "sujo" quando há mudanças) | Files | médio |
| S4 | **Terminal na pasta do Files com F4** (atalho, como no Dolphin) | Files | baixo |
| S5 | **Arrastar item para a bolinha de um terminal** no painel → cola o caminho no terminal | applet terminais | médio |
| S6 | **Arrastar item para o ícone do terminal** no painel → abre terminal ali | applet terminais | baixo |
| S7 | **Arrastar sobre um app no dock** traz a janela para frente (soltar dentro dela depois) | app-list | médio |
| S8 | **Pré-visualização com Espaço** (Quick Look) maior que o tooltip do F1 | Files | médio |
| S9 | **Criar arquivo a partir de modelos** (`~/Modelos`) no menu do espaço vazio | Files | baixo |
| S10 | **Botão direito no executável → "Executar no terminal"** (vê a saída/erros) | Files | baixo |

---

## 5. Ordem proposta

1. **§1.1 + §1.2 itens 1–3** (regra + arquivos/executáveis/desktop) — o pedido
   principal, um commit.
2. **§2** rolagem ao arrastar — um commit, com a curva testada.
3. **§3** canto durante arrasto — no `cosmic-applets`.
4. §1.2 itens 4–8 e §1.3.
5. Sugestões escolhidas.

Cada item vira entrada no [ROADMAP.md](ROADMAP.md) ao começar. Instalação dos
binários fica com você num terminal (precisa de sudo).

---

# Parte 2 — complemento (21/10, tarde)

Respostas da rodada 1: o canto "mostrar área de trabalho" é o **inferior
direito**, e o **inferior esquerdo** passa a fazer o mesmo (qualquer um dos dois
serve, inclusive arrastando um item).

## 6. Árvore da barra lateral: seta para recolher

**Problema (print de 21/10):** ao clicar em *Área de trabalho* ela abre as
subpastas, mas não há nada visível para fechar. Hoje o único jeito de recolher é
clicar **de novo** na pasta em que você já está (ou sair dela) — gesto
invisível. O `segmented_button` do libcosmic não tem chevron.

**Solução sem mexer no libcosmic:** o `nav_bar` já tem um botão à direita do item
(o de "fechar", `close_icon` + `on_close`, por item via `closable`).

1. 📋 Item **aberto** fica `closable` com `close_icon = pan-down-symbolic` (▾),
   sempre visível (`show_close_icon_on_hover = false`). Clicar na seta
   **recolhe** (`toggle_nav_expand`) sem navegar.
2. 📋 Pasta **fechada que tem subpastas**: ▸ (`pan-end-symbolic`) que abre sem
   navegar. Só se o `nav_bar` aceitar ícone por item; senão fica só o ▾ (o
   clique no nome continua abrindo).
3. 📋 Recolher pela seta também fecha as subpastas abertas dentro (já é o que o
   `toggle_nav_expand` faz com `retain(!starts_with)`).
4. 📋 Seta **←** com o foco na barra lateral recolhe, como na lista.

## 7. Captura de tela vai para o Ctrl+V (e cola no Claude Code)

**Vistoria:**
- **Falta o `wl-clipboard`** (`wl-copy`/`wl-paste`). O Claude Code no Linux lê
  imagem do clipboard com `wl-paste` (Wayland) ou `xclip` — **sem ele, Ctrl+V de
  imagem nunca funciona no terminal**, mesmo com a imagem copiada.
- O `cosmic-screenshot` salva **ou** copia (escolha na janela do portal), nunca
  os dois, e imprime o caminho do arquivo salvo no stdout.
- O atalho personalizado **Ctrl+Shift+P → `gnome-screenshot -a`** está quebrado:
  o `gnome-screenshot` não está instalado.

**Plano:**
1. 📋 `sudo apt install wl-clipboard` (você roda; precisa de senha).
2. 📋 Script `pop-flow-capture` (no `cosmic-applets`, junto dos outros binários
   da suíte):
   `p=$(cosmic-screenshot "$@")` → se veio caminho, `wl-copy --type image/png < "$p"`.
   Se você escolheu "copiar" no portal, não há arquivo e o clipboard já está
   certo. Resultado: **salva em `~/Imagens/Screenshots` e fica no Ctrl+V**.
3. 📋 Tecla **Print** e **Ctrl+Shift+P** passam a chamar o `pop-flow-capture`
   (o segundo, direto no modo retângulo). Feito no `setup-desktop.sh`,
   idempotente, com backup.
4. 📋 Notificação diz "Copiada — Ctrl+V para colar".
5. 📋 Validar no `cosmic-term`: Ctrl+V vai para o Claude Code (o terminal usa
   Ctrl+Shift+V para o próprio colar), que mostra `[Image #1]`.
6. 📋 Conferir com o `cosmic-clipboard-history`: imagem entra no histórico sem
   duplicar e sem guardar PNGs gigantes para sempre.
7. 💡 Botão direito numa imagem no Files → **Copiar imagem** (o conteúdo, não o
   caminho), para colar no Claude/WhatsApp.

## 8. Canto inferior esquerdo = mostrar área de trabalho

1. 📋 Segunda instância do mesmo binário:
   `cosmic-show-desktop-corner --corner bottom-left --dwell-ms 600` (serviço
   `cosmic-show-desktop-corner-left.service`). O nome da camada já é derivado do
   canto, então as duas convivem.
2. 📋 O suporte a arrasto (§3) vale para os dois cantos — é o mesmo código.
3. 📋 Conferir que o triângulo esquerdo não cobre o primeiro ícone do dock nem o
   botão do App Library (região de entrada de 28 px).
4. 📋 `install.sh` + `setup-desktop.sh` instalam e ligam os dois.

## 9. Mais sugestões

| # | Sugestão | Onde | Custo |
|---|---|---|---|
| S11 | **Captura de uma janela/área → já anotar** (seta, retângulo, borrar) antes de copiar | novo, ou PhotoCraft | alto |
| S12 | **Gravar tela curta em GIF/MP4** com atalho, também copiada | novo | médio |
| S13 | **OCR da captura**: Super+Shift+T copia o **texto** da área selecionada (tesseract, já usado no acervo da CLDF) | script | baixo |
| S14 | **Colar imagem no Files** (Ctrl+V numa pasta com imagem no clipboard cria `colado-AAAA-MM-DD.png`) | Files | baixo |
| S15 | **Arrastar a captura** da notificação direto para outro app | notificação | médio |
| S16 | Árvore da barra lateral **lembra a rolagem** e destaca a pasta atual dentro dela | Files | baixo |
| S17 | **Cantos configuráveis** em Configurações → Área de trabalho (qual ação em cada canto, tempo de hover) | cosmic-settings | médio |
| S18 | **Canto superior direito → notificações / central** (o último canto livre) | corner | baixo |
| S19 | **Abrir pasta das capturas** ao clicar na notificação, com o arquivo selecionado | Files | baixo |
| S20 | **Ctrl+Shift+C no Files** copia o caminho (hoje só pelo menu) | Files | baixo |

## 10. Ordem proposta (junta com a §5)

1. **§7 captura → clipboard** (rápido e destrava colar no Claude).
2. **§6 seta de recolher** na barra lateral.
3. **§8 canto esquerdo** + §3 (arrasto) nos dois cantos.
4. Itens 1–3 da §5 (terminal, rolagem ao arrastar).
5. O resto e as sugestões escolhidas.
