# Roadmap — POP Flow

Estado da suíte por componente. Legenda:
**✅ feito** · **🚧 em andamento** · **📋 planejado** · **💡 ideia (backlog)**

> Ao concluir um item, mova-o para "feito" com uma linha do que mudou. Ao pegar
> um novo, crie a entrada aqui **antes** de codar.

---

## ✅ Rodada 21/10 — qualidade de vida (instalada em 21/10)
Plano em [PLAN-qualidade-de-vida-2026-10.md](PLAN-qualidade-de-vida-2026-10.md).

- **Captura vai para o Ctrl+V** — `pop-flow-capture` (cosmic-applets `3bb4a994`):
  salva em `~/Imagens/Screenshots` **e** copia a imagem (`wl-copy`), notificação
  com "Mostrar na pasta". `setup-desktop.sh` aponta Print e o Ctrl+Shift+P
  quebrado (`gnome-screenshot` não instalado) para ele. Precisa de
  `wl-clipboard` — sem ele o Claude Code também não cola imagem.
- **Canto inferior esquerdo** também mostra a área de trabalho
  (`cosmic-show-desktop-corner-left.service`), e **os dois cantos funcionam
  arrastando um item** (escuta `wl_data_device`; nunca aceita o drop) — `3bb4a994`.
- **Files** (`dc84f4b`):
  - *Abrir no terminal* para qualquer seleção que dá numa pasta só: pasta → ela;
    arquivo → a pasta dele; **executável → raiz do repositório git**; atalho
    `.desktop` → `Path=` ou o repo do programa (`src/terminal_dir.rs`, 8 testes).
    Vale na área de trabalho, em Recentes/busca e na **barra de caminho**
    (também no seletor Abrir/Salvar).
  - **Seta ▾ para recolher** a pasta aberta na barra lateral (o slot de "fechar"
    do `nav_bar`); enquanto há pasta aberta, *Ejetar* vai para o menu do drive.
  - **Rolagem ao arrastar até a borda**, contínua mesmo com o mouse parado,
    mais rápida no fundo da faixa e com o tempo (teste da curva). O desktop usa
    o mesmo timer.
- **Dock**: *Abrir no terminal* para apps com repositório próprio ou `Path=`
  (cosmic-applets `ffb3dcaf`).
- **Launcher**: executável abre o terminal na raiz do repo (`88f29db`).
- **Terminal**: *Nova aba na raiz do repositório* no botão direito (`371dc68`).

---

## Launcher — `cosmic-launcher/` (`NicoArgo/POP-Flow`)

Alt+Tab estilo Windows com grade de miniaturas ao vivo. Instalado e em uso.

### ✅ Feito
- Grade de miniaturas ao vivo no Alt+Tab (substitui o Alt+Tab textual do COSMIC).
- Captura de miniaturas em thread wayland dedicada (screencopy + toplevel-info),
  com downscale e backend robusto.
- Botão **fechar (X)** por miniatura — via `pop_launcher::Request::Quit(id)`,
  fecha a janela exata (nunca uma parecida).
- **Atribuição 1:1** de miniaturas: janelas de mesmo título não compartilham a
  mesma imagem.
- **Posições fixas na grade**: cada janela mantém sempre a mesma célula — ativar
  uma janela não a joga para a primeira posição. Janelas novas entram no fim,
  fechadas somem; o Alt+Tab continua abrindo já com a janela anterior destacada.
- **Agrupamento por app** sobre essa ordem fixa.
- **Grade adaptativa sem scroll**: expande em colunas/linhas e **encolhe as
  miniaturas** para caber na tela, em vez de rolar.
- **Regras de tamanho** (`f862776`): miniatura entre 120×70 e 264×156; acima
  disso pagina com `+N`; detecta escala 1,25.
- **Peek** (`f7adf38`): a célula em foco cresce 1,2× em 120 ms, com sombra.
- **Menu de botão-direito enriquecido**: mescla ações do launcher — *Abrir no
  terminal*, *Abrir pasta*, *Copiar caminho* (para resultados com caminho de
  arquivo) — com as opções do pop-launcher.
- **Auto-reapply** após updates de pacote; `install.sh` / `uninstall.sh` / README.
- **Vazamento de memória corrigido** (`50b5b26`): a captura de miniaturas criava
  um pool shm e um `wl_buffer` por janela a cada abertura e só destruía o pool.
  Destruir um pool não invalida os buffers feitos dele, então cada abertura
  deixava ~8 MiB por janela mapeados no `cosmic-comp` até o fim da sessão — a
  causa do travamento em ~24 h descrito em
  [RELATORIO-travamento.md](RELATORIO-travamento.md) §7. Medido: 1153 MiB
  retidos numa sessão de 40 min, zero depois de `pkill -x cosmic-launcher`.

### ✅ Validado — **vazamento corrigido, medido depois de instalar** (10/8)
Com a correção instalada: 25 aberturas do overlay, **0 pools órfãos, 0 MiB**;
uma hora e quarenta de sessão, também 0. Antes eram 1153 MiB em 40 minutos. O
que conta como vazamento é o fd que *só* o compositor segura — o
`sampler.py` cruza os inodes de todos os processos para separar isso do
normal (uma ou duas superfícies vivas por cliente).

### ✅ Feito — **menu de contexto: o caminho não vinha de onde achávamos** (10/8)
Perguntando direto ao pop-launcher (`{"Search":"~/Doc"}`), o plugin de arquivos
responde `name` = só o nome e `description` = o **tamanho** ("12.00 KiB"). Como
o `result_path` procurava um caminho nesses dois campos, *Abrir no terminal*,
*Abrir pasta* e *Copiar caminho* **nunca apareciam** — e é justo o plugin que
mais quer essas ações. O plugin `recent`, por outro lado, devolve um URI
`file://` percent-encoded, que também não resolvia.

