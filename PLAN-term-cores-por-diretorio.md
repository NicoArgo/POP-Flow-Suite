# Plano — Aparência do terminal por diretório

**Objetivo:** cada pasta pode ter sua própria aparência de terminal (esquema de
cores, transparência, e afins), persistida de forma independente do ajuste
global e das outras pastas. Ao abrir um terminal numa pasta — ou ao `cd` para
ela — a aparência daquela pasta é aplicada.

**Alvo:** `cosmic-term` (o terminal do COSMIC, já instalado e padrão do sistema).
Novo componente da suíte — hoje ele **não** está no workspace.

---

## 1. Vistoria — o que existe hoje

### 1.1 Estado do workspace

- `cosmic-term/` **não existe** aqui. Componentes atuais: `cosmic-launcher`,
  `cosmic-files`, `cosmic-applets`, `cosmic-comp`, `cosmic-workspaces-epoch`.
  → Precisa de fork, pelo padrão da [ARCHITECTURE.md §2](ARCHITECTURE.md).
- ⚠ **Pendência aberta:** `cosmic-launcher` está **no meio de um `git merge
  upstream/master`** (`Cargo.toml` e `src/app.rs` em conflito). Ver
  [HANDOFF-sync-upstream.md](HANDOFF-sync-upstream.md). Não bloqueia este
  trabalho (repo diferente), mas **não rodar `git merge --abort`** por engano.

### 1.2 Versão instalada × upstream

| | versão |
|---|---|
| instalado no sistema | `1.0.7~1771870462` |
| candidato no apt | `1.5.0~1785342063` |
| upstream `master` (hoje) | `1.5.0` (commit `7daf10e`, 2026-07-29) |

O sistema está **uma epoch atrás**. Fazer `apt upgrade` do `cosmic-term` **antes**
de forkar/instalar, senão o backup `.orig` guarda um binário 1.0.7 e a nossa
build 1.5.0 fica muito à frente do resto do desktop.

### 1.3 Como o cosmic-term guarda config hoje

`cosmic-config`, **um arquivo por chave** em
`~/.config/cosmic/com.system76.CosmicTerm/v1/`. Hoje, aqui:
`show_headerbar`, `opacity` (97), `focus_follow_mouse`, `font_size` (15),
`font_name` ("Fira Mono"). Só o que difere do padrão é escrito.

Isso é ótimo para nós: **acrescentar uma chave nova é compatível nos dois
sentidos** — versão antiga ignora o arquivo extra, versão nova usa o default
quando o arquivo não existe. Nenhuma migração necessária.

### 1.4 O que já está pronto e joga a favor

Achados no código (`src/config.rs`, `src/main.rs`, `src/terminal.rs`):

1. **`Terminal::working_directory()`** (`terminal.rs:446`) já lê
   `/proc/<shell_pid>/cwd`. O cwd por terminal já é obtível, barato (um
   `readlink`), sem precisar de integração de shell.
2. **Cores já são por terminal.** Cada `Terminal` tem seu próprio array
   `colors: Colors` (`terminal.rs:253`) e um `profile_id_opt`. Dois painéis lado
   a lado já podem ter esquemas diferentes.
3. **Cores já trocam ao vivo.** `Terminal::set_config()` (`terminal.rs:~688`)
   compara e substitui as cores em tempo de execução, sem recriar o terminal.
4. **A opacidade já é aplicada por widget**, não pela janela:
   `terminal_box(...).opacity(...)` em `main.rs:3509`. Hoje o valor vem do
   global `self.config.opacity_ratio()` — trocar por um valor por terminal é uma
   linha.
5. **Perfis já existem** (`Profile`: nome, comando, `syntax_theme_dark/light`,
   `working_directory`, `tab_title`) e já resolvem tema por perfil em
   `Config::syntax_theme(kind, profile_id)`.
6. **Página de contexto** é um padrão estabelecido (`ContextPage::Profiles`,
   `::ColorSchemes`, `main.rs:3345+`) — cabe uma página nova sem inventar UI.
7. `i18n/pt-BR/cosmic_term.ftl` já existe.

### 1.5 O que falta (o trabalho de verdade)

- **`opacity` é global** (`Config.opacity: u8`) — não existe por perfil nem por
  terminal.
- **Nada reage ao `cd`.** `working_directory()` só é chamado ao abrir uma aba
  nova com "herdar diretório". Nenhum caminho de código observa mudança de cwd.
- **Não existe vínculo diretório → aparência.** `Profile.working_directory` é o
  contrário do que queremos: define onde o perfil *abre*, não qual perfil se
  aplica *a partir* de onde você está.
