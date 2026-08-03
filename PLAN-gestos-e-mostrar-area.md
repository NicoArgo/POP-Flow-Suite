# Plano — Gestos de touchpad e "mostrar área de trabalho"

Dois pedidos relacionados: **gestos de touchpad no estilo macOS** (três dedos
para o lado troca janela, etc.) e **clicar na barra de applets para minimizar
tudo e ir para a área de trabalho**.

> **Decisões travadas em 2026-08-03:** applet no painel (§3-A) · gesto de trocar
> janela **discreto** (§2.2-a) · primeira leva com **os quatro** gestos: 3 dedos
> ←→ trocar janela, 3 ↑ overview, 3 ↓ área de trabalho, pinch 4–5 App Library.

---

## 1. Vistoria

### 1.1 O compositor já tem a maior parte da infraestrutura de gesto

`cosmic-comp/src/input/gestures/mod.rs` já traz:

- `GestureState` — número de dedos, direção, delta acumulado, **velocidade** e
  **posição projetada** com desaceleração (para o gesto "continuar" ao soltar).
- `RubberBand` — o efeito elástico ao passar do limite.
  Ambos portados do Niri, com crédito no código.

E `src/input/mod.rs` já **captura 3+ dedos no compositor** (linha 982), ou seja,
esses gestos não vazam para os aplicativos.

**O que falta é vocabulário, não encanamento.** `SwipeAction` tem exatamente
duas variantes: `NextWorkspace` e `PrevWorkspace`.

### 1.2 O upstream deixou o lugar reservado

Em `src/input/mod.rs`:

```rust
activate_action = match gesture_state.fingers {
    3 => None, // TODO: 3 finger gestures      ← linha 1025
    4 => { /* trocar workspace na horizontal */ }
    _ => None,
};
```

E dentro do caso de 4 dedos, `_ => None, // TODO: Other actions` para as
direções não usadas (linhas 1045 e 1063). **O que você pediu é literalmente o
TODO do upstream.** Isso é o melhor cenário possível para a
[ARCHITECTURE §3](ARCHITECTURE.md) (patch aditivo, cirúrgico): preenchemos um
buraco previsto, não reescrevemos um caminho existente.

### 1.3 A descoberta que mais simplifica

`Action::System(...)` no compositor **não é lógica interna — é um comando**:

```rust
Action::System(system) => {
    if let Some(command) = self.common.config.system_actions.get(&system) {
        self.spawn_command(command.clone());
    }
}
```

Então "abrir o overview", "abrir a app library", "abrir o alternador de janelas"
já são comandos configurados. Um gesto que dispare qualquer um deles é uma
linha, não uma integração.

### 1.4 "Mostrar área de trabalho" não precisa do compositor

O protocolo `cosmic-toplevel-management` expõe **`set_minimized` /
`unset_minimized`** a qualquer cliente (confirmado no XML do
`cosmic-protocols`). Ou seja: minimizar todas as janelas é possível de fora do
compositor, por um applet ou uma ferramentinha.

POP Flow já tem quilometragem nesse protocolo — o launcher fecha janelas por ele
e o applet de dock rastreia toplevels.

### 1.5 O painel não recebe clique no espaço vazio

`cosmic-panel-bin/src/space/spacer.rs`:

```rust
fn is_in_input_region(&self, _point: &Point<f64, Logical>) -> bool {
    false
}
```

O vazio do painel é **deliberadamente transparente ao clique**. Fazer o painel
reagir a clique no fundo exige mudar isso — e o `cosmic-panel` **não é
componente da suíte** (precisaria de fork novo).

### 1.6 Estado dos repositórios

| | |
|---|---|
| `cosmic-comp` | Fork `NicoArgo/cosmic-comp` ✅, mas **em HEAD destacado** e com base de **2026-02-17** (~6 meses atrás) |
| `cosmic-panel` | **Não é componente da suíte** — fork novo, só se escolher a opção B da §3 |
| `cosmic-comp-config` | **É crate in-tree** do cosmic-comp — então tornar os gestos configuráveis **não** exige forkar mais nada |

> ⚠ **`cosmic-comp` é o compositor.** Se quebrar, derruba a sessão inteira, e
> testar exige reiniciar a sessão. É a única parte da suíte com esse risco.

---

## 2. Gestos — o que faz sentido fora do Mac

O que o libinput entrega: **swipe de 3, 4 ou 5 dedos** (1–2 dedos são ponteiro e
scroll, não dá), **pinch** (2+) e **hold**. O pinch já chega ao cosmic-comp, mas
hoje é só repassado aos aplicativos — ninguém o interpreta.