Agora os três formatos são cobertos: URI `file://`, caminho literal, e — para o
navegador de arquivos — a pasta sai da **consulta digitada** e o nome do
resultado a completa. Nomes vêm percent-encoded (`%C3%81rea%20de%20trabalho`),
então são decodificados antes de testar a existência, e `..` é recusado para não
agir fora da pasta listada. Testes cobrem os formatos exatos que o pop-launcher
devolveu nesta máquina.

### 📋 Planejado / a validar
- Ajuste fino do tamanho das miniaturas em telas/contagens variadas — precisa de
  olho, em telas e contagens de janela diferentes.

### 💡 Ideias
- "Abrir no terminal" também para apps/resultados sem caminho (abrir na home).
- ~~Pré-visualização maior ao focar (peek)~~ feito (`f7adf38`).
- Ações extras por tipo de janela (mover para workspace, etc.).

---

## Files — `cosmic-files/` (`NicoArgo/cosmic-files`)

Gerenciador de arquivos do COSMIC. Fork recém-criado, pronto para trabalho.

### ✅ Feito — **F1: preview maior no hover** (grade + lista)
Ao passar o mouse sobre o ícone de um arquivo, um tooltip mostra uma versão
ampliada (~240px) da miniatura — só para imagens/SVGs, reusando o handle já em
cache (sem regenerar). Via `Item::hover_peek()` + `Item::peek_wrap()` na
`grid_view` e nas 3 variantes da `list_view`, com `Position::FollowCursor` (o
preview segue o cursor). Commits `51ba475` (grade) + `78411b5` (lista) +
`4124ccb` (segue o cursor).

### ✅ Feito — **Barra lateral: "Abrir no terminal"**
O menu de botão-direito da barra lateral (locais/pastas) ganhou **"Abrir no
terminal"** para locais que são pasta, abrindo o terminal padrão naquela pasta.
Reusa a detecção de terminal (`mime_app_cache.terminal()`) e o `spawn_detached`
que o `cosmic-files` já usa no menu da área principal. Commit `f63865a`.

### ✅ Feito — **Miniatura no modal de renomear**
Ao renomear uma **imagem**, o modal mostra um preview dela (~288px, um pouco
maior que o do hover) acima do campo de nome. Só para arquivos de imagem.
Commit `0639510`.

### ✅ Feito — **Dropdown de pastas (árvore) na lista**
Cada pasta na visão em lista ganhou um **chevron ▸/▾**: clicar abre o conteúdo
**inline**, sem trocar de janela, com scroll contínuo. Várias pastas e subpastas
podem ficar abertas ao mesmo tempo. Setas **←/→** recolhem/expandem a pasta em
foco (não faziam nada de útil na lista, que tem uma coluna só).

Arquitetura: `items_opt` continua um `Vec<Item>` **plano** — assim clique,
seleção, laço, DnD, virtualização e miniaturas seguem funcionando sem mudança.
Cada `Item` ganhou `depth` + `tree_parent` (caminho, não índice, porque índices
se deslocam). A hierarquia é montada no `column_sort()`, que agrupa por
`tree_parent` e emite em DFS — então **a ordenação passa a valer dentro de cada
pasta** em vez de espalhar os filhos. Expandir só faz `push` no fim do vetor,
nunca desloca índices já capturados por mensagens de clique pendentes.
`Tab::expanded` (conjunto de caminhos absolutos) é a intenção do usuário e
sobrevive aos rescans; o `update_watcher` passou a observar também as pastas
abertas (o watch não é recursivo). Grid/busca/lixeira/recentes ficam de fora.

Duas opções no menu **Exibir**: *Clique esquerdo expande pastas* (padrão
desligado — o chevron sempre funciona) e *Manter pastas expandidas* (padrão
ligado — voltar para a pasta reabre o que estava aberto). 6 testes novos cobrem
expansão, recolhimento, ordenação, grid e persistência.

### ✅ Feito — **Árvore também na barra lateral**
As pastas favoritas da barra lateral abrem **inline**, indentadas, mostrando suas
subpastas (só pastas — a barra lateral é uma lista de lugares, não de arquivos).
Usa a **indentação nativa do `nav_bar`** do libcosmic, que já desenha as linhas-
guia; o `segmented_button` não tem chevron, então o gesto é o clique: clicar numa
pasta em que você **não está** navega e abre; clicar na pasta em que você **já
está** fecha. As subpastas são listadas fora da thread de UI
(`Message::NavExpanded`); `App.nav_expanded` sobrevive às reconstruções do
modelo. Liga/desliga em **Exibir → Expandir pastas na barra lateral**.

**A árvore é transitória** (mudança de 2026-08-18, a pedido): ela é um dropdown,
não um segundo painel. Fecha sozinha quando a aba sai da pasta que a abriu — por
qualquer caminho: outro lugar na barra lateral, a barra de caminho, o botão
voltar, duplo-clique na lista, troca de aba (`collapse_nav_tree_unless_inside`,
chamada depois do `tab.update`, quando a aba **já** se moveu) — e também no
clique solto na lista de arquivos ou em qualquer área que nenhum widget
reivindicou (`Message::Mouse`). Só uma ramificação fica aberta por vez; entrar
numa subpasta **de dentro** dela aninha em vez de fechar, que é o ponto da
árvore. Fechar descarta as subpastas abertas dentro e o cache de listagem — nada
sobrevive ao clique que abriu, e uma pasta criada no meio do caminho aparece na
próxima abertura. O colapso escuta o **soltar** do botão, não o apertar, senão
arrastar um arquivo da lista para uma subpasta aberta fecharia o alvo no meio do
gesto.