- **OSC 7 não está plumbado** (só OSC 8 / hyperlinks, em `terminal_box.rs`) — ou
  seja, o caminho "shell avisa o terminal que mudou de pasta" não existe hoje.

---

## 2. Decisões de projeto

> **Travadas em 2026-08-03:** regras por diretório (§2.1) · **uma regra = uma
> pasta**, sem herança; árvore é opt-in (§2.2, revisto no uso) · aplica ao abrir
> **e** ao vivo no `cd` (§2.3) ·
> escopo = **cor + transparência + título da aba/cursor**; fonte e tamanho
> **ficam de fora** (§2.5).

### 2.1 Modelo de correspondência — **decidido: regras por diretório**

Uma lista nova de **regras**, independente dos perfis:

```
regra = { caminho, cobre_arvore (opt-in), ativa, cores_dark, cores_light, opacidade, … }
```

Por quê não reaproveitar `Profile`: perfil carrega comando, título e diretório de
abertura; misturar "o que rodar" com "como aparecer" faz o usuário criar perfis
fantasma só para pintar uma pasta. Regras ficam ortogonais — funcionam com
qualquer perfil, inclusive sem nenhum.

**Precedência:** regra de diretório > perfil > global. Cada campo é
`Option<_>`: a regra só sobrescreve o que ela define, o resto cai para o perfil
e depois para o global. É isso que faz "persistir de forma independente" — mexer
no global continua valendo para todas as pastas sem regra.

**Alternativa considerada e descartada:** arquivo `.cosmic-term.toml` dentro da
própria pasta (estilo `.editorconfig`). Vantagem: a config viaja junto com a
pasta. Problema: qualquer repositório clonado passa a mudar a aparência do seu
terminal — é só cosmético, mas é entrada não confiável, e exigiria allowlist ou
confirmação. Fica como ideia futura, não como base.

### 2.2 Herança de subpastas — **revisto: uma regra = uma pasta**

> Esta seção mudou depois do F6, no uso real. A decisão original era herdar por
> padrão; ficou registrado o porquê da troca.

**Cada pasta tem a sua própria identidade e não a repassa.** Regra em
`~/projetos` não diz nada sobre `~/projetos/foo`, que segue com a aparência
global até ganhar regra própria. Cobrir uma árvore inteira continua possível,
via `include_subdirs: true` na regra, mas é **opt-in**.

A decisão anterior (herdar por padrão) partia de "ninguém quer marcar pasta por
pasta". Mas herdar significa que pintar uma pasta repinta silenciosamente tudo
que está embaixo dela — e o propósito da feature é justamente dar identidade a
uma pasta específica.

Comparação **por componente de caminho** (`/home/nico/ab` não casa com a regra
`/home/nico/a`). Quando duas regras alcançam o mesmo diretório — só possível
quando alguma optou por cobrir a árvore — vence a mais específica: a regra da
própria pasta ganha da árvore que desce até ela.

### 2.3 Quando aplica — **decidido: ao abrir e ao vivo no `cd`**

Só-ao-abrir é mais simples, mas frustra: você abre na home, `cd` para o projeto
e continua com a cara errada. Ao vivo é o comportamento que o pedido descreve.

### 2.4 Onde persiste

`~/.config/cosmic/com.system76.CosmicTerm/v1/dir_rules` — uma chave nova no
mesmo store (§1.3). Um arquivo, editável à mão, versionável, e sem migração.

### 2.5 Escopo de uma regra — **decidido**

| Propriedade | v1 | Observação |
|---|---|---|
| Esquema de cores (dark/light) | ✅ | Já é por terminal no código — parte barata |
| Transparência (opacidade) | ✅ | Já aplicada por widget; ver ressalva do blur em F2 |
| Título da aba | ✅ | Precisa conviver com o título que o shell manda — ver F4 |
| Cor do cursor | ✅ | Sobrepõe um índice do array de cores já resolvido |
| Fonte / tamanho | ❌ | **Fora da v1** — mexe em métricas e força recálculo do tamanho de célula do terminal. Fica no backlog |

---

## 3. Plano de execução

### F0 — Preparação

1. `apt upgrade cosmic-term` para 1.5.0 (§1.2).
2. `gh repo fork pop-os/cosmic-term --clone --default-branch-only` na raiz do
   workspace → `origin=NicoArgo/cosmic-term`, `upstream=pop-os/cosmic-term`.
3. Tag-âncora `pre-popflow` no ponto de partida (mesmo padrão do sync atual).
4. Entrada no [ROADMAP.md](ROADMAP.md) **antes de codar** (regra da própria
   ROADMAP) e linha na tabela do [README.md](README.md).

