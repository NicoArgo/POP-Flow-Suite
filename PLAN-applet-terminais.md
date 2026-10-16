# Plano — applet de terminais no painel

**Pedido:** na barra superior, um **botão que abre o terminal** e, ao lado dele,
**uma bolinha por terminal aberto**, na **cor da regra** da pasta em que aquele
terminal está.

**Componentes:** `cosmic-term/` (publica a identidade de cada janela) e
`cosmic-applets/` (applet novo `cosmic-applet-terminals`). O painel em si não muda.

---

## 1. O que já existe e a gente reaproveita

| Peça | Onde | Serve para |
|---|---|---|
| Cor por pasta (`DirRule.accent`) e nome (`tab_title`) | `cosmic-term`, T2 | É a "cor da regra" — fonte única |
| **Janela nova = processo novo** no cosmic-term | `Message::WindowNew` | Cada janela tem uma cor só (segue a aba ativa) |
| `active_dir_accent()` + `update_title()` | `cosmic-term/src/main.rs:1280`, `:1337` | Já sabem, ao vivo, a cor e o título da janela |
| Applet que acompanha janelas e traz para frente | `cosmic-applet-folder-button` (`wayland.rs`, `folder.rs`) | Molde: toplevel-info + toplevel-manager, ícone que cresce no hover |
| Instalação em `/usr/local`, sem auto-reapply | `cosmic-applets/install.sh` | Applet novo, nada a substituir |
| Botões adicionados ao painel com backup | `setup-desktop.sh` | Pôr o applet na ala esquerda |

## 2. O problema central: o applet não sabe a cor de cada janela

O protocolo de toplevel do COSMIC dá ao applet **app id + título** de cada
janela, mas não o pid nem a pasta. E a cor depende da pasta da **aba ativa**, que
só o próprio cosmic-term sabe.

**Decisão proposta: o cosmic-term publica, o applet só lê.**

Cada janela (processo) do cosmic-term mantém um arquivo:

```
$XDG_RUNTIME_DIR/pop-flow/terminals/<pid>.json
{ "title": "POP FLOW — claude", "name": "POP FLOW",
  "accent": "#2ec4d6", "cwd": "/home/nico/Área de trabalho/Pop Flow" }
```

- Escrito **só quando muda** (o mesmo ponto onde `applied_accent` e o título já
  são recalculados) — custo zero em repouso.
- `accent` ausente = pasta sem regra → bolinha neutra (cinza do tema).
- Apagado ao fechar a janela; se o processo morrer sem apagar, o applet descarta
  o arquivo cujo `/proc/<pid>` não existe mais.
- `$XDG_RUNTIME_DIR` é tmpfs por usuário: some no logout, nada a limpar.

**Ligar arquivo ↔ janela:** pelo `title` (que o próprio cosmic-term escreveu)
+ app id `com.system76.CosmicTerm`. É o mesmo raciocínio do folder-button: a
única ação é **trazer para frente**, então um empate de títulos no pior caso
foca o terminal irmão. Empate resolvido pela ordem de chegada.

**Alternativas descartadas:**
- Applet ler `dir_rules` e adivinhar a pasta pelo título → o título nem sempre
  tem a pasta (sem regra, o shell manda o que quiser).
- Applet varrer `/proc` atrás dos shells → acha o cwd, mas não sabe qual aba está
  ativa nem a qual janela o shell pertence.
- D-Bus por janela → mais peças (nome de serviço por pid, ciclo de vida) para o
  mesmo resultado que um arquivo.

## 3. Comportamento do applet

```
[ >_ ] ● ● ●
```

- **Botão `>_`**: abre um terminal novo, sempre (as bolinhas cuidam de voltar a
  um que já existe). Ícone `utilities-terminal-symbolic`, cresce 1,25× no hover
  como os outros botões da suíte.
- **Bolinhas**: uma por **janela** de terminal, na cor da regra da aba ativa
  dela; troca de cor ao vivo quando você dá `cd` ou muda de aba.
  - **Posição fixa** (ordem de abertura), como no Alt+Tab do launcher: focar um
    terminal não reordena as bolinhas.
  - **Clique**: traz aquela janela para frente (desminimiza / vai ao workspace).
  - **Janela focada**: bolinha com anel (ou um pouco maior).
  - **Hover**: cresce e mostra o nome da regra (ou o nome da pasta).
  - Muitas janelas: até **8** bolinhas, depois um `+N`.

## 4. Fases

### A0 — Preparação
1. Entrada no `ROADMAP.md` (Terminal **T3** e Barra de tarefas) **antes de codar**.
2. Confirmar se cosmic-term T2 já está instalado nesta máquina — o applet sem
   ele mostra só bolinhas neutras.