### ✅ Feito — **pastas na cor da regra** (`3d3d1c9`, merge `6c1e2ed`)
A pasta que tem regra no terminal (`dir_rules`, com `accent`) aparece **na cor
dela** aqui também: lista, grade, árvore inline, área de trabalho e barra
lateral. O `cosmic-files` lê a **mesma chave** do terminal, sem cópia: uma pasta
tem uma cor e um lugar para trocá-la, e uma assinatura do config segue as
mudanças ao vivo.

O ícone colorido é o SVG do próprio tema com os quatro cinzas trocados por tons
da cor (a frente é a cor, a aba de trás bem mais escura), com cache por
(arquivo, cor). As pastas especiais (Documentos, Downloads…) usam os mesmos
cinzas, então mantêm o desenho. Tema cujas pastas não usam esses cinzas recebe
uma pasta simples na cor em vez de uma recolorida pela metade. Na barra lateral
os ícones são simbólicos e só são tingidos. A regra de alcance é a do terminal:
só a pasta, a não ser com `include_subdirs`; a mais funda vence. 6 testes novos
(51 no total).

_Estado: **instalado e validado** (28/09). Lista e barra lateral conferidas a
olho; ao vivo também: uma regra adicionada no `dir_rules` pintou a pasta em ~3s
com a janela aberta, e removê-la devolveu o cinza. No `master` junto com a
visão por pasta (`bd62b04`)._

### ✅ Feito — **"Regra da pasta..." no botão direito** (06/10)
Logo abaixo de *Renomear*, no menu de uma pasta (lista, grade e área de
trabalho): um diálogo com **nome**, **cor** (12 amostras ou hex) e *aplicar
também às subpastas*, com prévia da pasta já colorida. Se a pasta já tem regra,
o diálogo vem preenchido e oferece *Remover regra*. Não precisa abrir o
terminal.

Quem grava é o próprio terminal: o Files chama `cosmic-term --set-rule` /
`--remove-rule` (novos no `cosmic-term`, `4edd77b`), e o observador de config
repinta a pasta. Assim só o terminal conhece o formato da regra, e uma regra
existente mantém o que o diálogo não mostra (opacidade, temas). O item só
aparece se o `cosmic-term` instalado tiver `--set-rule` — o de fábrica abriria
uma janela. Commit `c3271ae`.

_Estado: compilado, testado (67 + 57 testes) e **instalado** (Files e terminal)._

### ✅ Feito — **rodada 2 de 06/10**
- Cada pasta lembra lista/grade, com botões no cabeçalho (`bd62b04`).
- *Copiar caminho* sempre visível (`8844e45`), também no desktop.
- Seletor Abrir/Salvar acompanha as regras de pasta ao vivo (`84d3262`).
- Cache de ordenação: de 5 ms para 0,6 ms por quadro com 10 mil itens (`3ac4a14`).

### ✅ Feito e validado — **área de trabalho livre: arrastar para qualquer célula, com scroll** (30/9)
Cada ícone do desktop tem uma célula própria. Arrastar ícones e soltar no
próprio desktop — antes um no-op ("already in target directory") — agora os
move para a célula mais próxima da imagem de arrasto (snap leve). Um grupo
mantém o formato; cair em cima de outro ícone manda para a célula livre mais
próxima. As linhas não têm limite abaixo da tela: durante o arrasto sobra uma
linha vazia sob o último ícone e a borda rola, então soltar ali faz o desktop
rolar. O papel de parede não se mexe (é outra camada, cosmic-bg).
- Posições por monitor em `~/.local/state/cosmic-files/desktop-positions.ron`.
- Ícones nunca posicionados ocupam a primeira célula livre na ordem antiga
  (descendo `columns` colunas, padrão 4, uma tela por vez) — o desktop só muda
  no primeiro arrasto. No primeiro arrasto, o layout inteiro é congelado.
- A barra de rolagem padrão (trilho escuro + alça cinza) some no desktop; no
  lugar, uma barrinha de 4 px na cor de destaque, só quando há o que rolar
  (`224eea6`). É só indicador — o libcosmic não deixa recolorir a nativa.
- Nomes em até duas linhas, e a célula reserva só duas (linhas mais próximas);
  o nome completo fica no tooltip. Sem bloco escuro em repouso: texto branco com
  sombra desenhada; o bloco volta no hover/seleção (`8a0edde`).
- Ícone cresce no hover (1,15× em 120 ms); a célula reserva o tamanho crescido
  para nada se mexer (`d5dbf0b`).
- Regras puras em `desktop_layout.rs` (11 testes).
- **Descoberta:** o desktop é outro binário, `cosmic-files-applet`, e ele
  **nunca foi instalado pelo fork** — rodava o de fábrica. `install.sh`,
  `uninstall.sh` e o auto-reapply agora cobrem os dois (e reiniciam o desktop
  com `pkill -f`: o `-x` nunca casava, o nome do processo é truncado em 15).

### 📋 Planejado / a validar
- Validar em uso real; ajustar tamanhos/posições conforme feedback.
- Árvore: testar com pasta muito grande (o `column_sort` roda por frame).
- Barra lateral: sem chevron (limitação do `segmented_button`). Um chevron
  exigiria forkar o libcosmic — decidir se vale.

### 💡 Ideias
- Flag em `TabConfig` (`peek_on_hover` / tamanho) para ligar/desligar/ajustar.
- Miniaturas maiores/ajustáveis; melhor densidade de grade.
- Mais itens na sidebar (copiar caminho, abrir em nova janela para arquivos…).
- Árvore: animação de abertura. (Persistir foi decidido contra — ver acima.)

