# ETAPAS 2 a 7: protótipo jogável

Este guia cobre o que foi implementado depois da Etapa 1:

| Etapa | O que entrou |
|---|---|
| 2 | Personagem desenhado por código + controles de toque (← → e PULAR) |
| 3 | Corrida, pulo, gravidade, colisões, superfícies molhadas |
| 4 | Fase 1 "Parque Aquático" com piscina e plataformas |
| 5 | Obstáculos: martelo, boia móvel, jatos d'água, plataformas que somem, boia trampolim, escorregador |
| 6 | Tombos engraçados, respingos, checkpoints e renascimento |
| 7 | Contagem regressiva, cronômetro, linha de chegada, medalhas, recorde, pausa e "Jogar novamente" |

Todos os gráficos são desenhados com código (`_draw()`), sem imagens. Isso
deixa o jogo leve e permite editar cores direto no Inspetor do Godot. Os
sprites definitivos podem substituir os desenhos depois, sem mudar a lógica.

---

## 1. Como atualizar o projeto no celular

- **MGit:** abra o repositório e toque em **Pull**.
- **ZIP:** baixe o ZIP de novo e substitua a pasta.

Depois, no Godot, use **Projeto → Recarregar Projeto Atual**.

Para só **jogar**, sem abrir o Godot, instale o APK. Veja
[APK_GITHUB_ACTIONS.md](APK_GITHUB_ACTIONS.md).

---

## 2. Estrutura das cenas

```
scenes/
├── main/main.tscn              Tela inicial (botão JOGAR)
├── player/
│   ├── player.tscn             CharacterBody2D + colisão + visual + câmera
│   ├── player.gd               Física e estados (normal, tombo, água...)
│   └── player_visual.gd        Desenho e animações do personagem
├── world/
│   ├── platform.tscn/.gd       Plataforma de blocos coloridos
│   ├── water.tscn/.gd          Piscina (derruba quem cair)
│   ├── slide.tscn/.gd          Escorregador molhado
│   ├── checkpoint.tscn/.gd     Bandeira de checkpoint
│   ├── finish_line.tscn/.gd    Linha de chegada
│   └── sign.tscn/.gd           Placa de tutorial
├── obstacles/
│   ├── swinging_hammer         Martelo em pêndulo (empurra)
│   ├── moving_platform         Boia que vai e volta (carrega o jogador)
│   ├── water_jet               Jato d'água em ciclos (arremessa)
│   ├── vanishing_platform      Treme, some e volta
│   └── bounce_pad              Boia trampolim (lança para o alto)
├── effects/splash.tscn         Respingo (partículas + anel)
├── levels/
│   ├── level.gd                Regras da fase (reaproveitável)
│   ├── level_01.tscn           Fase 1: Parque Aquático
│   ├── park_background.tscn    Céu + parallax (nuvens, torres, palmeiras)
│   └── background_layer.gd     Desenho das camadas do fundo
└── ui/
    ├── touch_controls.tscn/.gd Botões de toque (multitoque)
    ├── touch_button.gd         Desenho de cada botão
    ├── hud.tscn/.gd            Cronômetro, quedas, contagem, pausa
    └── result_screen.tscn/.gd  Resultado da corrida
scripts/autoload/game.gd        Autoload "Game": recordes e troca de cena
assets/ui/theme.tres            Tema visual (botões, painéis, fonte)
assets/fonts/LilitaOne-Regular  Fonte gratuita (licença OFL)
```

### Cena do personagem (`player.tscn`)

```
Player (CharacterBody2D)         script: player.gd, camada 2 "Jogador", máscara 1 "Mundo"
├── CollisionShape2D (cápsula 20×80, com o pé na origem)
├── Visual (Node2D)              script: player_visual.gd
└── Camera2D                     suavização ligada, limites definidos pela fase
```

### Cena da fase (`level_01.tscn`)

```
Level01 (Node2D)                 script: level.gd
├── ParkBackground               fundo com parallax
├── World
│   ├── Signs                    placas de tutorial
│   ├── Platforms                plataformas (instâncias de platform.tscn)
│   ├── Slide                    escorregador
│   ├── Obstacles                martelos, boia, jatos, plataformas que somem
│   ├── Checkpoints
│   ├── Pool                     a piscina (água na frente de tudo)
│   ├── LeftWall / RightWall     paredes invisíveis
├── FinishLine
├── Player
├── TouchControls                CanvasLayer 5
├── HUD                          CanvasLayer 10 (funciona mesmo pausado)
└── ResultScreen                 CanvasLayer 20
```

---

## 3. Configurações importantes (já prontas)

**Projeto → Configurações do Projeto**

| Onde | Valor |
|---|---|
| Mapa de Entrada | `move_left` (A, ←), `move_right` (D, →), `jump` (Espaço, W, ↑), `pause` (Esc, P) |
| Autoload | `Game` → `res://scripts/autoload/game.gd` |
| GUI → Tema → Personalizado | `res://assets/ui/theme.tres` |
| Aplicação → Config → Sair ao Voltar | desligado (o botão Voltar do Android **pausa** a corrida) |
| Nomes de Camadas → Física 2D | 1 = Mundo, 2 = Jogador |
| Física → 2D → Gravidade | 1800 |

### Como os controles de toque funcionam

