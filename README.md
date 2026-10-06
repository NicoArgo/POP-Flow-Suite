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

| Componente | Repo | O que traz |
|---|---|---|
| **Alt+Tab** (`cosmic-launcher/`) | [`NicoArgo/POP-Flow`](https://github.com/NicoArgo/POP-Flow) | Grade de miniaturas ao vivo que sempre cabe na tela, janela em foco ampliada (peek), X para fechar, posições fixas, menu de contexto com *Abrir no terminal / Abrir pasta / Copiar caminho* |
| **Files** (`cosmic-files/`) | [`NicoArgo/cosmic-files`](https://github.com/NicoArgo/cosmic-files) | Prévia ampliada no hover, pastas expansíveis (lista e barra lateral), cada pasta lembra lista/grade, **pastas na cor da regra**, *Regra da pasta…* no botão direito, *Copiar caminho* sempre visível, área de trabalho livre (arrastar para qualquer célula, rolagem) |
| **Painel** (`cosmic-applets/`) | [`NicoArgo/cosmic-applets`](https://github.com/NicoArgo/cosmic-applets) | Prévia da janela no hover da barra de tarefas; **mostrar área de trabalho** por tela (botão, Super+D, triângulo no canto por clique ou hover); botões Imagens/Downloads; **modo vampiro** (o PC só dorme quando você manda; 1 h / 3 h; aviso ao fechar a tampa); cantos ativos configuráveis |
| **Terminal** (`cosmic-term/`) | [`NicoArgo/cosmic-term`](https://github.com/NicoArgo/cosmic-term) | Identidade por pasta: nome e **uma cor** na aba, no acento, na faixa do topo e no cursor; `--set-rule` / `--remove-rule` para outros apps |
| **Histórico da área de transferência** (`cosmic-clipboard-history/`) | [`NicoArgo/cosmic-clipboard-history`](https://github.com/NicoArgo/cosmic-clipboard-history) | **Super+V**: lista o que você copiou (texto), filtra, Enter devolve — sem sudo |
| **Tema do papel de parede** (`cosmic-wallsync/`) | [`NicoArgo/cosmic-wallsync`](https://github.com/NicoArgo/cosmic-wallsync) | Acento, fundo e texto do tema seguem o papel de parede |
| **Overview** (`cosmic-workspaces-epoch/`) — opcional | [`NicoArgo/cosmic-workspaces-epoch`](https://github.com/NicoArgo/cosmic-workspaces-epoch) | X ao passar o mouse em cada janela da tela do Super. Exige COSMIC atualizado (o instalador confere) |
| **Configurações** (`cosmic-settings/`) — opcional | [`NicoArgo/cosmic-settings`](https://github.com/NicoArgo/cosmic-settings) (branch `pop-flow`) | *Telas → Mostrar área de trabalho*: só a tela onde foi acionado / todas. Precisa de `libpipewire-0.3-dev` e `libclang-dev` para compilar |
| **Compositor** (`cosmic-comp/`) — opcional | [`NicoArgo/cosmic-comp`](https://github.com/NicoArgo/cosmic-comp) | Gestos de três dedos. ⚠ É o compositor: pede `yes`, vale no próximo login |

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
├── cosmic-applets/            ← fork: NicoArgo/cosmic-applets
├── cosmic-term/               ← fork: NicoArgo/cosmic-term
├── cosmic-comp/               ← fork: NicoArgo/cosmic-comp  (o compositor)
├── cosmic-wallsync/           ← próprio: NicoArgo/cosmic-wallsync (tema ← papel de parede)
├── cosmic-clipboard-history/  ← próprio: NicoArgo/cosmic-clipboard-history (Super+V)
├── cosmic-workspaces-epoch/   ← fork: NicoArgo/cosmic-workspaces-epoch (Overview)
├── cosmic-settings/           ← fork: NicoArgo/cosmic-settings (branch pop-flow)
├── install-all.sh             ← instala tudo
└── setup-desktop.sh           ← põe os botões no painel e os atalhos (Super+D, Super+V)
```

Cada componente tem seu próprio `README` e (quando aplicável) `install.sh` /
`uninstall.sh`. Este diretório-raiz documenta a **suíte** como um todo.

## Instalar

**Tudo de uma vez** (recomendado), num Pop!_OS com COSMIC. Rode em um terminal
real — pede a senha de `sudo` uma vez só:

```bash
git clone https://github.com/NicoArgo/POP-Flow-Suite.git
cd POP-Flow-Suite
./install-all.sh
```

O script:

1. confere a versão do COSMIC (testado na **1.0.7**; em outra, pergunta antes
   de seguir — `POP_FLOW_YES=1` pula a pergunta);
2. instala as dependências de compilação que faltarem (inclusive Rust, se não
   houver nenhum);
3. **clona os componentes** que ainda não estão na pasta — cada um mora no seu
   repo (tabela acima); os que já estão são usados como estão;
4. compila e instala cada um;
5. por último, o **compositor** (gestos de três dedos) — só se você digitar
   `yes` na pergunta dele. Recusar pula só ele. Ele entra no **próximo login**;
   se a sessão não voltar: Ctrl+Alt+F3 → `cd …/cosmic-comp` → `./uninstall.sh`
   → reiniciar.

Ao final: o **launcher** (Alt+Tab) e o **triângulo** do canto inferior direito já
funcionam; o **gerenciador de arquivos** é reiniciado (isso fecha as janelas
abertas dele — reabra depois). No fim ele roda o **`setup-desktop.sh`**
(pergunta antes): põe os botões no painel — mostrar área de trabalho, Imagens,
Downloads e o modo vampiro — e cria os atalhos **Super+D** (área de trabalho)
e **Super+V** (histórico). Faz backup do que muda, não duplica nada se rodar de
novo e não toma uma tecla que já esteja em uso. Pode ser rodado sozinho.

O **modo vampiro** vem desligado: clique no morcego/lua no painel para escolher.

- **Aparência por pasta** no terminal: abra um terminal **novo** e crie uma
  regra para uma pasta; o gerenciador de arquivos passa a mostrar a pasta na cor
  da regra.

O script também instala, para cada componente, um hook de APT que **reaplica** a
build do POP Flow depois de um update de pacote — sem isso, um `apt upgrade`
restaura o binário de fábrica e a feature some sem avisar. Para desfazer só o
hook de um componente: `cd <componente> && ./remove-auto-reapply.sh`.

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
