# HANDOFF — onde paramos (2026-08-03)

Trabalho em curso: vistoria do projeto → correções A1, A2, A3, B1.
**O merge do `cosmic-launcher` foi CONCLUÍDO** (commit `bb70591`) — não há mais
merge em curso em lugar nenhum, e o `.sync-wip/` já pode ser apagado. Os três
forks estão mesclados e commitados **localmente**; falta push e reinstalar.
Detalhes na seção A3.

---

## ✅ Concluído e pushado

**A1 — binário de 43 MB fora do histórico.** `cosmic-files.orig` removido do
histórico do `cosmic-files` via `filter-branch` + force-push. Clone novo do
GitHub: 4,9M (era 21 MB). O binário de fábrica segue no disco, íntegro
(sha256 `6fb9419b…`), agora *untracked* e coberto por `*.orig` nos 3 forks —
`uninstall.sh` continua funcionando. SHAs do `cosmic-files` mudaram; a
`ROADMAP.md` já foi atualizada com os novos.

**A2 — auto-reapply nos 3 componentes.** `setup-auto-reapply.sh` /
`remove-auto-reapply.sh` parametrizados (só o bloco `COMP`/`BUILT`/`RELOAD`
difere). `install-all.sh` roda o setup de cada componente. Os `install.sh`
agora avisam quando não há hook, em vez de ficarem em silêncio.

### ⚠ Pendência do A2 — precisa do SEU terminal (sudo com TTY)

Os hooks **ainda não existem na máquina**. Rode:

```bash
cd "Área de trabalho/Apps Workspace/Pop Flow"
(cd cosmic-files   && ./setup-auto-reapply.sh)
(cd cosmic-applets && ./setup-auto-reapply.sh)
```

Conferir depois: `/usr/local/lib/pop-flow/` com 3 golden copies e
`/etc/apt/apt.conf.d/` com 3 hooks `99-pop-flow-*`.

---

## ✅ A3 — sync com upstream (merges feitos, falta push)

Decisão tomada: **merge, não rebase** — preserva SHAs (a `ROADMAP.md` os cita e
já quebrou uma vez no A1), dispensa force-push e registra o ponto de sync.

Drift medido (bem maior que o estimado no relatório):

| Fork | Commits atrás | Sobreposição de arquivos | Merge |
|---|---|---|---|
| cosmic-launcher | **53** (base de 2026-02-17) | `src/app.rs`, `Cargo.toml`, `main.rs`, `subscriptions/launcher.rs` | ✅ resolvido |
| cosmic-files | 9 | `src/tab.rs`, `i18n/pt-BR` | ✅ limpo |
| cosmic-applets | 2 | nenhuma | ✅ limpo |

### ✅ Feito e **pushado** (os 3 forks)
- `cosmic-files` → `8ebe789` merge com upstream `24e34ea`. **`cargo check
  --all-targets` passou** (só warnings pré-existentes).
- `cosmic-applets` → `0e10415` merge com upstream `ec8ffdc8`. **`cargo check -p
  cosmic-app-list --all-targets` passou** — 3 warnings, todos com blame no
  upstream (`CornerRadius` e `corners` não usados, variantes `*ListeningForDnd`
  nunca construídas). Nenhum é nosso.
- Tags de âncora pré-merge nos 3 repos: `pre-sync-20260803` — **também pushadas**
  (eram só locais, e um ponto de rollback que só existe no disco não serve de
  ponto de rollback).

### ✅ Concluído — `cosmic-launcher` → `bb70591`
Merge de `upstream/master` (`585a8c0`). `cargo check --all-targets` limpo
(4 warnings, **todos pré-existentes**: 2 herdados do upstream — o import
`get_layer_surface` que ele não usa e o `size` ignorado em `Message::Opened` —
e 2 do nosso lado, anteriores ao merge). **16/16 testes passando.**

**Resolvido:**
- `Cargo.toml` ✅ — upstream removeu `unicode-truncate`/`unicode-width`, mas
  **nosso** código usa (`src/app.rs`, truncamento de título por largura de
  display). Mantidas como dependências nossas, com comentário explicando.
- `src/app.rs` hunks 1–3 ✅:
  1. Bloco de imports — upstream migrou `iced_core`/`iced_runtime` →
     `cosmic::iced::*`. Adotei o bloco do upstream (conhecido-bom) e
     reintroduzi só o nosso: `Row`.
  2. `std::path` — mantido `{Path, PathBuf}` + `Rc` + `FromStr` do upstream.
  3. Variantes de `Message` (`OutputSize`, `Surface`, `Thumb`, `Hover`,
     `Unhover`, `CloseWindow`) — mantido nosso lado; upstream não tem nenhuma.
  - Também: linha 12 voltou para `use cosmic::iced::event::wayland::
    OverlapNotifyEvent;` (sem `OutputEvent`) para não duplicar com o import do
    upstream em `runtime::core::event::wayland` → evitaria E0252.
  - Reintroduzidos `use unicode_truncate::UnicodeTruncateStr;` e
    `use unicode_width::UnicodeWidthStr;` (upstream apagou os dele).