### A1 — cosmic-term publica a identidade (`cosmic-term/`)
- Módulo `src/presence.rs`: `struct Presence { title, name, accent, cwd }`,
  `write(&Presence)` atômico (arquivo temporário + `rename`) e `remove()`.
- Chamado de `update_accent()` / `update_title()` quando o resultado mudou;
  `remove()` na saída e em `Drop`.
- Teste: serialização e "não escreve se igual".
- Nada muda para quem não usa o applet.

### A2 — Lógica pura do applet (`cosmic-applets/cosmic-applet-terminals/`)
- `terminals.rs`: entra (janelas do toplevel + arquivos de presença), sai lista
  ordenada de bolinhas `{ handle, color, name, focused }`. Funções livres:
  `match_presence`, `stable_order`, `overflow`.
- Testes no padrão do `show_desktop.rs`: sem regra → neutro, empate de título,
  pid morto descartado, ordem fixa ao focar, `+N`.

### A3 — Applet com a interface
- Copiar a estrutura do folder-button: `wayland.rs` (toplevel-info/manager),
  `lib.rs` (iced), hover pela superfície (lição do `a74aa75f`).
- Observar `$XDG_RUNTIME_DIR/pop-flow/terminals/` com `inotify` (crate
  `notify`), sem polling.
- Desenho das bolinhas: `container` arredondado com a cor; anel na focada.

### A4 — Instalação e painel
- Entrada `com.popflow.CosmicAppletTerminals.desktop` em `data/`, binário via
  `cosmic-applets/install.sh` em `/usr/local`.
- `setup-desktop.sh`: inserir na ala esquerda após
  `com.popflow.CosmicAppletDownloadsFolder`, idempotente e com backup do
  `plugins_wings`.
- i18n `en` e `pt-BR`: `open-terminal`, `terminal-no-rule`, `more-terminals`.

### A5 — Validar em uso
- Abrir 3 terminais em pastas com e sem regra; `cd` entre elas; trocar de aba;
  minimizar e clicar na bolinha; fechar e matar com `kill -9` (o arquivo órfão
  tem de sumir da barra).
- Conferir com o tracker de memória que o applet não vaza (histórico do
  minimize/app-list).

## 5. Riscos

| Risco | Mitigação |
|---|---|
| Painel em `Custom(28)` deixa pouco espaço | Bolinhas de 8 px com 4 px de folga; limite de 8 + `+N` |
| Cor clara some no painel claro | Contorno de 1 px na cor do texto do painel |
| Título igual em duas janelas | Só traz para frente; empate pela ordem de chegada |
| cosmic-term de fábrica (sem A1) | Applet mostra bolinhas neutras para todas as janelas do app id — ainda útil |
| Upstream do cosmic-term muda o título | A ligação usa o título que o próprio fork gravou, não um formato fixo |

## 6. Esforço

| Fase | Esforço |
|---|---|
| A0 | baixo |
| A1 | baixo |
| A2 | médio |
| A3 | **maior parte** |
| A4 | baixo |
| A5 | precisa de olho |

**Primeiro marco testável:** fim de A1 — `ls $XDG_RUNTIME_DIR/pop-flow/terminals`
e `cat` dos arquivos já mostram a cor de cada janela mudando no `cd`.

## 7. Decidido (16/10)

1. **Uma bolinha por janela** — a aba ativa manda na cor.
2. **O botão sempre abre um terminal novo.**
3. **Botão direito na bolinha** abre um menu com *Trazer para frente* e *Fechar
   janela* (menu em vez de fechar direto: um clique errado não mata um terminal
   com coisa rodando).

**Ajustes feitos na implementação:**
- Formato do arquivo é `key=value` por linha, não JSON — três campos, nenhum
  lado precisa de parser. O arquivo se chama só `<pid>`.
- Sem `inotify`: a janela grava o arquivo **antes** de mudar o título, e toda
  mudança de título já chega ao applet pelo protocolo de janelas — então ele
  relê os arquivos junto. Um timer de 3 s cobre só a cor editada numa regra sem
  mudança de título.
- A cor no painel é o hex literal da regra; dentro do terminal o libcosmic
  normaliza a luminosidade do acento, então podem diferir um pouco.

## 8. Backlog
- 💡 Clique do meio na bolinha abre um terminal novo **naquela pasta**.
- 💡 Botão direito no `>_`: lista das pastas com regra, para abrir direto nelas.
- 💡 Mesma bolinha colorida nas miniaturas do Alt+Tab.