| Gesto no Mac | Dedos | Equivalente COSMIC | Viável? |
|---|---|---|---|
| Trocar de "space" | 3–4 lado | Trocar workspace | ✅ **já existe** (4 dedos) |
| Mission Control | 3–4 cima | Overview de workspaces (tecla Super) | ✅ comando já existe |
| App Exposé | 3–4 baixo | *nada equivalente* | ⚠ sem contrapartida — proponho outro uso |
| Launchpad (pinch fecha) | 4–5 pinch | App Library | ✅ pinch chega; falta interpretar |
| Show Desktop (spread) | 4–5 spread | Minimizar tudo | ✅ via toplevel-management |
| Central de Notificações | 2 da borda | Applet de notificações | ❌ swipe de borda não existe no libinput |

### 2.1 Conjunto proposto

Mantendo **4 dedos = workspaces** como está (é o que o upstream já faz, e mexer
nisso quebraria o hábito de quem já usa):

| Gesto | Ação | Por quê |
|---|---|---|
| **3 dedos ← →** | **Trocar de janela** (MRU, o Alt+Tab do POP Flow) | O seu pedido explícito. E cai no nosso launcher, que é a joia da suíte |
| **3 dedos ↑** | Overview de workspaces | O "Mission Control"; comando já existe |
| **3 dedos ↓** | **Mostrar área de trabalho** | Sem App Exposé no COSMIC, este é o uso mais útil do gesto — e reaproveita exatamente a mesma ação do pedido do painel |
| **4 dedos ← →** | Trocar workspace | Já existe, não mexer |
| **4/5 dedos pinch** | App Library | O "Launchpad" |
| **4/5 dedos spread** | Mostrar área de trabalho | É literalmente o gesto do Mac para isso |

### 2.2 A decisão de verdade: como o "trocar de janela" se comporta

Duas semânticas possíveis, e elas custam muito diferente:

**(a) Discreto — um swipe, um passo.** Cada gesto de 3 dedos avança uma janela
na ordem de uso recente, como um Alt+Tab rápido. Simples, previsível, e o
launcher nem precisa mudar.

**(b) Ao vivo — o alternador segue os dedos.** O overlay abre enquanto os dedos
estão no touchpad, a seleção acompanha o movimento, e soltar confirma — como no
Mac. Muito melhor de usar, bem mais caro: o Alt+Tab do launcher hoje fecha
quando o **Alt é solto** (`Message::AltRelease`), e num gesto não há modificador
nenhum. Precisaria de um "modo gesto" no launcher e de um canal do compositor
para ele.

**Escolhido: (a) discreto.** O (b) fica como fase opcional (G6), se o uso provar
que vale. Vale registrar que **só o POP Flow pode fazer o (b)** com essa
qualidade, porque o launcher é nosso — num COSMIC de fábrica isso não existiria.

---

## 3. "Mostrar área de trabalho" — três caminhos

O núcleo é o mesmo nos três: **minimizar todas as janelas do workspace ativo e,
no segundo acionamento, restaurar exatamente as que foram minimizadas** (não
todas — quem já estava minimizado deve continuar).

Esse estado ("quais eu minimizei") precisa morar em algum processo vivo. É o que
separa as opções.

### Opção A — applet dedicado ✅ **escolhida**

Um applet em `cosmic-applets` (**fork que já temos**): uma faixa fina e
clicável, no canto do painel, no estilo do botão "Mostrar área de trabalho" do
Windows. Como o applet é um processo vivo, ele guarda naturalmente a lista do
que minimizou.

- ✅ Sem fork novo, sem tocar no compositor.
- ✅ Reaproveita o rastreio de toplevel que o applet de dock já faz.
- ➖ Não é *exatamente* "clicar na barra": é clicar num ponto dela.

### Opção B — clicar no vazio do painel (o pedido literal)

Forkar o `cosmic-panel` e fazer o fundo do painel aceitar clique (§1.5).

- ✅ É exatamente o que você descreveu.
- ➖ **Fork novo** de um componente que ninguém da suíte conhece ainda.
- ⚠ Risco real: o vazio do painel é transparente ao input **de propósito**.
  Torná-lo clicável pode atrapalhar arrastar janelas para a borda, o
  `overlap_notify`, e o clique-fora que fecha popups de applets. Precisa de
  clique **curto** (com limiar de tempo e de movimento) para não capturar
  arrastos.

### Opção C — só atalho de teclado

Registrar como um comando e deixar o usuário amarrar numa tecla.

- ✅ Custo quase zero, e é subproduto natural das opções A e B.
- ➖ Não atende o pedido sozinho.

**Escolhido: A**, com o C saindo de graça junto (o núcleo do G1 é o mesmo). A B
fica como G7 opcional, se o applet não satisfizer — as três compartilham o mesmo
núcleo, então nada é jogado fora ao trocar de opinião.

---

