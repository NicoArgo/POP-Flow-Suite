# Roadmap — POP Flow

Estado da suíte por componente. Legenda:
**✅ feito** · **🚧 em andamento** · **📋 planejado** · **💡 ideia (backlog)**

> Ao concluir um item, mova-o para "feito" com uma linha do que mudou. Ao pegar
> um novo, crie a entrada aqui **antes** de codar.

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
- **Agrupamento por app** preservando ordem de uso recente (MRU).
- **Grade adaptativa sem scroll**: expande em colunas/linhas e **encolhe as
  miniaturas** para caber na tela, em vez de rolar.
- **Menu de botão-direito enriquecido**: mescla ações do launcher — *Abrir no
  terminal*, *Abrir pasta*, *Copiar caminho* (para resultados com caminho de
  arquivo) — com as opções do pop-launcher.
- **Auto-reapply** após updates de pacote; `install.sh` / `uninstall.sh` / README.

### 📋 Planejado / a validar
- Validar em uso real o menu de contexto (o plugin de arquivos do pop-launcher
  realmente expõe o caminho? senão, ajustar a extração em `result_path`).
- Ajuste fino do tamanho das miniaturas em telas/contagens variadas.

### 💡 Ideias
- "Abrir no terminal" também para apps/resultados sem caminho (abrir na home).
- Pré-visualização maior ao focar (peek), como no Files (ver F1).
- Ações extras por tipo de janela (mover para workspace, etc.).

---

## Files — `cosmic-files/` (`NicoArgo/cosmic-files`)

Gerenciador de arquivos do COSMIC. Fork recém-criado, pronto para trabalho.

### ✅ Feito — **F1: preview maior no hover** (grade + lista)
Ao passar o mouse sobre o ícone de um arquivo, um tooltip mostra uma versão
ampliada (~240px) da miniatura — só para imagens/SVGs, reusando o handle já em
cache (sem regenerar). Via `Item::hover_peek()` + `Item::peek_wrap()` na
`grid_view` e nas 3 variantes da `list_view`, com `Position::FollowCursor` (o
preview segue o cursor). Commits `51ba475` (grade) + `fd2de78` (lista) +
`d19a5f5` (segue o cursor).

### ✅ Feito — **Barra lateral: "Abrir no terminal"**
O menu de botão-direito da barra lateral (locais/pastas) ganhou **"Abrir no
terminal"** para locais que são pasta, abrindo o terminal padrão naquela pasta.
Reusa a detecção de terminal (`mime_app_cache.terminal()`) e o `spawn_detached`
que o `cosmic-files` já usa no menu da área principal. Commit `59f37b8`.

### ✅ Feito — **Miniatura no modal de renomear**
Ao renomear uma **imagem**, o modal mostra um preview dela (~288px, um pouco
maior que o do hover) acima do campo de nome. Só para arquivos de imagem.
Commit `8eeeeed`.

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

### 📋 Planejado / a validar
- Validar em uso real; ajustar tamanhos/posições conforme feedback.
- Árvore: testar com pasta muito grande (o `column_sort` roda por frame).

### 💡 Ideias
- Flag em `TabConfig` (`peek_on_hover` / tamanho) para ligar/desligar/ajustar.
- Miniaturas maiores/ajustáveis; melhor densidade de grade.
- Mais itens na sidebar (copiar caminho, abrir em nova janela para arquivos…).
- Árvore: "recolher tudo", animação de abertura, persistir entre sessões.

---

## Overview do Super — `cosmic-workspaces-epoch/` (`NicoArgo/cosmic-workspaces-epoch`)

A tela de Task-View (tecla Super). Fork criado 2026-07-20.

### 🚧 Em andamento — portar melhorias do launcher
- **Botão X de fechar** por miniatura de janela (reusa o padrão do launcher).
- Depois: grade adaptativa / preview no hover, conforme fizer sentido aqui.
_Explorando onde as miniaturas de janela e o fechamento (toplevel-management)
são feitos._

---

## Compositor — `cosmic-comp/` (`NicoArgo/cosmic-comp`)

⚠ **É o compositor** — mudanças aqui, se quebrarem, derrubam a sessão; testar
exige reiniciar o compositor/sessão. Mudanças cirúrgicas e muito cuidado.

### 🚧 Em andamento — **snap de bordas (Aero-snap)**
Arrastar a janela para uma borda/canto da tela → encaixar em metade/quarto/
maximizar. _Explorando onde o move-grab e a geometria de janela vivem, e o
risco/forma de testar._

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

### 💡 Ideias
- Preview com *live-switch* + clicável (provavelmente via `cosmic-comp`).
- Re-capturar periodicamente pra miniatura ficar "ao vivo" de verdade.

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