---

## Overview do Super — `cosmic-workspaces-epoch/` (`NicoArgo/cosmic-workspaces-epoch`)

A tela de Task-View (tecla Super). Fork criado 2026-07-20.

### ✅ Feito e instalado (21/10) — **X ao passar o mouse** (`4524bb8`)
`install.sh` com auto-reapply desde `0b35b92`; o instalador recusa versão de
pacote diferente da do fork (hoje ambas 1.0.12).

### 📋 Depois — portar mais melhorias do launcher
- ~~**Botão X de fechar** por miniatura de janela~~ feito acima.
- Depois: grade adaptativa / preview no hover, conforme fizer sentido aqui.
_Explorando onde as miniaturas de janela e o fechamento (toplevel-management)
são feitos._

---

## Compositor — `cosmic-comp/` (`NicoArgo/cosmic-comp`)

⚠ **É o compositor** — mudanças aqui, se quebrarem, derrubam a sessão; testar
exige reiniciar o compositor/sessão. Mudanças cirúrgicas e muito cuidado.

### ✅ Fechado sem código — **snap de bordas (Aero-snap)** (06/10)
Já é nativo: arrastar uma janela flutuante para a borda/canto encaixa em
metade/quarto/maximiza (`SnappingZone` em `shell/grabs/moving.rs`, desde
`a4f30063`, 2024). O COSMIC instalado já tem.

### ✅ Feito e instalado (21/10) — **G3: gestos de três dedos** (`30bc899b`)
Fork atualizado para o código do pacote 1.9.0 (merge `f45ae7b8`) e instalado;
vale a partir do login seguinte. No `install-all.sh` desde `4b0b44a`
(opcional, último, pede `yes`). Ver
[PLAN-acao-2026-10.md](PLAN-acao-2026-10.md) P1.

---

## Barra de tarefas — `cosmic-applets/` (`NicoArgo/cosmic-applets`)

Os applets do painel. Fork criado 2026-07-20. Alvo: o applet **app-list** (a dock
de apps).

### ✅ Feito — **preview de janela no hover** (popup interativo)
Passar o mouse (debounce 350ms) no ícone de um app rodando → abre o **popup
interativo** de miniaturas (o mesmo do clique, que reusa screencopy + toplevel
tracking). Dá pra clicar numa miniatura pra ativar/fechar a janela; fecha ao
clicar fora. Adiciona `on_enter`/`on_exit` no ícone + helper `open_windows_popup`
compartilhado. Instala só o binário standalone `cosmic-app-list` por cima do
symlink (sem `libudev`), reinicia o `cosmic-panel`. Commits `06708fd7` →
`ffb217e8`.

**Limitação conhecida:** o popup faz *grab* (necessário pra ser clicável), então
**não troca** ao passar para outro app — pra ver outro, clica fora e faz hover.
Tentativas de popup transparente (grab off + input_zone vazio) quebraram os
cliques e o reconhecimento do mouse no COSMIC — ver histórico. Um preview que
troca ao vivo E é clicável exigiria mudança no **compositor** (quem roteia o
input do popup); fica como ideia futura.

### ✅ Feito — **vazamento do applet minimize** (`fb72bf7b`)
O mesmo ciclo de referência que o `3446f017` tirou do app-list: o `FrameData`
guardava um `CaptureSession` forte, o objeto do frame sobrevive à captura, então
o `Drop` que manda `destroy` nunca rodava — uma sessão e seus buffers vazados
por captura, dos dois lados do protocolo. Ficou de fora daquele commit porque
este applet captura ao minimizar (sangra devagar), não ao passar o mouse. Não
está no painel aqui, então a correção vale por paridade com a versão medida, não
por medição própria.

### ✅ Feito — **G1+G2: applet "mostrar área de trabalho"** (`de49826a`)
Um clique guarda todas as janelas do workspace atual; o próximo traz **de volta
exatamente aquelas**. Applet novo (`cosmic-applet-show-desktop`), sem tocar no
compositor nem no painel.

A regra que sustenta tudo é *"restaure exatamente o que você guardou"*: janela
que o usuário já tinha minimizado continua minimizada na volta, janela aberta
durante a área de trabalho não é varrida pela volta, e janela restaurada à mão
no meio do caminho fica onde ele deixou. Essa decisão vive em `show_desktop.rs`
como dados entra / passos sai, com **9 testes** — nenhum precisa de compositor.

Filtra pelo **workspace ativo**, o que não é cosmético: minimizar entre
workspaces deixaria os outros vazios ao voltar. Sem workspace ativo reportado,
cai para todas as janelas em vez de nenhuma.

Instala em `/usr/local` (software novo, não substituição), então **não precisa
de auto-reapply** — o dpkg não é dono do arquivo. **Não é adicionado ao painel
automaticamente**: isso reescreveria a configuração do painel do usuário. Para
usar: *Configurações → Área de trabalho → Painel → Configurar applets*.

Plano completo em [PLAN-gestos-e-mostrar-area.md](PLAN-gestos-e-mostrar-area.md).

### ✅ Feito — **botões de pasta (Imagens e Downloads)** — v1, substituída acima
Um clique abre a pasta no `cosmic-files`. **Sem código nosso**: o
`cosmic-panel-button`, que já vem neste mesmo pacote, desenha um botão a partir
de uma entrada `.desktop` e roda o `Exec` dela ao ser pressionado — é assim que
o botão "Aplicativos" funciona. Então cada botão são dois arquivos em
`data/folder-buttons/`: a entrada que o painel lista como applet, e a entrada
para a qual ela aponta.

