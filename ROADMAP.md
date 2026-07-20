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
`grid_view` (Position::Top) e nas 3 variantes da `list_view` (Position::Right) —
lista é a view padrão. Commits `51ba475` (grade) + `fd2de78` (lista).

### ✅ Feito — **Barra lateral: "Abrir no terminal"**
O menu de botão-direito da barra lateral (locais/pastas) ganhou **"Abrir no
terminal"** para locais que são pasta, abrindo o terminal padrão naquela pasta.
Reusa a detecção de terminal (`mime_app_cache.terminal()`) e o `spawn_detached`
que o `cosmic-files` já usa no menu da área principal.

### 📋 Planejado / a validar
- Validar peek e "abrir no terminal" em uso real; ajustar tamanho/posição do peek.

### 💡 Ideias
- Flag em `TabConfig` (`peek_on_hover` / tamanho) para ligar/desligar/ajustar.
- Miniaturas maiores/ajustáveis; melhor densidade de grade.
- Mais itens na sidebar (copiar caminho, abrir em nova janela para arquivos…).

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
