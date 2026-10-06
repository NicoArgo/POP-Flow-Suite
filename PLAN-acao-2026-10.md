# Plano de ação — outubro de 2026

> **Atualização 06/10, fim do dia:** tudo das seções 2 e 3 foi implementado e
> está no GitHub (ver "Rodada 2" no fim). Falta **instalar e olhar na tela**.

Estado em 06/10/2026. Legenda: ✅ feito nesta rodada · 🔧 falta só instalar/validar ·
📋 próximo · 💡 oportunidade.

---

## 1. Pedidos desta rodada

### ✅ Canto inferior direito por hover
`cosmic-show-desktop-corner`: repousar o ponteiro **600 ms** no triângulo mostra a
área de trabalho, como um *hot corner*. Dispara **uma vez por visita** — o ponteiro
precisa sair antes de agir de novo, para não ficar alternando. O clique continua
valendo e conta como a decisão daquela visita (o hover não desfaz logo depois).
🔧 Instalar com `cosmic-applets/install.sh` (o serviço é reiniciado sozinho).

### ✅ Modo vampiro × modo dormir (applet novo)
`cosmic-applet-vampire`: um botão no painel. **Morcego** = modo vampiro (o PC só
dorme quando você manda); **lua** = modo dormir (tampa e inatividade podem
suspender). Tooltip diz o modo atual.

Como funciona:
- **Tampa**: um serviço de usuário (`pop-flow-vampire.service`) segura um
  inibidor `handle-lid-switch` em modo *block* no logind. Fechar a tampa não
  suspende. Habilitado = persiste após reiniciar.
- **Inatividade**: o `cosmic-idle` suspende por conta própria (roda
  `systemctl suspend` como você, e o logind não usa os seus próprios
  inibidores contra você). Então o modo zera `suspend_on_ac_time` e
  `suspend_on_battery_time` e **guarda os valores antigos** em
  `~/.local/state/pop-flow/vampire-idle/` para devolver ao desligar.
- **Suspender de propósito** (menu de energia, `systemctl suspend`) continua
  funcionando — é a mesma regra do logind que faz isso possível.
- CLI: `cosmic-applet-vampire --on | --off | --toggle | --status`.

**Já ligado nesta máquina** (o inibidor aparece em `systemd-inhibit --list`).
🔧 Instalar o applet (`cosmic-applets/install.sh`) e adicioná-lo em
*Configurações → Área de trabalho → Painel → Configurar applets*.
🔧 Validar: fechar a tampa com o modo ligado e conferir que não dorme; desligar
e conferir que volta a dormir.

Fora do alcance (de propósito): bateria crítica do UPower continua podendo
hibernar/desligar — é proteção do hardware, não "dormir".

---

## 2. Pendências que ficaram

| # | Item | Estado | Ação |
|---|------|--------|------|
| P1 | Gestos de 3 dedos (`cosmic-comp`) | 🔧 compilado, **não instalado** | `cosmic-comp/install.sh` num terminal real, digitar `yes`, sair e entrar na sessão. Recuperação: Ctrl+Alt+F3 → `./uninstall.sh`. |
| P2 | Regra da pasta no botão direito | ✅ instalado e visto | Validar uso real: salvar, remover, subpastas. |
| P3 | Snap de bordas (Aero-snap) | ✅ **já existe no COSMIC** | Arrastar janela flutuante para borda/canto encaixa (metade, quarto, maximizar) — nativo desde 2024 (`SnappingZone` no `cosmic-comp`). Item fechado sem código. |
| P4 | Overview do Super: botão X por janela | 📋 em andamento | Portar o X do launcher para `cosmic-workspaces-epoch` e incluir o componente no `install-all.sh`. |
| P5 | Atalho de teclado "mostrar área de trabalho" | ✅ **Super+D** | Atalho personalizado → `cosmic-applet-show-desktop --toggle`. Backup do arquivo de atalhos em `~/.local/state/pop-flow/shortcuts-custom.before-super-d`. |
| P6 | Miniaturas do Alt+Tab em telas/contagens variadas | 📋 precisa de olho | Testar com 2, 8, 20 janelas e com monitor externo. |
| P7 | Árvore do Files com pasta muito grande | 📋 | Medir `column_sort` com ~10 mil itens; se travar, cachear a ordenação por pasta. |
| P8 | `cosmic-wallsync` privado | ✅ sem impacto | O `install-all.sh` já pula repositório que não consegue clonar. Decidir se publica. |
| P9 | ROADMAP desatualizado (gestos como "planejado") | ✅ corrigido nesta rodada | — |