O `Exec` é `cosmic-files "$(xdg-user-dir PICTURES)"`. O applet executa via
`sh -c`, então a substituição acontece **no clique**: o botão segue o diretório
XDG onde quer que ele esteja e com o nome que o idioma der (aqui `~/Imagens`),
em vez de congelar o caminho de uma máquina num arquivo que a gente distribui.

Duas armadilhas que só apareceram rodando:
- **`Name[pt_BR]` sozinho nunca casa.** A busca de locale tenta o `LANG`
  inteiro (`pt_BR.UTF-8`) e depois só o que vem antes do `_` (`pt`) — nunca o
  `pt_BR` puro. É por isso que toda entrada traduzida que o COSMIC distribui
  carrega as duas chaves; as nossas agora também.
- **Ícone ou texto não é escolha nossa.** Com o painel em `Custom(28)`, o
  `cosmic-panel-button` sempre renderiza texto — o "Aplicativos" ao lado é
  texto pelo mesmo motivo. Ícone exigiria `force_presentation: Icon`, que é uma
  config compartilhada por todos os botões e mudaria o "Aplicativos" junto.
  Ficou texto, por decisão de quem usa.

Instala em `/usr/local/share/applications` (software novo, sem auto-reapply,
nenhum binário a compilar). Diferente do show-desktop, estes **foram**
adicionados à ala esquerda do painel — foi o pedido; o `plugins_wings` anterior
está em `plugins_wings.bak-popflow`.

### ✅ Feito e validado — **triângulo "mostrar área de trabalho" no canto** (30/9)
`cosmic-show-desktop-corner`: um triângulo no canto **inferior direito** que
roda `cosmic-applet-show-desktop --toggle` — o mesmo estado do botão do painel.
Discreto em repouso (12 px, destaque clareado), cresce no hover; todo o
triângulo de 28 px é clicável (região de entrada em escada). Camada Top: acima
das janelas, abaixo de tela cheia. sctk + shm puro, ~2,5 MiB. Serviço systemd
de usuário.

### ✅ Corrigido — **`--toggle` travava e nunca minimizava nada** (`a5667103`)
O toggle lia só a primeira lista de janelas e parava de ler. A thread Wayland
manda uma lista por janela descoberta, encheu o canal (capacidade 4), travou no
`send` — antes de executar os pedidos de minimizar — e o `join()` esperou para
sempre. Com mais de 4 janelas, todo toggle travava: o canto, o gesto e o atalho
não faziam nada (achado pelos 12 processos presos, um por clique). Agora o
toggle espera a lista assentar (150 ms sem mudança, prazo real por polling),
fecha o canal e age sobre a lista **completa** — a primeira só tinha uma janela.

### ✅ Feito e validado — **botões de pasta trazem a janela aberta** (30/9)
Imagens e Downloads eram `cosmic-panel-button`, que só roda um comando: cada
clique abria outra janela. Agora são um applet nosso
(`cosmic-applet-folder-button pictures|downloads`) que acompanha as janelas: o
clique traz para frente uma janela do Files já nessa pasta (desminimiza, ou vai
para a área de trabalho dela) e só abre uma nova se não houver. Com a janela
aberta, o nome fica na cor de destaque. Casa pelo título "‹pasta› — …" + app id
(seguro: a única ação é trazer para frente). Mesmos ids de entrada: os botões já
no painel passam a usar o applet sem reconfigurar.
- Viraram **ícones** (a pasta aberta pinta o ícone na cor de destaque), e os três
  botões do painel — Imagens, Downloads, mostrar área de trabalho — **crescem no
  hover** (1,25× em 120 ms) em vez de tooltip (`cbffe575`, `f828820a`,
  `1fcddea6`). O hover vem dos eventos da própria superfície: a `mouse_area`
  nunca via a saída (o botão ocupa a superfície toda), ficava "em cima" e o
  efeito funcionava uma vez só (`a74aa75f`).
- Primeira instalação não pegou: cópias de teste antigas em
  `~/.local/share/applications` têm prioridade e mantinham o botão velho. O
  `install.sh` agora as move para `~/.local/state/pop-flow/old-desktop-entries`.

### ✅ Feito — **canto por hover** (06/10)
Repousar o ponteiro 600 ms no triângulo mostra a área de trabalho; uma vez por
visita, o clique continua valendo.

### ✅ Feito — **modo vampiro × modo dormir** (06/10)
`cosmic-applet-vampire`: morcego = só dorme quando você manda (inibe a tampa no
logind e zera a suspensão por inatividade do `cosmic-idle`, guardando os valores
antigos); lua = dorme normalmente. Detalhes em
[PLAN-acao-2026-10.md](PLAN-acao-2026-10.md).

### ✅ Feito — **Super+D mostra a área de trabalho** (06/10)
Atalho personalizado do COSMIC para `cosmic-applet-show-desktop --toggle`.

### ✅ Feito — **cantos genéricos** (`c5bd62cc`)
`cosmic-show-desktop-corner --corner <canto> --dwell-ms N --exec <comando>`:
qualquer canto, com qualquer ação. O canto superior esquerdo → overview está
instalado, mas desligado; o inferior esquerdo virou o segundo "mostrar área de
trabalho" na rodada de 21/10.

### ✅ Feito — **vampiro temporário** (`e8b7cdaa`, `8d354f6d`)
Morcego por **1 h / 3 h**, voltando sozinho a lua; aviso "tampa fechada, PC
acordado".

### ✅ Gestos de touchpad (G3) — no compositor
Implementados em `cosmic-comp` (`30bc899b`); instalados em 21/10.

