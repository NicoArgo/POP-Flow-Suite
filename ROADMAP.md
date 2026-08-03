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
está** fecha — assim voltar para a raiz nunca destrói a árvore aberta. As
subpastas são listadas fora da thread de UI (`Message::NavExpanded`) e ficam em
cache; `App.nav_expanded` sobrevive às reconstruções do modelo. Liga/desliga em
**Exibir → Expandir pastas na barra lateral**.

### 📋 Planejado / a validar
- Validar em uso real; ajustar tamanhos/posições conforme feedback.
- Árvore: testar com pasta muito grande (o `column_sort` roda por frame).
- Barra lateral: sem chevron (limitação do `segmented_button`). Um chevron
  exigiria forkar o libcosmic — decidir se vale.

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

## Terminal — `cosmic-term/` (`NicoArgo/cosmic-term`)

O terminal do COSMIC. Fork criado **2026-08-03**, a partir do upstream 1.5.0
(`7daf10e`); tag-âncora `pre-popflow` no ponto de partida.

### 🚧 Em andamento — **T1: aparência por diretório**
Cada pasta pode ter sua própria aparência, persistida de forma independente do
ajuste global e das outras pastas: **esquema de cores, transparência, título da
aba e cor do cursor**. Aplica ao abrir o terminal **e ao vivo quando você dá
`cd`. Fonte e tamanho ficaram de fora da v1.

Modelo: uma lista de **regras** (`dir_rules`) separada dos perfis — perfil diz
_o que rodar_, regra diz _como aparecer_, e as duas coisas são ortogonais.
Precedência **regra > perfil > global**, campo a campo (todo campo é `Option`,
onde `None` = "herda"). Subpastas herdam, com o match mais longo vencendo.

Persiste em `~/.config/cosmic/com.system76.CosmicTerm/v1/dir_rules` — o
cosmic-config guarda **um arquivo por chave**, então a chave nova não exige
migração e versões antigas simplesmente a ignoram.

O plano completo (vistoria do código, fases, riscos) está em
[PLAN-term-cores-por-diretorio.md](PLAN-term-cores-por-diretorio.md).

_Estado: **F0** (fork + docs), **F1** (modelo `DirRule` + resolução `cwd → regra`,
`8b3fb87`), **F2** (aplicar a aparência por terminal, `f5672ae`) e **F3** (reagir
ao `cd`, `40a6a1b`) feitos. 32 testes passando. Próximo: **F4** — a interface._

**A feature já funciona de ponta a ponta**, editando as regras à mão. Com um
terminal aberto, escreva em
`~/.config/cosmic/com.system76.CosmicTerm/v1/dir_rules`:

```ron
{
    1: (path: "~/projetos", opacity: Some(85), syntax_theme_dark: Some("Dracula")),
    2: (path: "~/projetos/prod", tab_title: Some("PROD"), cursor: Some("#ff0000")),
}
```

O terminal reage na hora (o cosmic-config observa o arquivo) e ao `cd` entre as
pastas. Só falta a UI para não precisar editar arquivo.

**F6 antecipado** (`c6e6ce8`): os quatro scripts de instalação já existem, então
dá para instalar e usar de verdade antes de construir a UI. O `install.sh` avisa
se a versão do sistema não bate com a do fork — o backup que ele tira é o que o
`uninstall.sh` restaura depois. Formato das regras documentado no README do
componente.

**Decisão tomada no F2 (o ponto que o plano deixou em aberto):** com o blur do
COSMIC ligado, o tema substitui o alfa do painel — a transparência fixada numa
pasta não apareceria. Uma regra é uma escolha explícita sobre aquela pasta, então
ela **vence mesmo sob blur**; sem regra, o comportamento é idêntico ao de antes.
Isso está isolado em `terminal_opacity()`, com testes. **Falta validar a olho**
quando instalar.

### 📋 Planejado
- Instalar exige `apt upgrade cosmic-term` antes (sistema em 1.0.7, upstream em
  1.5.0) — senão o backup `.orig` guarda um binário de uma epoch anterior.
- ⚠ `cosmic-term` **não** é gerenciado pela sessão: dar `pkill` nele fecha os
  terminais abertos do usuário. O `install.sh` deve só avisar, como o do Files.

### 💡 Ideias
- Fonte e tamanho por pasta (cortado da v1 — mexe em métricas e tamanho de
  célula).
- OSC 7 no lugar de ler `/proc` (pega `cd` dentro de subprocesso, mas exige
  configurar o shell).
- Regra por glob (`~/projetos/*/prod`) em vez de só prefixo.
- Levar o conceito ao *Abrir no terminal* do `cosmic-files`, para a pasta já
  abrir com a aparência dela.

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
