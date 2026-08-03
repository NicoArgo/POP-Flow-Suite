# Relatório — travamento progressivo da sessão

Sintoma relatado: depois de um tempo o sistema fica travado, o mouse "não
acompanha a taxa de atualização" e o scroll fica truncado.

**Não é cache, nem sujeira acumulada de sistema. É um vazamento de memória**,
e o processo que vaza é um dos que o POP Flow instalou.

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
cd "Área de trabalho/Apps Workspace/Pop Flow/cosmic-applets" && ./uninstall.sh
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
