# Aqua Caos 3D: jogabilidade, fases infinitas e rivais

Esta versão (0.3) refaz o jogo em **3D** com foco na jogabilidade. Tudo é
gerado por código (personagens, obstáculos, cenário, sons), então não há
arquivos de modelo 3D ou de áudio para gerenciar no celular.

## Como jogar

| Ação | Celular | PC (teste) |
|---|---|---|
| Andar/correr | Joystick: encoste o dedo em qualquer ponto da metade esquerda | WASD ou setas |
| Pular | Botão **PULAR** (segure para pular mais alto) | Espaço |
| Mergulhar | Botão **MERGULHO**: dá um impulso de barriga para a frente, também no ar | Shift, E ou J |
| Pausar | Botão **II** ou o Voltar do Android | Esc ou P |

**Dica:** pule e mergulhe no ar para alcançar vãos maiores. No escorregador,
continue segurando para frente para ganhar velocidade.

## O que tem no jogo

- **Boneco cartoon 3D** com contorno de desenho animado e animações
  exageradas: corrida, pulo, mergulho, barrigada, tombo girando com olhos
  tontos, nado desesperado e comemoração. Uma sombra redonda embaixo dele
  ajuda a acertar os pulos.
- **Física divertida:** aceleração rápida, pulo variável, *coyote time*
  (ainda dá para pular logo depois de sair da borda), memória de pulo,
  superfícies molhadas que escorregam, empurrões com tombo e
  invulnerabilidade curta ao levantar.
- **12 tipos de trecho:**
  - pulos entre plataformas;
  - bastão giratório;
  - martelos em pêndulo;
  - plataformas móveis (para os lados ou para frente);
  - escorregador molhado com boia no fim;
  - boias trampolim em sequência;
  - piso que cai;
  - paredes que dão soco;
  - bolas gigantes rolando rampa abaixo;
  - discos giratórios;
  - esteira que puxa para trás;
  - gêiseres (inclusive um paredão que só se sobe usando o jato).
- **Fases infinitas:** cada número de fase gera sempre o mesmo percurso. A
  dificuldade cresce até a fase ~40 e depois estabiliza. Novos obstáculos
  são liberados aos poucos: martelos na fase 2, piso que cai na 3, socos na
  4, bolas na 5, discos na 6, esteira na 7 e gêiseres na 8. A fase que
  libera um obstáculo sempre o traz.
- **5 ambientações** em rodízio: Parque Tropical, Pôr do Sol, Lagoa Neon
  (noite com postes coloridos), Ilha dos Doces e Recife de Coral. Cada fase
  tem um nome próprio.
- **Mundo vivo:** ilhas com coqueiros e guarda-sóis, torres de tobogã ao
  longe, boias balançando, golfinhos saltando, gaivotas voando, nuvens e
  torcida pulando nas arquibancadas da largada e da chegada.
- **Rivais controlados pelo computador:** de 3 a 5 bonecos com nome e cor
  (Pingo, Sapeca, Tubinha, Jujuba, Robô Bolha) disputam a corrida. Eles
  erram, caem e ficam mais espertos nas fases avançadas. O HUD mostra sua
  posição ao vivo (ex.: **2º/6**).
- **Progressão salva no aparelho** (offline): moedas, fase liberada,
  recordes e estrelas.
  - **Estrelas:** 3 se terminar dentro do tempo-alvo, 2 até 1,5× o tempo,
    1 só por terminar.
  - **Moedas:** as coletadas na fase, mais bônus por chegar, por não cair
    na água e por terminar em 1º, 2º ou 3º lugar.
- **Menu 3D** com o boneco comemorando num pódio, câmera girando, botão
  JOGAR, seleção de fases (páginas de 20) e som liga/desliga.
- **Sons** de pulo, mergulho, moeda, respingo, batida, boia, checkpoint,
  contagem e vitória, todos sintetizados por código.

## Estrutura

```
scenes/
├── menu/            menu.tscn/.gd: menu 3D e seleção de fases
├── levels/          level.tscn/.gd: monta a fase, rivais, contagem, chegada
├── player/          player.tscn/.gd (física), character_model.gd (boneco),
│                    follow_camera.gd (câmera)
└── ui/              hud, result_screen, touch_controls, virtual_joystick,
                     touch_button, star_icon
scripts/
├── autoload/        game.gd (progresso e salvamento), sfx.gd (sons)
├── level/           course_builder.gd (gerador de fases), bot_brain.gd (IA)
├── obstacles/       sweeper, pendulum_hammer, moving_platform, spinning_disc,
│                    vanishing_tile, bounce_pad, pusher, ball_roller,
│                    geyser, conveyor
└── world/           themes.gd (ambientações), world_decor.gd (cenário vivo),
                     world_setup.gd (céu, sol, água), build.gd e mat.gd
                     (formas e materiais), coin, checkpoint, finish_gate, splash
shaders/water.gdshader   água com ondas e brilho
```

## Ajustes rápidos (sem programar muito)

- **Física do personagem:** abra `scenes/player/player.tscn`, selecione
  `Player` e mude no Inspetor (grupos Corrida, Pulo, Mergulho, Superfícies
  molhadas e Quedas).
- **Câmera:** em `scenes/levels/level.tscn`, nó `FollowCamera` → `Offset`
  (distância e altura) e `Follow Speed`.
- **Dificuldade e obstáculos:** em `scripts/level/course_builder.gd`:
  - `UNLOCK` define em que fase cada trecho aparece;
  - cada função `_seg_*` controla um trecho (vãos, velocidades, quantidades);
  - `difficulty` define a curva de dificuldade.
- **Cores e ambientações:** em `scripts/world/themes.gd`. Para criar um
  tema novo, copie um bloco `{ ... }` e mude as cores.
- **Rivais:** `RIVALS` em `scenes/levels/level.gd` (nome e cores). A
  habilidade deles está em `_spawn_rivals()`.

## Como foi testado

- Todos os scripts e cenas carregam sem erro no Godot 4.3.
- Um **robô de teste** jogou as fases automaticamente. As fases 1, 2 e 4
  foram concluídas sem cair, com tempo abaixo do alvo.
- Corridas só com os rivais nas fases 1 a 60 mostraram que eles terminam a
  maioria delas. Isso confirma que os percursos são possíveis de completar.
- Capturas renderizadas de vários trechos e temas foram conferidas.

## Limitações conhecidas

- Os rivais às vezes empacam num trecho difícil. Depois de 9 s parados,
  eles voltam ao último checkpoint.
- O jogador e os rivais atravessam uns aos outros (sem trombadas).
- Em celulares muito fracos, desligue as sombras: em
  `scripts/world/world_setup.gd`, troque `sun.shadow_enabled = true` por
  `false`.

## Próximas etapas sugeridas

1. Tela de entrada rica com perfil (nome, avatar), recompensa diária e
   notícias.
2. Loja e customização: cores, bonés, roupas e acessórios comprados com
   moedas.
3. Missões diárias e conquistas.
4. Pacotes de recompensa. Compras com dinheiro real exigem o plugin
   oficial **Google Play Billing** para Godot e uma conta de desenvolvedor
   na Play Console.
5. Anúncios recompensados opcionais, com SDK certificado para o programa
   "Famílias" do Google Play.
6. Músicas de fundo e mais temas.