### ✅ Feito e instalado — **terminais no painel** (16/10)
`cosmic-applet-terminals`: um ícone de terminal que **sempre abre um novo**, e
ao lado **uma bolinha por janela de terminal**, na cor da regra da pasta da aba
ativa (neutra quando a pasta não tem regra). A cor muda ao vivo no `cd` e na
troca de aba. Cada bolinha mantém a posição de quando abriu; clique traz a
janela para frente, **botão direito** abre um menu com *Trazer para frente* e
*Fechar janela*. Passou de 8, aparece `+N`. A cor vem do cosmic-term (T3), que
grava um arquivo por janela em `$XDG_RUNTIME_DIR/pop-flow/terminals/`; o applet
liga arquivo e janela pelo título. Plano em
[PLAN-applet-terminais.md](PLAN-applet-terminais.md).

### 💡 Ideias
- Preview com *live-switch* + clicável (provavelmente via `cosmic-comp`).
- Re-capturar periodicamente pra miniatura ficar "ao vivo" de verdade.

---

## Terminal — `cosmic-term/` (`NicoArgo/cosmic-term`)

O terminal do COSMIC. Fork criado **2026-08-03**, a partir do upstream 1.5.0
(`7daf10e`); tag-âncora `pre-popflow` no ponto de partida.

### ✅ Feito — **T1: aparência por diretório**
Cada pasta pode ter sua própria aparência, persistida de forma independente do
ajuste global e das outras pastas: **esquema de cores, transparência, título da
aba e a cor da pasta** (que desde `e28197e` também pinta o cursor). Aplica ao abrir o terminal **e ao vivo quando você dá
`cd`. Fonte e tamanho ficaram de fora da v1.

Modelo: uma lista de **regras** (`dir_rules`) separada dos perfis — perfil diz
_o que rodar_, regra diz _como aparecer_, e as duas coisas são ortogonais.
Precedência **regra > perfil > global**, campo a campo (todo campo é `Option`,
onde `None` = "herda").

**Uma regra vale para uma pasta, não para a árvore dela.** Cada diretório tem a
sua própria identidade e não a repassa: regra em `~/projetos` não diz nada sobre
`~/projetos/foo`, que segue com a aparência global até ganhar regra própria.
`include_subdirs: true` cobre a árvore, quando é isso que se quer.

Persiste em `~/.config/cosmic/com.system76.CosmicTerm/v1/dir_rules` — o
cosmic-config guarda **um arquivo por chave**, então a chave nova não exige
migração e versões antigas simplesmente a ignoram.

O plano completo (vistoria do código, fases, riscos) está em
[PLAN-term-cores-por-diretorio.md](PLAN-term-cores-por-diretorio.md).

_Estado: **T1 completa.** F0 (fork + docs), F1 (modelo `DirRule` + resolução
`cwd → regra`, `8b3fb87`), F2 (aparência por terminal, `f5672ae`), F3 (reagir ao
`cd`, `40a6a1b`), F6 antecipado (scripts de instalação, `c6e6ce8`) e F4 (a UI,
`70c00f8`). 38 testes passando. **Falta validar em uso real.**_

**Como usar:** botão direito no terminal → *Usar esta aparência aqui* fixa a
aparência atual na pasta em que você está. Depois, **Arquivo → Regras por
pasta...** para ajustar cores, transparência, título, a cor da pasta e se a
regra cobre a árvore. Cada campo pode ficar em "herdar" — é isso que mantém as pastas
independentes.

Editar `~/.config/cosmic/com.system76.CosmicTerm/v1/dir_rules` à mão continua
funcionando; o formato está no README do componente.

### ✅ Feito — **T2: cor e nome de identidade por pasta**

O T1 pinta o **conteúdo** do terminal. O T2 estende a mesma regra para tudo que
identifica *qual terminal é este*: o acento da interface, uma faixa no topo da
janela e a etiqueta da statusline do Claude Code.

O problema que ele resolve: hoje "esta pasta é a POP Flow, e a cor dela é esse
ciano" está escrito em **dois lugares independentes** — a regra do terminal e o
`.claude/statusline.sh`, que tem a cor fixa no script com um comentário mandando
trocar o RGB por projeto. Duas fontes de verdade para o mesmo fato.

**Um campo novo resolve os dois lados:** `accent: Option<HexColor>` na `DirRule` —
a cor daquela pasta, com um trabalho só. O `tab_title` que já existe passa a ser
também *o nome da sessão*. Interface e statusline consomem os dois; um lugar para
editar.

Decisões tomadas antes de codar:

- **Só o acento, não a janela inteira.** Header bar e menus mantêm o cinza do
  sistema; a cor da regra pinta aba ativa, foco, hover e botões de ação. Derivar
  fundos legíveis a partir de um hex qualquer é o tipo de coisa que quebra em
  cores claras ou saturadas, e o ganho não paga o risco.
- **A aba ativa manda.** Uma janela tem várias abas e um header só, então o
  acento segue o foco — mesma lógica que já governa o título.
- **O tema do usuário é preservado.** O acento é trocado sobre o `ThemeBuilder`
  do próprio usuário (lido do cosmic-config), não sobre o padrão. Quem
  customizou o tema não perde a customização ao usar uma regra.
- **`{title}` no `tab_title`.** Hoje o título da regra sobrescreve de forma dura
  o que o app emite — pôr um nome na pasta apagaria o título vivo do Claude
  Code. Com o placeholder (`POP FLOW — {title}`) dá para ter os dois, e quem não
  usa o placeholder mantém o comportamento de antes.

Viável porque **janela nova é processo novo** no cosmic-term (`Message::WindowNew`
dá `spawn` no próprio executável): o `set_theme` do libcosmic é por aplicação,
mas com um processo por janela isso equivale a um tema por janela.