---

## 3. Oportunidades de UX no Pop!_OS (backlog priorizado)

Ordem = ganho no dia a dia ÷ esforço.

1. 💡 **Regra da pasta também na barra lateral do Files** — o mesmo diálogo no menu
   de botão direito dos favoritos. Esforço baixo (reusa o diálogo).
2. 💡 **"Copiar caminho" sempre visível** no menu de arquivo (hoje só com Shift).
   Esforço baixo.
3. 💡 **Vampiro temporário** — clique do meio no morcego: "acordado por 1 h / 3 h"
   e volta sozinho para dormir. Bom para downloads e renderizações. Esforço baixo.
4. 💡 **Outros cantos ativos** — mesmo binário do triângulo, configurável:
   canto superior esquerdo → Overview (Super), por exemplo. Tempo de hover
   configurável. Esforço médio.
5. 💡 **Histórico da área de transferência (Super+V)** — o COSMIC não tem.
   Avaliar applet da comunidade antes de escrever um. Esforço médio.
6. 💡 **Prévia maior no Alt+Tab ao focar** (peek), como no Files. Esforço médio.
7. 💡 **Indicador de "tampa fechada, ainda acordado"** — notificação discreta na
   primeira vez que a tampa fecha em modo vampiro, para não esquecer o PC ligado
   na mochila. Esforço baixo.
8. 💡 **Pastas coloridas no seletor de arquivos** (diálogo "Abrir/Salvar" dos
   apps): já lê as regras; conferir se pinta em todas as visões. Esforço baixo.

---

## 4. Ordem sugerida

1. Instalar `cosmic-applets` (canto por hover + applet vampiro) e validar a tampa.
2. P1 — instalar os gestos quando puder sair da sessão.
3. Oportunidades 1, 2, 3 e 7 (baixas, mesmo dia).
4. P4 — X no Overview.
5. P6/P7 — testes de carga e ajuste fino.

---

## Rodada 2 — tudo implementado (06/10)

| Item | Componente | Commits | Para valer |
|------|-----------|---------|-----------|
| Regra da pasta na barra lateral | cosmic-files | `59b9cad` | `cosmic-files/install.sh` |
| "Copiar caminho" sempre visível | cosmic-files | `8844e45` | idem |
| Pastas coloridas ao vivo no seletor Abrir/Salvar | cosmic-files | `84d3262` | idem |
| Árvore: ordem em cache (10 mil itens: 5 ms → 0,6 ms por quadro) | cosmic-files | `3ac4a14` | idem |
| Vampiro temporário 1 h / 3 h (botão direito no morcego; `--for <min>`) | cosmic-applets | `e8b7cdaa` | `cosmic-applets/install.sh` |
| Aviso "tampa fechada, PC acordado" (uma vez por fechamento) | cosmic-applets | `8d354f6d` | idem |
| Cantos configuráveis + canto superior esquerdo → Overview (desligado por padrão) | cosmic-applets | `c5bd62cc` | idem + `systemctl --user enable --now cosmic-overview-corner` |
| Alt+Tab: regras de tamanho (mín. 120×70, máx. 264×156, paginação "+N") | cosmic-launcher | `f862776` | `cosmic-launcher/install.sh` |
| Alt+Tab: peek 1,2× na janela em foco | cosmic-launcher | `f7adf38` | idem |
| Overview: X ao passar o mouse em cada janela | cosmic-workspaces-epoch | `4524bb8`, `0b35b92` | **antes**: `sudo apt full-upgrade` (o pacote instalado é 0.1.0, o fork é 1.0.12; o instalador recusa) |
| Histórico da área de transferência (Super+V) | cosmic-clipboard-history (novo) | `b9d8178` | `cosmic-clipboard-history/install.sh` (sem sudo) + atalho Super+V |

Histórico da área de transferência: um serviço de usuário grava o que é
copiado (só texto, 200 itens, ignora senhas marcadas por gerenciadores) e um
plugin do pop-launcher lista: **Super+V** abre o launcher com `cb ` digitado,
Enter devolve o texto, Ctrl+V cola. O applet Flatpak de clipboard que estava
instalado nunca funcionou (sandbox sem acesso ao protocolo) — pode remover.
