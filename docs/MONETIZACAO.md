# Monetização: skins, anúncios e compras

## Situação atual

| Recurso | Situação |
|---|---|
| Anúncio entre fases (a cada **2 fases**) | **AdMob real** |
| Anúncio premiado (dobrar moedas, +50 moedas, skin por 3 dias) | **AdMob real** |
| Compras com dinheiro (skins exclusivas e pacotes de moedas) | Simuladas (modo de teste) |

## Anúncios (AdMob)

### Como funciona

- O plugin `android_plugin/` (Java) usa o SDK oficial do Google Mobile
  Ads. O GitHub Actions compila esse plugin e o inclui no APK
  automaticamente.
- `addons/aqua_ads/aqua_ads.gd` coloca o ID do app AdMob no APK e remove
  as permissões de rastreamento.
- `scripts/autoload/monetization.gd` guarda os IDs dos blocos e decide
  quando mostrar.

| Bloco | ID |
|---|---|
| App | `ca-app-pub-4311255826061303~5610988046` |
| Entre fases (intersticial) | `ca-app-pub-4311255826061303/2764286671` |
| Dobrar Moedas, Moedas Grátis, Skins (premiado) | `ca-app-pub-4311255826061303/1946029022` |

### Anúncios de teste e anúncios reais

- O **APK de teste** (o da release `apk-teste`) mostra anúncios de **teste
  do Google**, com a etiqueta "Test Ad". Assim você pode testar e clicar à
  vontade.
  - Clicar nos seus próprios anúncios reais pode suspender a conta AdMob.
  - Se o anúncio de teste aparece, a integração está funcionando.
- A **versão de publicação** (build *release*) usa os seus blocos reais
  automaticamente. Isso é decidido por `OS.is_debug_build()` em
  `monetization.gd`.
- O APK ficou maior porque agora ele é montado pelo Gradle e inclui o SDK
  de anúncios.

### Regras para o público infantil (já configuradas)

Todas as solicitações de anúncio vão com:

- marcação de conteúdo **direcionado a crianças**;
- marcação de **menor de idade**;
- classificação máxima **G** (livre).

O app não declara a permissão de ID de publicidade (`AD_ID`) nem as APIs
de rastreamento do Android (Privacy Sandbox).

No painel do AdMob, confira também:

- **Controles de bloqueio** → classificação máxima de conteúdo **G**;
- as configurações do app para público infantil (tratamento direcionado a
  crianças).

### Comportamento no jogo

- O anúncio entre fases só aparece se já estiver carregado. Se não
  estiver, o jogo segue normalmente, sem espera.
- O premiado mostra "Carregando anúncio..." por até 5 s. Se não houver
  anúncio, avisa e não dá o prêmio.
- O prêmio só é dado se o anúncio for assistido até o fim.
- O som do jogo fica mudo enquanto o anúncio aparece.
- No PC/editor, onde não há AdMob, aparece uma tela simulada.

### Antes de publicar na Play Store

- Gerar o build *release* assinado com a sua chave de publicação (AAB).
  Isso pode ser feito pelo GitHub Actions.
- Vincular o app do AdMob ao app publicado na Play Store.
- Publicar o arquivo `app-ads.txt` no site de desenvolvedor informado na
  Play Store.
- Preencher a política de privacidade e o formulário "Segurança dos dados"
  informando o uso do SDK de anúncios.

## Compras (Google Play Billing), ainda simuladas

Hoje as compras mostram uma tela "MODO DE TESTE" e liberam o item sem
cobrar. **Antes de publicar** é preciso:

1. Usar o plugin **oficial** de pagamentos da Google Play para Godot
   (`godotengine/godot-google-play-billing`).
2. Na **Google Play Console**, criar os produtos com os mesmos IDs usados
   no jogo:
   - skins: `skin_shark`, `skin_robot`, `skin_king`, `skin_lava`. São
     **não consumíveis** (compra única).
   - moedas: `coins_small`, `coins_big`, `coins_mega`. São
     **consumíveis**.
3. Trocar o conteúdo de `purchase()` e `price_of()` em `monetization.gd`.

Os preços reais vêm da Play Store. Os de `TEST_PRICES` são só exemplos.

## Boas práticas já seguidas

- Nenhum anúncio interrompe uma corrida.
- As skins são só visuais: nenhuma vantagem na corrida.
- Dá para jogar tudo sem pagar. Moedas vêm de fases, estrelas, colocação,
  presente diário e anúncios opcionais.
- O progresso, as skins e os aluguéis ficam salvos no aparelho (offline).