A ponte com o Claude é `cosmic-term --resolve-rule <dir>`, que imprime
`RULE_NAME` / `RULE_ACCENT` / `RULE_ACCENT_RGB` e sai antes de subir a GUI. O
`statusline.sh` avalia a saída e cai nos valores fixos se o comando não existir —
assim ele continua funcionando em outro terminal ou via SSH.

**Uma armadilha que o `statusline.sh` teve que desarmar:** o cosmic-term de
fábrica *ignora* flags que não conhece e segue para abrir uma janela. Chamar
`--resolve-rule` num binário antigo abriria um terminal **a cada redesenho da
statusline**. Por isso o script sonda o `--help` uma vez e guarda a resposta até
o binário mudar — a sonda custa um spawn por instalação, não um por render.

_Estado: **T2 completa.** `accent` + `{title}` no modelo, `--resolve-rule`, tema
por aba ativa, faixa de identidade, campo na UI (pt-BR e en) e o `statusline.sh`
ligado à regra. **48 testes passando** (eram 38). Instalado; **falta validar em
uso** — em especial se a normalização de luminosidade do `with_accent` deixa a
faixa (hex literal) visivelmente diferente do acento da interface._

### ✅ Feito — **uma cor por pasta** (`e28197e`)
A cor do cursor e o acento da pasta eram dois campos, e o config real mostrava o
resultado: o mesmo hex digitado duas vezes em toda regra que usava os dois. Agora
é um campo só — `accent` pinta o acento da janela, a faixa, **o cursor do
terminal** e o que o `--resolve-rule` entrega para a statusline do Claude. Regras
antigas não perdem a cor: a chave `cursor` ainda é lida uma vez e dobrada no
`accent` na primeira abertura.

### ✅ Feito — **a regra é identidade, não um segundo tema** (`3467fc5`)
O diálogo perdeu os dois esquemas de cores e a transparência — quatro linhas de
ruído em volta dos dois campos que realmente se preenchem, e nenhuma regra do
config usava. As chaves continuam valendo se escritas à mão no arquivo (agora
documentadas como "só no arquivo"). *Usar esta aparência aqui* virou **Criar
regra para esta pasta**: cria, abre, e deixa nome e cor com você — congelar tema
e opacidade sem ter onde vê-los ou desfazê-los era pior que não ter a ação.
A lista mostra o **nome final da pasta, na cor dela**, no lugar do caminho; o
caminho inteiro segue no editor da regra.

A statusline do Claude (`.claude/statusline.sh`, fora do versionamento) perdeu o
último nome fixo: sem regra, o rótulo é o nome da pasta em maiúsculas — a mesma
derivação que o terminal usa na aba. Assim a etiqueta é sempre o título da aba,
e nada mais escreve "POP FLOW" dentro de outro projeto.

### ✅ Feito e instalado — **T3: cada janela diz ao painel a cor que está usando** (16/10)
Cada janela grava `$XDG_RUNTIME_DIR/pop-flow/terminals/<pid>` (`title=`, `name=`,
`accent=`) quando o título, a aba ou a regra mudam — é o que o applet de
terminais do painel lê. Escrita atômica, removida ao sair; arquivo de processo
morto é limpo pelo applet.

De quebra, **corrigido um bug do T1**: terminal aberto sem `--working-directory`
nascia com a regra da pasta e a perdia logo em seguida — a releitura da config
re-resolvia a regra a partir de uma pasta "ainda não lida". Agora o terminal
nasce sabendo a pasta inicial (a pedida, ou a do processo, que o shell herda).

### 📋 A validar em uso
- A decisão do blur (regra vence o alfa do tema) — a única escolha que não deu
  para conferir a olho. A aritmética tem teste; o julgamento visual não.

### 💡 Ideias
- Atalho de teclado para *Criar regra para esta pasta*.
- Indicador na aba de que a pasta tem regra.

**Decisão tomada no F2 (o ponto que o plano deixou em aberto):** com o blur do
COSMIC ligado, o tema substitui o alfa do painel — a transparência fixada numa
pasta não apareceria. Uma regra é uma escolha explícita sobre aquela pasta, então
ela **vence mesmo sob blur**; sem regra, o comportamento é idêntico ao de antes.
Isso está isolado em `terminal_opacity()`, com testes. **Falta validar a olho**
quando instalar.

### ✅ Feito — **desinstalar não pode virar downgrade**
O `cosmic-term.orig` desta máquina é **1.0.7** e o fork é 1.5.0: o backup foi
tomado antes do guard existir. Hoje é inofensivo, porque o pacote apt também
está em 1.0.7 — a armadilha é depois de um `apt upgrade`, quando o
`uninstall.sh` devolveria silenciosamente o 1.0.7. Ele agora compara a versão do
backup com a do pacote e **recusa**, apontando para
`sudo apt install --reinstall cosmic-term`, que é o original de verdade.

O `install.sh` já não mata terminais (não há `pkill` nele): `cosmic-term` não é
gerenciado pela sessão, então matá-lo fecharia as janelas abertas do usuário.

### 💡 Ideias
- Fonte e tamanho por pasta (cortado da v1 — mexe em métricas e tamanho de
  célula).
- OSC 7 no lugar de ler `/proc` (pega `cd` dentro de subprocesso, mas exige
  configurar o shell).
- Regra por glob (`~/projetos/*/prod`) em vez de só prefixo.
- Levar o conceito ao *Abrir no terminal* do `cosmic-files`, para a pasta já
  abrir com a aparência dela.

---

## Tema do papel de parede — `cosmic-wallsync/` (`NicoArgo/cosmic-wallsync`)

Componente próprio (não é fork): um binário de usuário + serviço systemd
`--user`. Não substitui nada do sistema, então dispensa `sudo`, `.orig` e hook
de APT — um update de pacote não tem o que reverter.

