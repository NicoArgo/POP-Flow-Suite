# Relatório — travamento progressivo da sessão

> ## ⚠️ Segunda vistoria — 5 de agosto, 13h55
>
> **O vazamento diagnosticado em 3 de agosto foi corrigido e a correção
> funcionou. Existe um segundo vazamento, diferente, e é ele que está travando
> a máquina agora.** Leia a [§6](#6-segunda-vistoria--5-de-agosto) primeiro; o
> que vem antes é o histórico do primeiro.

Sintoma relatado: depois de um tempo o sistema fica travado, o mouse "não
acompanha a taxa de atualização" e o scroll fica truncado.

**Não é cache, nem sujeira acumulada de sistema.** São **duas coisas somadas**,
e só uma delas é do POP Flow.

> **Correção (mesma vistoria, medição posterior).** A primeira versão deste
> relatório atribuiu o sintoma inteiro ao vazamento do POP Flow. Estava errado.
> O usuário observou que a lentidão **já existia antes do POP Flow**, e a
> medição confirma: a máquina já vivia perto do limite por conta do uso normal.
> O vazamento é o que transformou "às vezes lento" em "trava sempre depois de um
> tempo" — é agravante, não a causa única. O diagnóstico abaixo reflete isso.

| | |
|---|---|
| **Crônico** (anterior ao POP Flow) | 23 GB de RAM sustentando Chrome, WhatsApp e várias sessões de Claude Code ao mesmo tempo. Já perto do limite, sem vazar. |
| **Agudo** (do POP Flow) | `cosmic-app-list` vazando ~150 MB/min. Dobra a cada ~25 min e estoura qualquer folga. |

### O Claude Code é a causa? Não.

Medido, porque a pergunta merece número e não palpite. Quatro sessões
simultâneas, três amostras de 20 s cada:

```
claude:379 → 377 → 375 MB
claude:350 → 356 → 352 MB
claude:371 → 356 → 359 MB
claude:339 → 326 → 329 MB
```

**Oscilam, não crescem** — sobem e descem dezenas de MB, que é coletor de lixo
funcionando. Somam ~1,4 GB, o que é um pedaço real dos 23 GB, mas é um pedaço
**estável**. O Chrome idem (3,84 GB nas duas amostras, parado).

Nenhum dos dois vaza. Eles ocupam a folga; quem a consome sem parar é o applet.

---

## 1. O que foi medido

Sessão com **4h48min** de uso no momento da vistoria.

### 1.1 O achado principal

```
cosmic-app-list   RSS 1.4 GB   e crescendo ~35 MB a cada 15 s
```

Medido em quatro amostras consecutivas, sem ninguém tocar no computador:

| horário | RSS | heap (anônima) |
|---|---|---|
| 15:14:03 | 1360 MB | 1348 MB |
| 15:14:18 | 1397 MB | 1385 MB |
| 15:14:33 | 1431 MB | 1419 MB |
| 15:14:48 | 1468 MB | 1456 MB |

**~140 MB por minuto.** Para um applet de painel, que deveria ficar na casa das
dezenas de megabytes.

A memória é **anônima** (heap), não arquivo mapeado — 1,18 GB numa única região.
E o processo usa **0,4% de um núcleo**: não é laço ocupado, são **poucas
alocações grandes**. Do tamanho de imagens.

### 1.2 O efeito disso na máquina

```
RAM:   23 Gi total, 13 Gi em uso
Swap:  19 Gi total, 15 Gi EM USO      ← aqui está o travamento
```

Com o swap nesse nível, cada movimento de janela ou scroll pode esbarrar numa
página que está no disco. O sintoma exato disso é o que você descreveu: ponteiro
engasgando e scroll truncado, porque o quadro perde o prazo esperando I/O.

### 1.3 O compositor

```
cosmic-comp   RSS 1,2 GB   CPU ~38% de um núcleo parado
              3082 descritores abertos, dos quais 2888 são de arquivos DELETADOS
```

2888 arquivos deletados mantidos abertos são buffers que ninguém fechou. **Mas o
número está estável** (medido duas vezes, sem crescer), então isso é acúmulo
antigo, não o vazamento ativo. O compositor é vítima, não causa.

---

## 2. A causa

O applet captura miniaturas por `screencopy`. Cada captura, em
`cosmic-app-list/src/wayland_handler.rs`, faz:

```rust
fn send_image(&self, handle: ExtForeignToplevelHandleV1) {
    std::thread::spawn(move || {
        let Ok(fd) = rustix::fs::memfd_create(name, MemfdFlags::CLOEXEC) else { ... };

        // XXX is this going to use to much memory?      ← comentário do upstream
        let img = capture_data.capture_source_shm_fd(false, &handle, fd, None);
```

Cada chamada cria uma thread, um `memfd` e um buffer compartilhado do tamanho da
janela (uma janela 1080p RGBA = 8 MB). **O comentário `XXX` é do upstream** — o
próprio autor registrou a dúvida sobre consumo de memória e nunca a resolveu.

### O que é nosso nisto

O código que vaza **não é nosso**. Mas a nossa feature de preview no hover
mudou a *frequência* com que ele roda:

- **Upstream:** captura só ao **clicar** no ícone. Raro.
- **POP Flow:** captura ao **passar o mouse** (debounce de 350 ms). Comum — o
  ponteiro cruza a dock o tempo todo.

Ou seja: **herdamos um primitivo que vaza e multiplicamos a exposição a ele.**
Essa é a leitura honesta. A correção é nossa de qualquer forma, porque foi a
nossa feature que tornou o problema visível.

### O que eu não consegui confirmar

**Não localizei o disparo exato** que mantém as capturas acontecendo agora, com
ninguém usando a máquina. O caminho do hover no `app.rs` retorna cedo quando já
há popup aberto, e não encontrei laço nem timer que capture sozinho. Ficam duas
hipóteses, e o plano começa por distinguir as duas:

1. O ponteiro está parado sobre um ícone da dock, e algo reabre a captura em
   ciclo.
2. Existe um segundo caminho de captura que eu não achei na leitura.

Não vou afirmar qual é sem medir.

---

## 3. Alívio imediato

Reiniciar o painel devolve a memória na hora (o applet é respawnado):

```bash
pkill -x cosmic-panel
```

Isso **fecha e reabre o painel**, nada mais — janelas de aplicativos não são
tocadas. Devolve ~1,4 GB e o sintoma some até acumular de novo.

Se quiser cortar o problema pela raiz enquanto não há correção, dá para voltar
ao applet de fábrica:

```bash
cd "Área de trabalho/Pop Flow/cosmic-applets" && ./uninstall.sh
```

Isso remove o preview no hover junto — é a troca.

---

## 4. Plano de correção

### C1 — Medir antes de consertar (primeiro passo, sem exceção)

Descobrir **quantas capturas por minuto** estão acontecendo e o que as dispara.
Um contador e um log por captura, com o app-id, respondem isso em minutos de uso
e distinguem as duas hipóteses da §2. Consertar antes de medir seria adivinhar.

### C2 — Fechar o buffer de captura

Independente da frequência, cada captura precisa liberar o que alocou: o
`memfd`, o pool shm e o buffer no compositor. É o que explica tanto o heap do
applet quanto os 2888 fds deletados do compositor. Esta é a correção de verdade,
e cabe mandá-la de volta ao upstream — o `XXX` é deles.

### C3 — Não capturar o que não vai ser mostrado

Mesmo sem vazamento, capturar a cada passada do mouse é desperdício. Duas
medidas que se somam:
- **Cache curto por janela** — não recapturar a mesma janela em, digamos, 2 s.
- **Capturar só quando o popup realmente abrir**, não ao iniciar o debounce.

### C4 — Teto de segurança

Um limite explícito de capturas em voo. Se algo escapar no futuro, o applet fica
lento em vez de comer a memória da máquina inteira — um modo de falha aceitável
em vez de um que derruba a sessão.

### C5 — Reduzir a pressão de swap (independente do resto)

O vazamento é a causa aguda, mas a máquina já vive perto do limite: o
`QtWebEngine` (zapzap/WhatsApp) soma ~1,4 GB de swap e o Chrome ~1,1 GB. Com o
applet corrigido isso deixa de ser crítico, mas vale saber que a folga é pequena.

---

## 5. Ordem sugerida

| | | |
|---|---|---|
| **agora** | `pkill -x cosmic-panel` | alívio imediato |
| C1 | instrumentar e medir | responde *por que* está capturando |
| C2 | liberar o buffer | a correção de verdade |
| C3 | não capturar à toa | corta o desperdício restante |
| C4 | teto de capturas | evita repetir o modo de falha |

O C1 é curto e o C2 é o que importa. Vale fazer os dois antes de voltar aos
gestos.

---

# 6. Segunda vistoria — 5 de agosto

Sintoma novo e pior: o sistema trava por **vários minutos**, e desta vez **o
áudio trava junto**. Áudio travando é o sinal de que não é mais engasgo de
quadro — é a máquina inteira parada esperando disco.

## 6.1 O que fizemos mais cedo, e funcionou

Em 3 de agosto, 15h32, o commit `3446f017` (`cosmic-applets`) fechou o
vazamento de sessões de screencopy: cada miniatura guardava um clone forte da
`CaptureSession`, o `Drop` nunca rodava, e nada era destruído. O binário foi
instalado um minuto depois (`/usr/bin/cosmic-app-list`, 15h33).

**A correção funcionou, e dá para provar.** O sintoma daquele vazamento era o
compositor segurando descritores de captura abertos — eram 2888 na primeira
vistoria. Hoje:

```
fds do compositor com nome "app-list-screencopy":  0
RSS do cosmic-app-list:                            18 MB   (era 1,4 GB)
```

Zero. O applet voltou ao tamanho de applet. Aquele vazamento está morto.

## 6.2 O segundo vazamento

O compositor continua acumulando descritores — só que **de outra coisa**:

```
cosmic-comp (pid 2403):  4206 fds abertos, 3891 em arquivos DELETADOS
  3870  memfd:smithay-client-toolkit    ← estes
     8  memfd:smithay-dmabuffeedback-format-table
     3  memfd:xwayland-shared
```

Somando o tamanho real de cada um dos 3870:

```
20 457 MB — 20 GB presos em buffers que ninguém libera
média de 5,4 MB por buffer
```

Não são buffers de captura. São **pools de memória compartilhada de
superfície** (`wl_shm_pool`), criados pelo cliente e mantidos abertos pelo
compositor porque o `destroy` do pool nunca chega. O cliente já fechou o lado
dele — o `cosmic-app-list` tem só 3 abertos agora. Quem segura os 3870 é o
compositor, e memória de `shm` **não é recuperável**: o kernel não pode
descartá-la como faz com cache, só pode empurrá-la para o swap.

### Os tamanhos dizem de onde vêm

| quantidade | tamanho | soma |
|---|---|---|
| 2037 | 7,65 MB | 15,6 GB |
| 1678 | 2,72 MB | 4,5 GB |
| 176 | outros | ~0,4 GB |

Dois tamanhos dominam, em proporção de quase **1:1** — ou seja, **duas
superfícies criadas por evento**, cerca de 1800 a 2000 eventos ao longo de 24 h
de sessão. E 7,65 MB é exatamente `1920 × 1044 × 4`: a sua tela (1920×1080)
menos a altura do painel.

Isso combina com o popup de preview no hover, que desde `ffb217e8` é um popup
**interativo (com grab)**: um popup com grab precisa de uma superfície do
tamanho da tela para capturar o clique fora, além da superfície do próprio
preview. Duas superfícies por hover, ~10,4 MB por hover, nenhuma liberada.

**Isto era inferência quando foi escrito. Deixou de ser — ver §6.6.**

## 6.3 Por que isso trava o áudio

```
RAM:   23 Gi total —  22 Gi em uso,  704 Mi livres
Swap:  19 Gi total —  19 Gi em uso,   96 Ki livres     ← 0,0005% livre
zram:  16 G  — 13 G de dados comprimidos em 1,6 G de RAM
```

Dos 20 GB de swap ocupados, **apenas 8,5 GB pertencem a processos**. Os outros
**11,9 GB são shmem** — os buffers vazados, empurrados para o disco.

Com o swap cheio e 20 GB de memória não-recuperável, o kernel não tem o que
liberar. Toda alocação vira espera por disco. O contador do próprio kernel
desde o boot:

```
/proc/pressure/io      parada TOTAL: 11 709 s  (195 min)
/proc/pressure/memory  parada TOTAL:    231 s  (3,8 min)
```

195 minutos, em 24 h de uptime, com **todas** as tarefas bloqueadas em I/O.
O `load average` de 15 min estava em **23,63** no momento da vistoria.

O áudio trava aí. O PipeWire tem prazo de milissegundos e suas páginas foram
para o swap (6 MB do `pipewire`, 6 MB do `wireplumber`). Quando o buffer que
ele precisa está num disco criptografado atrás de uma fila de swap, o áudio
para. **O áudio travar não é um sintoma novo — é o mesmo travamento, agora
grande o bastante para alcançar o processo mais sensível a atraso da máquina.**

## 6.4 Ritmo do vazamento

20 457 MB em 1446 minutos de uptime = **~14 MB/min, permanentes.**

É menos que os 150 MB/min do primeiro vazamento, mas com uma diferença que
importa: aqueles 150 MB/min eram RSS do applet, transitório. Estes 14 MB/min
**nunca voltam** enquanto o compositor viver.

Duas amostras com 40 s de intervalo, sem ninguém tocar na máquina: `3870 → 3870`.
**Não cresce sozinho.** Cresce por interação — o que reforça a §6.2.

## 6.5 O que fazer

### `pkill -x cosmic-panel` NÃO resolve mais — medido, 14h08

Eu previ que reiniciar o painel devolveria os 20 GB, porque a queda da conexão
Wayland deveria fazer o compositor destruir os recursos daquele cliente.
**Previsão errada.** Executado e medido:

```
             painel      pools     RAM        swap livre
antes        2467        3870      22 Gi      196 KiB
depois       338519      3877      22 Gi       26 MiB
```

O painel e o `cosmic-app-list` reiniciaram de fato — PIDs novos (338519,
338568), 80 s de vida. O compositor ficou de pé o tempo todo (24 h de uptime).
**Nem um byte voltou.** Os pools subiram para 3877: os 7 novos são das
superfícies do painel recém-nascido.

Isso muda o diagnóstico de lugar:

> **O compositor não libera os pools nem quando o cliente que os criou morre.**
> Um `wl_shm_pool` cujo dono desapareceu ainda está aberto no `cosmic-comp`.
> Isso não é um cliente que esquece de destruir — é o **compositor retendo o
> objeto além do tempo de vida da conexão**.

Consequências práticas:

- **Não existe alívio barato.** Só reiniciar o `cosmic-comp` — ou seja, encerrar
  a sessão / reiniciar a máquina — devolve os 20 GB.
- O `pkill -x cosmic-panel` da §3 continua valendo para o *primeiro* vazamento
  (RSS do applet), que já está corrigido. Para este, não serve.
- O que "limpou e melhorou a performance" ontem foi o **reboot** das 13h49 de
  4/8, não um comando de limpeza. O contador começa do zero a cada boot e leva
  ~24 h para voltar a estrangular a máquina, que é exatamente o intervalo que
  você observou.

### O teste que fecha o diagnóstico (2 minutos)

Logo depois de reiniciar o painel, com a contagem zerada:

1. medir `ls /proc/$(pgrep -x cosmic-comp)/fd | wc -l`
2. passar o mouse pela dock umas 20 vezes, sem clicar
3. medir de novo

Se subir ~40 (dois por hover), o popup de preview está confirmado e a correção
tem endereço exato. Se não subir, o cliente é outro e a busca continua.

### A correção

Depende do resultado acima. Se for o popup: garantir que **todo** caminho de
fechamento destrua o popup — há 14 chamadas de `destroy_popup` no `app.rs`, e
basta um caminho de saída sem ela para vazar. Os candidatos são as transições
que a POP Flow acrescentou: hover que troca de app sem fechar o popup anterior
(`188f8a4e`), e o popup com grab (`ffb217e8`).

### Independente disso — o teto crônico continua

O QtWebEngine (WhatsApp) soma ~5 GB em swap e o Chrome mais um tanto. Com 20 GB
livres isso é folgado; a §5 do primeiro relatório segue valendo.

## 6.6 Confirmado: é o hover na dock — 14h18

O teste ficou possível quando a linha de base se revelou **exatamente zero**.
Duas janelas sem ninguém tocar na máquina, com os inodes comparados um a um:

```
14:14:36 → 14:16:08   3916 → 3916    novos: 0    liberados: 0
```

Zero em 92 s. Não há laço de fundo, timer nem relógio de painel criando pools.
Com o fundo preto, qualquer crescimento durante uma ação pertence àquela ação.

Janela de 90 s, com o usuário passando o mouse pela dock e mais nada:

```
14:17:12  t0 = 3916
   ...       3916      (11 amostras planas)
14:18:07     3916
14:18:12     3931      ← +15
14:18:42  t1 = 3931
```

E os pools novos, medidos pelo inode:

| quantidade | tamanho | soma |
|---|---|---|
| 3 | 7,65 MB | 23,0 MB |
| 12 | 2,72 MB | 32,6 MB |
| **liberados** | — | **0 MB** |

**Saldo: 55 MB vazados numa única passada de mouse pela dock.**

Os dois tamanhos são **exatamente** os dois que dominam os 20 GB acumulados
(§6.2). Mesma assinatura, mesmo produtor. A inferência virou medição.

### As duas falhas, que são independentes

1. **No cliente** — cada abertura do popup de preview aloca superfícies novas e
   nenhuma é destruída. 15 pools, 0 liberados. Há 14 chamadas de
   `destroy_popup` no `app.rs`; destruir o popup evidentemente não destrói os
   pools das superfícies dele.
2. **No compositor** — o `cosmic-comp` **não libera os pools nem quando o
   cliente morre** (§6.5: painel reiniciado, 3870 pools intactos). Esta é a que
   torna a primeira fatal: normalmente o vazamento de um applet se resolveria
   sozinho quando ele reinicia.

A segunda é a mais grave e não é da POP Flow — é do compositor, que também
temos como fork (`cosmic-comp`, branch criada em 3/8).

### Ordem de correção

| | | |
|---|---|---|
| **agora** | reiniciar a sessão | única coisa que devolve os 20 GB |
| **enquanto não há correção** | `cosmic-applets/uninstall.sh` | tira o preview no hover; para a hemorragia |
| **D1** | destruir os pools ao fechar o popup | corta 55 MB por passada de mouse |
| **D2** | liberar pools órfãos no `cosmic-comp` | impede que qualquer cliente repita isso |

O D2 vale mandar para o upstream: um compositor que segura buffers de clientes
mortos transforma o bug de qualquer applet num travamento de sessão.

## 6.7 Decisão — 5 de agosto

**O preview no hover fica.** Não desinstalamos o applet nem removemos a feature:
corrigimos o D1 e o D2 para que ela funcione sem vazar. A opção de rodar o
`uninstall.sh` está descartada.

### Retomada, depois do reboot

O reboot zera o contador — é por isso que a máquina "melhora sozinha" e volta a
travar em ~24 h. **Reiniciar não corrige nada**, só devolve os 20 GB.

Estado a confirmar logo ao voltar (deve estar na casa das dezenas, não dos
milhares):

```bash
ls -l /proc/$(pgrep -x cosmic-comp)/fd | grep -c memfd:smithay-client-toolkit
```

### Correção da leitura: são 15 pools por POPUP, não por hover

Desde `ffb217e8` o popup agarra o ponteiro e **não troca** ao passar por outro
ícone. O guarda está explícito no `app.rs`:

```rust
Message::HoverPreviewEnter(id, parent_window_id) => {
    // Don't stack onto an already-open popup
    if self.popup.is_some() { return Task::none(); }
```

Durante os 90 s do teste, portanto, **só um popup pôde abrir** — os demais
hovers foram bloqueados. O padrão medido bate exatamente: 55 s plano, +15 num
degrau, 30 s plano. Logo:

> **Uma única abertura do popup de preview = 15 pools = 55 MB, 0 liberados.**

Confere com o acumulado: 3870 ÷ 15 ≈ **258 aberturas** em 24 h de uso.

### Onde o D1 NÃO está

O `app.rs` cria **um** popup: uma chamada de `get_popup`, um `window::Id`. Os
15 buffers não são dele — são alocados pela **libcosmic/iced-sctk** ao renderizar
e redimensionar aquela superfície. Três têm exatamente `1920×1044×4`, a tela
menos o painel, o que sugere superfície dimensionada para a área toda antes de
ser limitada.

Os caminhos de destruição no `app.rs` foram revisados e estão razoáveis:
`close_popups`, `Activate`, `Toggle`, `PinApp`, `UnpinApp`, `Quit` e
`CloseRequested` limpam o estado. **Patch no `app.rs` seria mirar no lugar
errado.**

### Por onde começar de verdade

A libcosmic é dependência git com checkout local, e o `Cargo.toml` do
`cosmic-applets` **já tem as linhas de patch local comentadas**:

```toml
# [patch."https://github.com/pop-os/libcosmic"]
# libcosmic = { path = "../libcosmic" }
```

1. clonar a libcosmic em `../libcosmic` (rev `511384f6` do `Cargo.lock`) e
   ligar o patch;
2. **instrumentar antes de consertar** — um log por criação e destruição de
   pool, com tamanho. Em minutos de uso isso diz quais dos 15 são quais e qual
   não é destruído;
3. só então o patch, com endereço.

O método que funcionou e vale repetir para validar a correção: **linha de base
ociosa é exatamente zero**, então basta comparar os inodes dos `memfd` do
compositor antes e depois de uma passada de mouse pela dock. Hoje esse número é
**+15 pools / 55 MB**. Corrigido, tem que ser 0.

---

# 7. Achado — 10 de agosto: é o nosso launcher

**O vazamento é do `cosmic-launcher` (POP Flow), no caminho de captura das
miniaturas.** Corrigido no commit `50b5b26` do fork. A dock **não** é a fonte —
a §6.6 estava errada, e as hipóteses da §6.7 (`app.rs`, libcosmic, retenção
própria do `cosmic-comp`) estão todas descartadas.

## 7.1 O teste que fecha tudo, em 5 segundos

```bash
pkill -x cosmic-launcher
```

Antes: **266 pools órfãos, 1153,9 MiB**. Depois: **0**. Cada byte vazado estava
pendurado na conexão do launcher; o COSMIC o reinicia sozinho em seguida. Isso é
o alívio imediato enquanto a correção não é instalada — e é a prova de autoria,
porque o compositor libera tudo de um cliente que morre.

## 7.2 O mecanismo

Três fatos, um em cima do outro:

1. No `wayland-server`, o handle de um objeto (`WlBuffer`) **carrega o próprio
   user-data**: `data: Option<Arc<dyn Any>>` (gerado pelo `wayland-scanner`).
2. No smithay, o user-data de um buffer shm é `ShmBufferUserData { pool:
   Arc<Pool>, .. }`, e o `Pool` é **dono do `OwnedFd`** do memfd.
3. Pelo protocolo, **destruir o pool não invalida os buffers feitos dele**.

Logo: enquanto existir um `wl_buffer`, o memfd fica aberto e mapeado no
compositor — mesmo com o pool destruído e o fd fechado no cliente. É por isso
que o censo não achava dono: o cliente tinha fechado a sua cópia.

## 7.3 O que o launcher fazia

Em `src/wayland.rs`, a cada abertura do Alt+Tab, **por janela**: um `RawPool`
(memfd `smithay-client-toolkit`) de `largura×altura×4` e um `wl_buffer`. Ao
chegar o `ready`, o pool era solto (o `Drop` do `RawPool` o destrói e fecha o
fd) e **o buffer era esquecido**. Janela maximizada = 1920×1044×4 = 8017920 B —
exatamente o tamanho que dominava o censo. Quinze janelas por abertura é o
"15 pools por popup" da §6.7, atribuído à dock por coincidência de ritmo.

O applet da dock faz certo (`pool.destroy(); buffer.destroy();`), e o
`cosmic-applet-minimize` também. O compositor não segura nenhum memfd
`app-list-screencopy` — o nome que o applet dá aos seus.

## 7.4 Como foi medido

**Censo de órfãos** (`scratchpad/sampler.py`): fds `memfd:smithay-client-toolkit`
que **só** o `cosmic-comp` segura, correlacionando inodes entre todos os
processos. Ocioso não cresce; abrir o app library crescia em degraus.

**Cliente-sonda** (`scratchpad/shm-probe`), contra o compositor rodando:

| o que a sonda faz | fds retidos |
|---|---|
| toplevel: 15 buffers, anexa e destrói cada um | 0 (só o buffer corrente) |
| popup: 5 ciclos abre/desenha/fecha | 0 |
| layer surface: 5 ciclos, destruindo | 0 |
| layer surface: desmapeia e mantém a superfície | 0 |
| cliente morre sem destruir nada | 0 (o compositor limpa) |
| **captura: pool destruído, buffer não — como o launcher** | **+1 por captura** |
| **a mesma captura com `buffer.destroy()`** | **0** |

O compositor está limpo em todos os caminhos comuns. O único que vaza é o que
deixa um `wl_buffer` vivo.

## 7.5 Validar depois de instalar

Linha de base ociosa é exatamente zero, então:

```bash
python3 scratchpad/sampler.py 5 300   # deixa rodando
# abrir e fechar o Alt+Tab várias vezes
```

Tem que ficar em 0. Hoje, sem a correção, são ~8 MiB por janela por abertura.
