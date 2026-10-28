# Monetização: skins, anúncios e compras

## O que já está pronto (modo de teste)

Todo o fluxo do jogo já funciona, usando telas **simuladas** marcadas como
"MODO DE TESTE — NÃO É UM ANÚNCIO REAL". Nenhum valor é cobrado e nenhum
anúncio de verdade é exibido.

| Recurso | Onde | Como funciona |
|---|---|---|
| Skins com moedas | Loja → SKINS | 7 skins de 150 a 900 moedas |
| Skins grátis por anúncio | Loja → SKINS ("Grátis: anúncio") | Assistir um anúncio recompensado libera a skin por **3 dias**. Assistir de novo soma mais 3 dias. Quando vence, a skin volta para a Clássica sozinha. |
| Skins exclusivas | Loja → SKINS ("Exclusiva") | Compra com dinheiro real: Tubarão, Robô Bolha, Rei da Piscina, Dragão de Lava |
| Pacotes de moedas | Loja → MOEDAS | 3 pacotes com dinheiro real e +50 moedas grátis assistindo anúncio |
| Dobrar moedas | Tela de resultado | Anúncio recompensado opcional que dobra as moedas da fase |
| Anúncio entre fases | Ao sair do resultado | A cada **2 fases concluídas**. Nunca aparece no meio de uma corrida. |

Todas as chamadas passam por um único arquivo:
`scripts/autoload/monetization.gd`. As funções usadas pelo jogo são:

- `show_interstitial()`: anúncio entre fases;
- `show_rewarded() -> bool`: anúncio recompensado (retorna se foi assistido até o fim);
- `purchase(produto) -> bool`: compra (retorna se foi concluída);
- `price_of(produto)`: preço exibido na loja.

Para ligar os serviços reais, basta trocar o conteúdo dessas funções. O
resto do jogo não muda.

## O que é preciso para publicar com anúncios e compras reais

### 1. Exportação com "Gradle build"

Plugins Android do Godot (anúncios e pagamentos) exigem o modo **Gradle
build** na exportação. O workflow do GitHub Actions precisará:

- instalar o template de build Android do Godot 4.3 (`android_source.zip`);
- ligar `gradle_build/use_gradle_build=true` em `export_presets.cfg`;
- copiar os plugins para `android/plugins`.

Isso dá para fazer inteiramente pelo GitHub Actions, sem computador.

### 2. Compras (Google Play Billing)

- Use o plugin **oficial** de pagamentos da Google Play para Godot
  (repositório `godotengine/godot-google-play-billing`) e siga a
  documentação dele.
- Na **Google Play Console**, crie os produtos com os mesmos IDs usados no
  jogo:
  - skins: `skin_shark`, `skin_robot`, `skin_king`, `skin_lava`;
  - moedas: `coins_small`, `coins_big`, `coins_mega`.
- Skins são produtos **não consumíveis** (compra única). Moedas são
  **consumíveis**.
- Os preços reais vêm da Play Store. Os de `TEST_PRICES` são só exemplos.

### 3. Anúncios

**Atenção: o jogo atrai crianças.** A Google Play exige que apps para o
público infantil participem do programa **Famílias** e usem somente SDKs de
anúncio **autocertificados para Famílias**, com anúncios adequados à idade:
sem anúncios personalizados e sem rastreamento de crianças.

- O AdMob é certificado para Famílias quando configurado como
  "direcionado a crianças" (tag *child-directed* / classificação máxima G).
- Para usar AdMob no Godot é preciso um plugin Android de terceiros
  compatível com Godot 4.3. Escolha um mantido e siga a documentação
  **dele**. Este projeto não inventa chamadas de API.
- Configure o consentimento (UMP/GDPR) e a política de privacidade antes de
  publicar.
- Frequência atual: 1 anúncio entre fases a cada 2 fases
  (`Game.INTERSTITIAL_EVERY`). Anúncios recompensados são sempre
  opcionais.

### 4. Desligar o modo de teste

Depois de integrar os plugins, em `scripts/autoload/monetization.gd`:

1. troque `TEST_MODE := true` por `false`;
2. implemente as chamadas reais dentro de `show_interstitial`,
   `show_rewarded`, `purchase` e `price_of`.

## Boas práticas já seguidas

- Nenhum anúncio interrompe uma corrida.
- As skins são só visuais: nenhuma vantagem na corrida.
- Dá para jogar tudo sem pagar. Moedas vêm de fases, estrelas, colocação,
  presente diário e anúncios opcionais.
- O progresso, as skins e os aluguéis ficam salvos no aparelho (offline).