### F1 — Modelo de dados + resolução (lógica pura, sem UI)

Em `src/config.rs`:

```rust
#[serde(transparent)] pub struct DirRuleId(pub u64);

pub struct DirRule {
    pub path: String,               // absoluto; "~" expandido na leitura
    pub include_subdirs: bool,      // default true
    pub enabled: bool,              // default true
    #[serde(default)] pub syntax_theme_dark: Option<String>,
    #[serde(default)] pub syntax_theme_light: Option<String>,
    #[serde(default)] pub opacity: Option<u8>,
    #[serde(default)] pub tab_title: Option<String>,
    #[serde(default)] pub cursor: Option<HexColor>,   // hex_color já é dep
}

// em Config:
pub dir_rules: BTreeMap<DirRuleId, DirRule>,   // BTreeMap, igual profiles
```

Todo campo de aparência é `Option<_>`: **`None` = "não opino, herda"**. É isso
que mantém as pastas independentes entre si e do global.

Duas **funções livres testáveis** ([ARCHITECTURE §5](ARCHITECTURE.md)):

- `resolve_dir_rule(&rules, cwd) -> Option<DirRuleId>` — ignora desativadas,
  casa por componente; normalmente é a regra do caminho exato, e entre regras
  que cobrem árvore vence a mais específica.
- `effective_appearance(&config, kind, profile_id, dir_rule_id) -> Appearance`
  — aplica a precedência da §2.1 e devolve
  `{ syntax_theme: String, opacity: u8, tab_title: Option<String>, cursor: Option<HexColor> }`.

Testes: exato × prefixo, `/a` não casa `/ab`, regra desativada, aninhamento de
3 níveis, regra sem opacidade cai no global, regra com cor mas sem título não
mexe no título, `~` expandido, caminho inexistente.

**Nesta fase o app compila e roda idêntico** — nada consome as regras ainda.

### F2 — Aplicar a aparência por terminal

- `Terminal` ganha `dir_rule_id_opt: Option<DirRuleId>`.
- `Terminal::set_config()` passa a resolver o tema por
  `effective_appearance(...)` em vez de `config.syntax_theme(kind, profile_id)`.
  As cores já trocam ao vivo (§1.4.3) — nada mais a fazer para cor.
- **Cursor:** depois de copiar o esquema para `self.colors`, sobrescrever
  `colors[NamedColor::Cursor]` quando a regra define cor de cursor. Um índice do
  array que já existe — não precisa de esquema de cores novo.
- `Terminal::effective_opacity(&config) -> f32` novo; `main.rs:3509` passa a
  usar isso no lugar de `self.config.opacity_ratio()`.
- Na criação do terminal (`create_and_focus_new_terminal`, `main.rs:1553`),
  resolver a regra a partir do diretório inicial já conhecido.

⚠ **Ressalva do blur:** em `main.rs:3509`, quando o tema COSMIC está em modo
transparente/fosco, a opacidade do terminal é **substituída** por
`alpha_map.blurred_alpha(frosted)`. Com blur ligado, opacidade por pasta não
aparece. Decidir: (a) deixar como está e documentar, ou (b) multiplicar
`blurred_alpha × (opacidade da regra / global)` para a regra ainda pesar. Testar
com blur ligado e desligado antes de escolher.

### F3 — Detectar o `cd` ao vivo

`TermEvent::Wakeup` (`main.rs:3144`) já chega a cada saída do terminal —
inclusive quando o shell imprime o prompt depois do `cd`. É o gancho natural:

- `Terminal` ganha `cwd_cache: Option<PathBuf>` + `cwd_checked_at: Instant`.
- No `Wakeup`, com **throttle** (~200 ms), chamar `working_directory()`; se o
  caminho mudou, re-resolver a regra; se a regra mudou, `set_config()`.
- Custo em repouso: **zero** (é orientado a evento, sem timer).

Limitações a documentar: só Linux (`/proc`); é o cwd do **shell**, então
`cd /x && vim` não muda a pasta vista; um comando que só imprime não dispara
reavaliação (mas o prompt seguinte dispara).

_Refinamento futuro:_ OSC 7 (o shell anuncia a pasta) — mais preciso, mas exige
plumbing novo no parser e configuração de shell do usuário. Não é o caminho da
v1.

### F4 — Interface

Dois pontos de entrada, um rápido e um completo:

1. **Rápido — menu de contexto** (`menu.rs:81+`, ao lado de *Copiar/Colar*):
   **"Usar esta aparência nesta pasta"** — cria/atualiza a regra do cwd atual
   com o esquema e a opacidade correntes. E **"Remover regra desta pasta"**
   quando já existe. É esse gesto que faz a coisa parecer natural, sem tabela.