Cada botão é um `TouchScreenButton` com a propriedade **Action** apontando
para `move_left`, `move_right` ou `jump`. O Godot "aperta" a ação sozinho,
com suporte a vários dedos ao mesmo tempo (correr + pular). O
`touch_controls.gd` reposiciona os botões nos cantos em qualquer proporção de
tela. Os botões ← → têm **Passby Press** ligado: dá para deslizar o dedo de um
para o outro.

---

## 4. Sinais (todos conectados por código)

Você **não** precisa conectar nada pela aba "Nó → Sinais". O `level.gd`
conecta tudo em `_ready()`:

| Sinal | Quem emite | O que acontece |
|---|---|---|
| `fell_in_water` | Player | soma +1 em QUEDAS |
| `activated` | Checkpoint | mostra "CHECKPOINT!" |
| `crossed` | FinishLine | para o cronômetro e mostra o resultado |
| `restart_requested` / `menu_requested` | HUD (pausa) | recomeça / volta ao menu |
| `retry_requested` / `menu_requested` | ResultScreen | joga de novo / menu |

Os obstáculos não usam sinais: eles chamam direto os métodos do personagem
(`knockback()`, `launch()`, `enter_water()`).

---

## 5. Ajustando pelo Inspetor (sem programar)

Selecione o nó na árvore da cena e mude no **Inspetor**:

- **Player**: `Run Speed`, `Jump Velocity`, `Slope Slide Accel`, `Knock Time`...
  (grupos "Corrida", "Pulo", "Superfícies molhadas", "Quedas").
- **Player → Visual**: cores da pele, camiseta, short e boné (é assim que
  as skins da Etapa 8 vão funcionar).
- **Platform**: `Size`, `Colors`, `Slippery` (molhada), `Pillar Depth`.
- **SwingingHammer**: `Arm Length`, `Max Angle Degrees`, `Period`, `Phase`, `Push`.
- **MovingPlatform**: `Travel` (quanto anda), `Period`, `Phase`.
- **WaterJet**: `Off Time`, `Warn Time`, `On Time`, `Time Offset`, `Push`.
- **VanishingPlatform**: `Warn Time`, `Gone Time`.
- **Level01**: `Gold Time` e `Silver Time` (medalhas).

Os scripts usam `@tool`, então plataformas, água, martelos e placas aparecem
desenhados **dentro do editor** enquanto você ajusta.

### Criar um novo trecho da fase

1. Abra `scenes/levels/level_01.tscn`.
2. Selecione `World/Platforms` → ícone de **corrente** (Instanciar Cena
   Filha) → `scenes/world/platform.tscn`.
3. Arraste a plataforma ou digite `Position` no Inspetor. O topo das
   plataformas da fase 1 fica em **y = 540**, e a água em **y = 600**.
4. Ajuste `Size`. Um pulo alcança ~320 px de distância e ~170 px de altura.

---

## 6. Testar

1. Toque em **▶**. Aparece a tela inicial com o personagem comemorando.
2. Toque em **JOGAR**. Contagem **3, 2, 1, JÁ!**
3. Percurso da fase 1 (≈ 25 a 60 s):
   1. corra e pule o primeiro buraco;
   2. passe pelo **martelo** (pule sobre ele ou espere ele ir embora);
   3. suba na **boia móvel** e pule para o outro lado;
   4. suba os degraus e desça o **escorregador** (você acelera!);
   5. a **boia trampolim** lança você sobre a piscina → **checkpoint**;
   6. segundo martelo; depois a **passarela** com **jatos d'água** (espere
      as bolhas sumirem);
   7. **plataformas rosas** que somem → **CHEGADA**.
4. Caia na água de propósito: respingo, contador QUEDAS +1 e renascimento
   piscando no último checkpoint.
5. Toque em **II** (ou no Voltar do Android) para pausar.
6. Na chegada: medalha (ouro ≤ 30 s, prata ≤ 55 s, senão bronze), recorde,
   e os botões **JOGAR NOVAMENTE** e **MENU**.

> O recorde por enquanto fica só na memória: ao fechar o jogo ele zera. O
> salvamento no aparelho chega na **Etapa 9**.

## 7. Problemas comuns

| Sintoma | Solução |
|---|---|
| Botões de toque não aparecem no PC | Normal: só aparecem em telas de toque. Para testar no PC, marque `Always Visible` em `TouchControls`. |
| "Identifier 'Game' not declared" | Confira o autoload `Game` em Configurações do Projeto → Autoload. |
| Botões/textos com fonte padrão | Confira GUI → Tema → Personalizado = `res://assets/ui/theme.tres`. |
| Personagem atravessa plataforma nova | Use uma instância de `platform.tscn` (camada 1 "Mundo"). Duplicar uma existente com Ctrl+D também funciona. |
| Mudou `Size` e a colisão não acompanhou | Feche e reabra a cena. O shape é "local à cena", cada cópia tem o seu. |
| Erro vermelho na aba Depurador | Leia a linha indicada. Em GDScript, use **Tab** para indentar, sem misturar com espaços. |

---

✅ **Protótipo concluído quando:** você consegue ir do início até a chegada,
cair na água e renascer, ver o resultado e jogar de novo.

Próxima: **ETAPA 8: moedas, personagens e desbloqueios.**
