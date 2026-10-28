# Aqua Caos 3D: jogabilidade, fases infinitas e rivais

Versão 0.4. Personagens, obstáculos e cenário são gerados por código. As
músicas e os efeitos sonoros são arquivos `.ogg` criados pelo script
`tools/audio/generate_audio.py`.

## Como jogar

| Ação | Celular | PC (teste) |
|---|---|---|
| Andar/correr | Joystick: encoste o dedo em qualquer ponto da metade esquerda | WASD ou setas |
| Pular | Botão **PULAR**. O pulo tem sempre a mesma altura. | Espaço |
| Mergulhar | Toque em **PULAR** de novo ainda no ar: o boneco dá um impulso de barriga para a frente | Espaço no ar |
| Girar a câmera | Arraste o dedo na metade direita da tela | Q / E |
| Pausar | Botão **II** ou o Voltar do Android | Esc ou P |

O joystick anda na direção da câmera. Depois de 2,5 s sem mexer nela, a
câmera volta sozinha para trás do boneco, um pouco de cima e de lado
(visão 3/4).

## Como as fases "incontáveis" funcionam (não são falsas)

Cada fase é **gerada por um algoritmo** a partir do número dela, em
`scripts/level/course_builder.gd`:

1. O número vira uma semente: `hash("aqua_caos_fase_%d" % fase)`. A mesma
   fase gera sempre o mesmo percurso, em qualquer celular, e cada número
   gera um percurso diferente.
2. O gerador escolhe uma lista de trechos. Fases mais altas têm mais
   trechos: 5 + fase/4, até 11 trechos, com curvas entre eles.
3. Cada trecho é montado de verdade (plataformas, colisões, obstáculos,
   moedas). Ele é girado e encaixado na ponta do anterior, então o
   percurso faz curvas, sobe e desce.
4. A dificuldade cresce até a fase ~40 e depois estabiliza: vãos maiores,
   obstáculos mais rápidos, vento mais forte.

Ou seja, não existe uma lista fixa de fases salva no jogo. O limite é só o
número inteiro do Godot, mais de 2 bilhões de fases. Os rivais conseguem
terminar as fases nos testes automáticos, o que mostra que os percursos
são possíveis de completar.

### Tipos de trecho (20)

| Fase em que aparece | Trechos |
|---|---|
| 1 | pulos entre plataformas, bastão giratório, escorregador, curvas |
| 2 | martelos em pêndulo, plataformas móveis, boias trampolim, tobogã em zigue-zague |
| 3 | piso que cai, troncos rolantes |
| 4 | paredes que dão soco, ventiladores de vento |
| 5 | bolas gigantes, elevadores |
| 6 | discos giratórios, rampa de salto |
| 7 | esteira, vigas estreitas |
| 8 | gêiseres |
| 9 | tambor giratório |

A fase que libera um trecho novo sempre o traz. Há placas avisando cada
trecho e checkpoints a cada 3 trechos.

## Telas

- **Menu:** logotipo animado, moedas, presente diário (sequência de dias
  dá mais moedas), configurações (som, música e idioma), JOGAR, LOJA e
  MAPA.
- **Mapa:** caminho sinuoso e infinito com as fases, estrelas e regiões
  coloridas por ambientação. Ao vencer, o boneco anda até a próxima fase.
- **Loja:** prévia 3D do boneco girando num pódio.
  - Skins por moedas, skins grátis por anúncio (3 dias) e skins
    exclusivas pagas.
  - Pacotes de moedas.
  - Detalhes em [MONETIZACAO.md](MONETIZACAO.md).
- **Resultado:** colocação, estrelas, tempo, recorde e moedas, com opção
  de dobrar as moedas assistindo um anúncio.
- As trocas de tela usam uma transição em círculo.

## Sons e músicas

- Músicas infantis alegres (marimba, sininhos, flauta): menu, mapa e duas
  músicas de corrida que se alternam.
- Vinhetas de vitória (1º a 3º lugar) e de chegada.
- Efeitos suaves, sem agudos estridentes.
- Para mudar, edite `tools/audio/generate_audio.py` e rode
  `python3 tools/audio/generate_audio.py`. Ele precisa de numpy, scipy e
  ffmpeg.

## Idiomas

Português, inglês e espanhol. Na primeira abertura o jogo usa o idioma do
celular. Se não for nenhum dos três, usa português. Dá para trocar no menu
(engrenagem → idioma).

Os textos ficam em `assets/i18n/strings.csv`, uma coluna por idioma.

## Gráficos

- Sombras com mapa de 4096 (2048 no celular), filtro suave e alcance
  menor. Isso deixa a sombra mais nítida e sem serrilhado.
- Antisserrilhado MSAA 4x.
- Em celulares muito fracos, desligue as sombras: em
  `scripts/world/world_setup.gd`, troque `sun.shadow_enabled = true` por
  `false`.

## Estrutura

```
scenes/
├── menu/       tela inicial
├── map/        mapa de fases
├── shop/       loja de skins e moedas
├── levels/     level.tscn/.gd: monta a fase, rivais, contagem e chegada
├── player/     player.gd (física), character_model.gd (boneco e acessórios),
│               follow_camera.gd (câmera)
└── ui/         hud, result_screen, touch_controls, test_ad_overlay
scripts/
├── autoload/   game (progresso, skins, idioma), sfx, music, monetization,
│               transition
├── level/      course_builder (gerador de fases), bot_brain (IA dos rivais),
│               path_tracker (progresso na rota)
├── obstacles/  sweeper, pendulum_hammer, moving_platform, spinning_disc,
│               vanishing_tile, bounce_pad, pusher, ball_roller, geyser,
│               conveyor, log_roller, spinning_drum, wind_fan, jump_ramp
├── ui/         ui_kit (botões e animações), bean_icon, coin_icon
└── world/      themes, skins, world_decor, world_setup, build, mat, coin,
                checkpoint, finish_gate, splash
assets/audio/   músicas e efeitos (.ogg)
assets/i18n/    traduções
tools/audio/    gerador das músicas e efeitos
```

## Ajustes rápidos

- **Física do personagem:** `scenes/player/player.tscn`, nó `Player`, no
  Inspetor.
- **Câmera:** `scenes/player/follow_camera.gd`:
  - `distance`: distância;
  - `pitch_degrees`: altura do ângulo;
  - `side_degrees`: quanto fica de lado.
- **Dificuldade:** `scripts/level/course_builder.gd`:
  - `UNLOCK`: fase em que cada trecho aparece;
  - funções `_seg_*`: cada trecho;
  - `difficulty`: curva de dificuldade.
- **Skins:** `scripts/world/skins.gd`.
- **Anúncio entre fases:** `INTERSTITIAL_EVERY` em
  `scripts/autoload/game.gd`.

## Limitações conhecidas

- Nas fases muito longas, algum rival às vezes empaca. Depois de 10 s
  parado, ele volta ao último checkpoint. Se cair 2 vezes no mesmo ponto,
  ganha uma proteção temporária.
- O jogador e os rivais atravessam uns aos outros (sem trombadas).
- Anúncios e compras estão em **modo de teste** (ver
  [MONETIZACAO.md](MONETIZACAO.md)).