2. **Completo — `ContextPage::DirectoryRules`**, no mesmo molde de
   `ContextPage::Profiles` (`main.rs:1145`, `3359`): lista de regras
   expansíveis, cada uma com caminho (+ botão "usar pasta atual"), toggle de
   subpastas, dropdown de esquema dark/light (reusa `color_scheme_names()`),
   slider de opacidade com opção "usar o global", campo de título da aba, cor do
   cursor, ativar/desativar, remover. Item novo no menu **Arquivo**, junto de
   "Perfis" (`menu.rs:229`).

⚠ **Título da aba — quem ganha.** Hoje `TermEvent::Title` (`main.rs:3129`)
escreve o título da aba a menos que exista `tab_title_override` (usado pelo
perfil). O título vindo da regra entra **pelo mesmo mecanismo de override**, com
a precedência da §2.1: título da regra > título do perfil > o que o shell mandar.
Regra sem título (`None`) deixa o comportamento atual intacto. Suportar
`{dir}`/`{base}` no texto é opcional e cabe numa função livre testável.

### F5 — i18n

Chaves novas em `i18n/en/` **e** `i18n/pt-BR/` ([ARCHITECTURE §7](ARCHITECTURE.md)):
`directory-rules`, `directory-rules-desc`, `use-appearance-here`,
`remove-rule-here`, `include-subdirectories`, `use-current-directory`,
`use-global-opacity`, `rule-path`, `rule-tab-title`, `rule-cursor-color`.

### F6 — Instalação

`install.sh` / `uninstall.sh` / `setup-auto-reapply.sh` /
`remove-auto-reapply.sh` no molde do launcher — **os quatro**
([ARCHITECTURE §6](ARCHITECTURE.md)) — e `cosmic-term` acrescentado ao array
`COMPONENTS` do `install-all.sh`.

⚠ **`cosmic-term` não é gerenciado pela sessão.** Diferente do launcher, matar o
processo **fecha os terminais abertos do usuário** (inclusive o que está rodando
o `install.sh`). O instalador **não deve** dar `pkill` — deve apenas avisar
"reabra o terminal para usar a versão nova", como já se faz com o
`cosmic-files`.

---

## 4. Riscos e como mitigar

| Risco | Mitigação |
|---|---|
| Blur do COSMIC anula a opacidade por pasta (§F2) | Testar com blur lig/desl e decidir entre documentar ou compor os alfas |
| Drift do upstream (o COSMIC anda rápido) | Patch **aditivo**: campos `Option<_>`, `#[serde(default)]`, caminho antigo intacto como fallback |
| `readlink` em excesso | Throttle de 200 ms + orientado a evento; nunca no laço de render |
| Regra errada pinta a pasta errada | Match por componente de caminho, coberto por teste (`/a` × `/ab`) |
| Config nova quebrar versão antiga | Chave separada no store por-arquivo — versão antiga ignora (§1.3) |
| Piscar de cor ao trocar de pasta | Só chamar `set_config` quando a **regra** muda, não quando o cwd muda |

---

## 5. Ordem sugerida e esforço

| Fase | Entrega | Esforço |
|---|---|---|
| F0 | Fork + upgrade + ROADMAP | baixo |
| F1 | Modelo + resolução + testes (`cargo test --bins`) | médio |
| F2 | Cor, opacidade, cursor e título por terminal | médio |
| F3 | Reação ao `cd` | baixo |
| F4 | Menu de contexto + página de regras | **maior parte do trabalho** |
| F5 | en + pt-BR | baixo |
| F6 | Scripts de instalação + docs | baixo |

**Primeiro marco testável:** ao fim de F3 já dá para validar tudo editando o
arquivo `dir_rules` na mão — antes de investir na UI, que é a fase mais cara.

---

## 6. Backlog (fora da v1)

- 💡 **Fonte e tamanho por pasta** — cortado da v1 (§2.5); exige recálculo de
  métricas e de tamanho de célula.
- 💡 **OSC 7** — o shell anuncia a pasta em vez de a gente ler `/proc`; mais
  preciso (pega `cd` dentro de subprocesso), mas exige plumbing no parser e
  configuração no shell do usuário.
- 💡 **Config dentro da pasta** (`.cosmic-term.toml`) — portátil e versionável,
  mas é entrada não confiável; só com allowlist ou confirmação (§2.1).
- 💡 **Regra por padrão glob** (`~/projetos/*/prod`) em vez de só prefixo.
- 💡 Levar o mesmo conceito ao *Abrir no terminal* do `cosmic-files`, para a
  pasta abrir já com a aparência dela.