- `src/app.rs` hunks 4–9 ✅ — em todos, **ficaram os dois lados**:
  4. `init()`: adotada a forma nova do upstream (monta o app → cria a layer
     surface dummy → devolve a task) e reintroduzidos nossos 4 campos
     (`thumbnails`, `thumb_tx`, `hovered`, `screen_size`). `height` passou para
     o padrão `800.` do upstream (o `100.` era da base).
  5+6. `AltTab`/`ShiftAltTab`: nosso `set_thumbs_active(true)` **e** o
     `alt_tab_released = false` novo do upstream.
  7. Handlers do POP Flow no fim do `match` (`Surface`, `Thumb`, `Hover`,
     `Unhover`, `CloseWindow`) — upstream não tinha nada ali, ficou o nosso.
  8. O hunk grande (411): nossos métodos + funções livres inteiros, com o
     `layer_padding()` do upstream inserido **dentro** do `impl` e o
     `alt_tab_modifier_is_released()` **fora**, como função livre.
  9. Eventos de output: um arm da subscription só pode emitir **uma** mensagem,
     então adotamos o `Message::Output(event)` do upstream e dobramos nosso
     rastreio de `screen_size` para dentro do handler dele. `Message::OutputSize`
     ficou sem emissor e foi removido.

**⚠ A armadilha deste sync:** o bump do libcosmic quebrou **nosso** código em
arquivos que o git mesclou **sem conflito nenhum**. Um merge limpo não é sinal
de que compila — só `cargo check --all-targets` acha isso:
- `wayland.rs`: `Subscription::run_with_id` → `run_with`, e `cosmic::iced_futures`
  → `cosmic::iced::stream` (espelha o padrão que já existia em
  `subscriptions/launcher.rs`).
- `text::Style` e `container::Style` ganharam campos → passamos a usar
  `..Default::default()`, para o próximo bump não quebrar de novo.
- `Theme::background` virou método com a flag de transparência. Adotado
  `t.background(theme.transparent)` como o upstream faz em todo lugar — senão um
  fundo opaco esconde o desktop borrado atrás da layer surface.

### Próximos passos do A3
1. ~~Resolver os hunks, `cargo check`, `cargo test`, commitar~~ ✅ `bb70591`.
2. ~~`cargo check -p cosmic-app-list` no applets~~ ✅ passou.
3. ~~Pushar os três forks~~ ✅ (+ as tags-âncora).
4. **Rebuild + reinstalar (`./install-all.sh`, no seu terminal — o `sudo` precisa
   de TTY). O binário em `/usr/bin` ainda é o pré-sync**, ou seja: nada do que
   foi mesclado está rodando na máquina até isso acontecer.
5. Apagar o `.sync-wip/` da raiz do workspace (backup da resolução parcial, já
   não serve para nada).

---

## 📋 B1 — CI (não iniciado)

Diagnóstico já feito: `gh run list` volta vazio nos 3 forks — **Actions vem
desabilitado por padrão em forks**, então os `ci.yml` herdados nunca rodaram.

O que o CI herdado faz:
- `cosmic-files/ci.yml`: `cargo test` ×3 (no-default-features, default, all-features).
- `cosmic-applets/ci.yml`: `rustfmt --check` + `clippy --all --all-targets`.
- `cosmic-launcher`: só `validate-desktop-files.yml`, **sem build/test**.

Plano: habilitar Actions via
`gh api -X PUT repos/NicoArgo/<repo>/actions/permissions -f enabled=true`,
e avaliar um workflow próprio mínimo (`cargo check --all-targets`) para o
launcher, que não tem nenhum. Atenção: o clippy do applets é `--all
--all-targets --all-features` e pode falhar por motivos do upstream, não nossos.

---

## Achados do relatório ainda abertos

- **B2** — `cosmic-applets` sem testes (0), justo o componente com a máquina de
  estados assíncrona (debounce 350ms).
- **B3** — `column_sort()` roda por frame (padrão do upstream); a árvore
  multiplica `n` porque cada pasta expandida empurra linhas no mesmo `Vec`
  plano. Não medido.
- **C1** — `unwrap()` inconsistente em `wayland.rs:425/428/436` e `:254`.
- **C2** — `cosmic-files/README.md` é o do upstream; nossas 5 features só
  aparecem na ROADMAP da suíte (o repo é público).
- **C3** — `cosmic-applets` sem README.
- **C5** — `uninstall.sh` do applets assume o layout de symlink do upstream.

Relatório completo da vistoria: foi entregue como arquivo na sessão
(`vistoria-pop-flow.md`); o conteúdo está resumido acima nos itens abertos.