### ✅ Feito — **v1: o tema segue o papel de parede** (29/9)
- Destaque = o grupo mais colorido com ≥ 1% da imagem (k-means em Oklab), com
  luminosidade presa numa faixa legível por modo e croma dentro do sRGB. Fundo
  com um sopro do matiz da imagem; texto com o matiz do destaque. Papel de
  parede cinza não mexe no destaque.
- Grava como o *Configurações → Aparência*: só `accent`/`bg_color`/`text_tint`
  no builder, reconstrói o `Theme` e atualiza o CSS do GTK. Claro e escuro.
- `watch` reage à troca de papel de parede em < 1 s (testado ao vivo: gato na
  colina → azul `#5994e1`, auroras → roxo `#a27bdb`).
- `restore` devolve o tema de antes — verificado idêntico (builder byte a byte;
  tema derivado salvo arredondamento na 7ª casa).
- **Descoberta:** o sistema lê a config de tema `v1`; o libcosmic de 2026-07 em
  diante (usado pelos nossos forks) grava `v2`. Os forks leem `v1` como fallback
  enquanto `v2` estiver vazio — por isso o wallsync fica fixado na revisão do
  `cosmic-settings` 1.0.7 e grava só `v1`. Se algum fork um dia gravar tema em
  `v2`, ele passa a ignorar mudanças feitas pelo sistema.

### 💡 Ideias
- Slideshow: seguir a imagem da vez (o cosmic-bg não publica qual é; exigiria
  patch nele ou replicar a ordem de rotação).
- Um tema por monitor quando os papéis de parede diferem.
- Levar o destaque ao terminal: hoje a cor por pasta do `cosmic-term` sobrepõe
  o destaque na faixa do topo.

---

## Mostrar área de trabalho por tela — `cosmic-applets/` + `cosmic-settings/` (`NicoArgo/cosmic-settings`, branch `pop-flow`)

### ✅ Feito e instalado (06/10; Configurações em 21/10)
Contextual por padrão: cada tela tem seu triângulo e minimiza/restaura só as
próprias janelas; Super+D usa a tela da janela em foco; o botão do painel, a
tela do seu painel (`bdfcbcc4`, `0d767f49`). A escolha "só esta tela / todas"
fica em `com.popflow.ShowDesktop/v1/per_output` (padrão `true`): botão direito
no triângulo, `cosmic-applet-show-desktop --scope screen|all`, ou
**Configurações → Telas → Mostrar área de trabalho** (fork do cosmic-settings
`0e1ae88`, atualizado para o pacote 1.9.0 no merge `6c2eaad` e instalado em
21/10). O instalador do Settings recusa outra versão do pacote: a cada
atualização do COSMIC, trazer o código novo para o fork.

---

## Histórico da área de transferência — `cosmic-clipboard-history/` (`NicoArgo/cosmic-clipboard-history`)

### ✅ Feito — **Super+V** (06/10, `b9d8178`)
Serviço de usuário grava cópias de texto via `ext-data-control`; plugin do
pop-launcher (`cb `) lista, filtra e devolve. Sem sudo. Detalhes e o resto da
rodada em [PLAN-acao-2026-10.md](PLAN-acao-2026-10.md) ("Rodada 2").
CLI: `cosmic-clipboard-history list | copy N | clear | check`.

---

## Tela de boot — `cosmic-bootsplash/` (`NicoArgo/cosmic-bootsplash`)

### ✅ Feito (22/10) — **uma imagem do ligar até o login** (opcional)
Virou componente a tela de boot que estava só nesta máquina (ver
`ajustes-do-sistema/boot`). Ela tem três partes: o tema Plymouth `pop-flow`,
o serviço que pinta o framebuffer por cima do logo do fabricante e as opções
do kernel via kernelstub. Por padrão usa o papel de parede; aceita
`--image`/`--logo`/`--black`. No `install-all.sh`, a resposta padrão é não.
O `uninstall.sh` tira só as opções do kernel que ele mesmo adicionou.

---

## fastfetch — `cosmic-fastfetch/` (`NicoArgo/cosmic-fastfetch`)

### ✅ Feito (23/10) — **resumo do sistema nos terminais novos** (opcional)
Instala o fastfetch (do APT, ou o .deb das releases quando o APT não tem, como
no 24.04), escreve a config e põe um bloco marcado no `~/.bashrc`. Com
`--logo`, desenha a imagem com letras: cada célula recebe o caractere cuja
forma, na fonte do cosmic-term, mais se parece com aquele pedaço; a proporção
da célula sai de `ceil(1,4 × tamanho)` e da largura da fonte. Opções `--fill`,
`--crop`, `--circle`, `--invert`, `--by-light`, `--overlay`. No
`install-all.sh`, a resposta padrão é não.

---

## Referências (não modificadas)

- (nenhuma no momento — os clones de referência viraram componentes ativos.)

---

## Backlog da suíte (expansão)

Espaço para a visão de longo prazo — "ferramenta completa de facilitação de
usabilidade do Pop!_OS". Ideias ainda não atribuídas a um componente:

- 💡 Painel/Dock: menus de contexto e atalhos mais completos.
- 💡 Atalhos de teclado e navegação mais previsíveis entre apps/janelas.
- 💡 Configurações rápidas / quality-of-life que o COSMIC ainda não expõe.
- 💡 _(adicione as suas aqui)_

Ao promover uma ideia daqui para um componente: crie/forke o repo pelo padrão da
[ARCHITECTURE.md](ARCHITECTURE.md#2-fork-na-conta-do-autor-padrão-pop-flow),
adicione a entrada na seção do componente e atualize a tabela do
[README.md](README.md#componentes).
