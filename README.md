# POP Flow

**Uma suíte de melhorias de usabilidade para o Pop!_OS / COSMIC.**

POP Flow é um conjunto de forks e patches cirúrgicos sobre os componentes do
desktop COSMIC (o ambiente do Pop!_OS, da System76). O objetivo não é um app
isolado, e sim **uma ferramenta completa de facilitação de usabilidade do
Pop!_OS**: trazer ergonomia estilo Windows e melhorias de qualidade de vida
para o dia a dia — sem abandonar a estética e a base do COSMIC.

> Cada peça do desktop (launcher, gerenciador de arquivos, painel, compositor…)
> é um **binário e repositório próprios**. POP Flow é o guarda-chuva que reúne
> esses componentes e dá a eles uma direção comum.

---

## Componentes

| Componente | Repo (fork na conta) | Papel | Status |
|---|---|---|---|
| **Launcher** (`cosmic-launcher/`) | [`NicoArgo/POP-Flow`](https://github.com/NicoArgo/POP-Flow) | Alt+Tab com grade de miniaturas ao vivo, fechar janela, menu de contexto rico | 🟢 ativo, instalado |
| **Files** (`cosmic-files/`) | `NicoArgo/cosmic-files` (fork) | Gerenciador de arquivos — preview ampliado no hover (F1) | 🟢 F1 implementada |
| **Overview** (`cosmic-workspaces-epoch/`) | `NicoArgo/cosmic-workspaces-epoch` (fork) | Tela do Super (Task-View) — portar X de fechar / grade / preview | 🟡 iniciando |
| **Compositor** (`cosmic-comp/`) | `NicoArgo/cosmic-comp` (fork) | Snap/tiling de janelas estilo Windows (Aero-snap) | 🟡 iniciando (⚠ é o compositor) |
| **Barra de tarefas** (`cosmic-applets/`) | `NicoArgo/cosmic-applets` (fork) | Preview de janela ao passar o mouse no ícone da dock | 🟢 v1 implementada |

Veja o estado detalhado e o que vem a seguir em **[ROADMAP.md](ROADMAP.md)**.

## Filosofia

POP Flow segue princípios claros para se manter sustentável em cima de um
upstream vivo (o COSMIC ainda muda rápido). Os detalhes estão em
**[ARCHITECTURE.md](ARCHITECTURE.md)**, mas em resumo:

- **Um fork por componente**, cada um na conta do autor (backup + histórico na
  nuvem + espaço para PRs pro upstream).
- **Patches cirúrgicos e aditivos** — mudar o mínimo, preservar o caminho de
  comportamento do upstream, para facilitar rebase em versões novas do COSMIC.
- **Segurança primeiro** — ações destrutivas (fechar janela, etc.) miram o
  identificador exato, nunca heurística de título.
- **Lógica testável** — regras puras (layout de grade, correlação de
  miniaturas…) extraídas em funções livres com testes unitários.
- **Instalação reversível** — backup do binário original, cópia "golden" para
  reaplicar após updates do sistema, `uninstall.sh` restaura o estado.

## Como está organizado

```
Pop Flow/                      ← este workspace (o guarda-chuva da suíte)
├── README.md                  ← você está aqui
├── ARCHITECTURE.md            ← princípios e como adicionar um componente
├── ROADMAP.md                 ← feito / em andamento / planejado
├── .claude/                   ← config da sessão (statusline etc.)
├── cosmic-launcher/           ← fork: NicoArgo/POP-Flow  (o launcher)
├── cosmic-files/              ← fork: NicoArgo/cosmic-files
├── cosmic-comp/               ← clone de referência (upstream)
└── cosmic-workspaces-epoch/   ← clone de referência (upstream)
```

Cada componente tem seu próprio `README` e (quando aplicável) `install.sh` /
`uninstall.sh`. Este diretório-raiz documenta a **suíte** como um todo.

## Instalar

**Tudo de uma vez** (recomendado) — compila e instala todos os componentes com
uma só senha de `sudo`. Rode em um terminal real:

```bash
./install-all.sh
```

Ao final: o **launcher** (Alt+Tab) já fica ativo; o **gerenciador de arquivos** é
reiniciado (isso fecha as janelas abertas dele — reabra depois).

**Ou um componente por vez**, a partir da sua pasta:

```bash
cd cosmic-launcher && ./install.sh   # compila release, faz backup, instala, reinicia o launcher
```

> Cada `install.sh` de componente reinstala **apenas aquele** binário. O do
> launcher reinicia o Alt+Tab (não fecha janelas de apps); o do gerenciador de
> arquivos **não** mata o processo (você reabre para carregar o novo). Todos
> precisam de `sudo` (terminal real).

---

_POP Flow é um projeto pessoal de melhoria do Pop!_OS. Não é afiliado à
System76._