## 4. Plano de execução

> **O G1 e o G2 não dependem do G0.** O applet vive no `cosmic-applets` e fala
> com o compositor por protocolo, não por código. Dá para entregar metade do
> pedido — a área de trabalho — **sem tocar no compositor e sem risco de
> sessão**. O G0 só é pré-requisito das fases de gesto (G3 em diante).

### G0 — Preparação (antes de qualquer código **no compositor**)

1. **Consertar o `cosmic-comp`**: está em **HEAD destacado**. Colocar num ramo
   antes de tudo, senão o trabalho fica pendurado no nada.
2. **Sync com o upstream** (base de fevereiro, ~6 meses). Pelo que a
   [HANDOFF-sync-upstream.md](HANDOFF-sync-upstream.md) ensinou: merge, não
   rebase; e `cargo check --all-targets` **é obrigatório** mesmo se o merge for
   limpo — o drift de API não aparece como conflito.
3. **Tag-âncora** `pre-popflow` e os quatro scripts de instalação — com um
   detalhe crítico: o `install.sh` do compositor **não pode reiniciar nada**.
   Vale escrever o `uninstall.sh` **antes** de instalar pela primeira vez.

### G1 — Núcleo do "mostrar área de trabalho" (sem UI)

Uma função pura + um cliente de toplevel-management: minimizar todos os
toplevels do workspace ativo, guardar quais foram, restaurar só esses.

Testável sem compositor: a lógica de "quais minimizar / quais restaurar" sai em
funções livres ([ARCHITECTURE §5](ARCHITECTURE.md)), com o protocolo isolado
atrás de uma borda fina.

### G2 — Applet "mostrar área de trabalho" (opção A)

Um applet novo em `cosmic-applets`, faixa clicável + o núcleo do G1. Entrega o
pedido do painel sem tocar no compositor. **Aqui já dá para usar de verdade.**

### G3 — Vocabulário de gestos no compositor

Em `cosmic-comp`:
- `SwipeAction` ganha as variantes novas.
- O `match gesture_state.fingers` preenche o `3 =>` e as direções do `4 =>`.
- Gestos que só disparam comando (overview, app library, alternador) reusam o
  caminho do `Action::System` (§1.3).
- Respeitar `natural_scroll`, como o código de 4 dedos já faz.

### G4 — Gesto de trocar janela, semântica (a)

3 dedos ← → dispara o alternador. Fase curta se o G3 estiver de pé.

### G5 — Configuração

Chaves em `cosmic-comp-config` (in-tree, §1.6) para ligar/desligar e remapear
cada gesto. Sem isso, quem odiar um gesto não tem saída — e gesto que dispara
sem querer é bem pior que gesto ausente.

### G6 — (opcional) Alternador ao vivo, semântica (b)

Só depois de o G4 provar o gesto no uso. Envolve `cosmic-launcher` + um canal do
compositor.

### G7 — (opcional) Clique no painel, opção B

Fork do `cosmic-panel`, com o cuidado da §3-B.

---

## 5. Riscos

| Risco | Mitigação |
|---|---|
| **Quebrar o compositor derruba a sessão** | `uninstall.sh` escrito e testado **antes** do primeiro install; nunca instalar sem uma sessão de recuperação (TTY) à mão |
| Sync do compositor com 6 meses de drift | Lição do launcher: `cargo check --all-targets` acha o que o merge não acusa |
| Gesto disparando sem querer | Limiares de distância e velocidade; e o G5 (poder desligar) não é opcional na prática |
| Roubar o pinch dos aplicativos | Só interpretar pinch de **4–5 dedos**; 2 dedos continua indo para o app (é o zoom de mapa, imagem, PDF) |
| Clique no painel atrapalhar arrasto | Exigir clique **curto**, com limiar de tempo e de movimento |
| "Restaurar" trazer de volta janela que já estava minimizada | O estado é "o que **eu** minimizei", nunca "tudo que está minimizado" |

---

## 6. Ordem sugerida

| Fase | Entrega | Risco |
|---|---|---|
| G0 | Ramo + sync + scripts do compositor | baixo (mas obrigatório) |
| G1 | Núcleo minimizar/restaurar + testes | baixo |
| G2 | Applet — **já usável** | baixo |
| G3 | Vocabulário de gestos | ⚠ compositor |
| G4 | 3 dedos troca janela | ⚠ compositor |
| G5 | Configuração | baixo |
| G6/G7 | Alternador ao vivo / clique no painel | opcional |

**Marco recomendado:** parar depois do **G2** e usar. Ele entrega metade do
pedido (a área de trabalho) sem nenhum risco de sessão, e dá tempo de decidir se
o gesto de janela deve ser discreto ou ao vivo antes de mexer no compositor.
