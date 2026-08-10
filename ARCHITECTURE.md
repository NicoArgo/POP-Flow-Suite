# Arquitetura & Filosofia — POP Flow

Este documento explica **como** POP Flow é construído e **por quê** dessa forma.
A meta é evoluir uma suíte de melhorias de usabilidade em cima do COSMIC (um
upstream que ainda muda rápido) sem virar uma bola de neve impossível de manter.

---

## 1. Um fork por componente

O desktop COSMIC não é um programa só. Cada peça é um **processo e repositório
separados**: o launcher (`cosmic-launcher`), o gerenciador de arquivos
(`cosmic-files`), o painel (`cosmic-panel`), o compositor (`cosmic-comp`), as
configurações (`cosmic-settings`)…

Logo, POP Flow **não** é um repositório único. É:

- **um workspace guarda-chuva** (esta pasta) que reúne os componentes e a
  documentação da suíte;
- **um fork por componente**, cada um clonado aqui como um subdiretório.

Não misture mudança de um componente no repo de outro — eles compilam e
instalam como binários distintos.

## 2. Fork na conta do autor (padrão "POP-Flow")

Todo componente que vamos modificar é **forkado para a conta do autor** (não só
clonado do upstream). Assim há backup e histórico na nuvem, e a porta fica
aberta para PRs de volta ao upstream.

```bash
# Padrão para adicionar um novo componente à suíte:
cd "Pop Flow"
gh repo fork pop-os/<componente> --clone --default-branch-only
# → cria NicoArgo/<componente>, clona aqui, e configura:
#     origin   = NicoArgo/<componente>   (seu fork — dá push)
#     upstream = pop-os/<componente>     (para acompanhar o upstream)
```

Componentes usados **só como referência** (não modificados) podem ser clones do
upstream — hoje `cosmic-workspaces-epoch/`. Um clone de referência vira fork no
dia em que recebe o primeiro patch: o `cosmic-comp/` fez essa travessia quando
ganhou os gestos de três dedos.

> Nota: o launcher vive em `NicoArgo/POP-Flow` (fork renomeado de
> `cosmic-launcher`). Novos forks mantêm o nome do upstream por padrão; renomear
> para uma marca "POP-Flow-*" é opcional e feito no GitHub.

## 3. Patches cirúrgicos e aditivos

O COSMIC ainda lança versões novas com frequência. Para conseguir acompanhar:

- **Mude o mínimo.** Prefira adicionar caminhos novos a reescrever os
  existentes. Preserve o comportamento do upstream como fallback.
- **Nada de regressão silenciosa.** Recursos são aditivos e degradam com
  elegância (ex.: se o tamanho da tela ainda não chegou, a grade usa um padrão).
- **Comente o _porquê_**, no idioma e densidade do código ao redor.

## 4. Segurança primeiro na UX

Ações destrutivas miram o **identificador exato**, nunca heurística de texto:

- Fechar janela vai por `pop_launcher::Request::Quit(id)` — a id exata da
  janela, então **nunca** fecha uma parecida.
- A correlação título↔miniatura é apenas cosmética (qual imagem desenhar); ela
  nunca decide sobre qual janela agir.

## 5. Lógica pura e testável

Regras de decisão são extraídas em **funções livres** e cobertas por testes
unitários, isoladas da camada de UI/wayland. Exemplos no launcher:
`grid_layout` (colunas + escala da grade), `assign_thumbs` (correlação 1:1),
`group_by_app` (agrupamento por app), `result_path`/`sh_quote` (menu de
contexto). Rode com `cargo test --bins`.

## 6. Modelo de instalação (reversível)

Cada componente modificável traz `install.sh` / `uninstall.sh` /
`setup-auto-reapply.sh` / `remove-auto-reapply.sh` no mesmo molde do launcher —
os quatro, sem exceção. Um componente sem os dois últimos é revertido pelo
próximo `apt upgrade` **sem aviso nenhum**, que é o pior modo de falha possível:
a feature some e nada indica por quê.

1. `cargo build --release`
2. Backup do binário atual do sistema → `<componente>.orig` (uma vez)
3. `sudo install` do binário novo em `/usr/bin/<componente>`
4. Atualiza a **golden copy** em `/usr/local/lib/pop-flow/<componente>`
5. `pkill -x <componente>` → o COSMIC respawna com a versão nova

Pontos-chave:

- **Reinicia só aquele componente** — não fecha janelas de aplicativos.
- **`sudo` exige terminal real** (o prefixo `!` da sessão não tem TTY).
- **Auto-reapply:** `setup-auto-reapply.sh` instala a golden copy mais um hook
  `DPkg::Post-Invoke` que reaplica nossa build sempre que o binário do sistema
  diverge dela. O script é o mesmo nos três componentes — só o bloco de
  variáveis do topo (`COMP`/`BUILT`/`RELOAD`) muda. `install-all.sh` roda isso
  para todo componente que instala.
- **Alvos que são symlink** (ex.: `/usr/bin/cosmic-app-list` aponta para o
  binário multiplexado `cosmic-applets`): `cmp` segue o link, então a restauração
  do symlink pelo dpkg conta como divergência e dispara o reapply. E `install`
  desvincula o destino antes de copiar, então trocar o symlink por um arquivo
  **não** sobrescreve o binário multiplexado.
- **Reversível:** `uninstall.sh` restaura o `.orig`. Um backup do binário
  original de fábrica é preservado no workspace — não apague sem confirmar.

## 7. Internacionalização

Strings ficam em Fluent (`i18n/<locale>/*.ftl`), sempre com **en** e **pt-BR**.
Toda string visível ao usuário passa por `fl!("chave")`.

## 8. Especificidades COSMIC / Wayland

Conhecimento acumulado (para não redescobrir):

- **Miniaturas ao vivo:** `wlr/cosmic screencopy` + `toplevel-info` numa thread
  wayland dedicada; capturas são reduzidas e enviadas por canal.
- **Fechar janelas / ações:** via pop-launcher (`Quit`, `ActivateContext`),
  não pelo protocolo de toplevel-management (evita correlação frágil).
- **Tamanho da tela:** eventos `OutputEvent` do iced (`logical_size`) — usados
  pela grade adaptativa.
- **Overlaps de painel/dock:** `overlap_notify` para calcular margem segura.
- **Referência canônica** de screencopy/toplevel: `cosmic-workspaces-epoch/`.

## 9. Receita: adicionar um novo componente à suíte

1. `gh repo fork pop-os/<componente> --clone --default-branch-only` (seção 2).
2. Identificar o menor ponto de mudança; manter o patch cirúrgico (seção 3).
3. Extrair a lógica de decisão em funções livres + testes (seção 5).
4. Adicionar `install.sh`/`uninstall.sh` no molde do launcher (seção 6).
5. Strings em en + pt-BR (seção 7).
6. Registrar em [ROADMAP.md](ROADMAP.md) e na tabela do [README.md](README.md).
