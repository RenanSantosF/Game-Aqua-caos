# Publicar na Google Play: passo a passo

Tudo o que o jogo precisa já está no repositório:

| Item | Onde |
|---|---|
| AAB assinado | Release `apk-teste` → `aqua-caos.aab` (depois do passo 1) |
| Ícone 512×512 | `store/icon_512.png` |
| Banner 1024×500 | `store/<idioma>/feature_graphic_1024x500.png` |
| Capturas 1920×1080 | `store/<idioma>/screenshot_1..8.png` |
| Textos da ficha | `store/LISTING.md` |
| Política de privacidade | `PRIVACY.md` |

Pastas de idioma: `pt-BR`, `en-US` e `es-419` (espanhol da América
Latina).

## 1. Ligar a geração do AAB (uma vez só)

A chave de upload (assinatura) fica **criptografada** em
`ci/upload.keystore.enc`. O GitHub Actions só precisa da senha:

1. No GitHub, abra o repositório e vá em **Settings → Secrets and
   variables → Actions → New repository secret**.
2. Preencha:
   - **Name:** `AAB_KEY_PASSWORD`
   - **Secret:** a senha que você recebeu na conversa.
3. Vá em **Actions → Build APK Android → Run workflow**.
4. Em uns 5 minutos a release `apk-teste` terá também o arquivo
   **`aqua-caos.aab`**.

> Guarde a senha e o arquivo `aqua-caos-upload.keystore` (enviado na
> conversa) em lugar seguro, por exemplo no Google Drive. Se perder, dá
> para pedir ao Google uma nova chave de upload, mas leva alguns dias.

## 2. Criar o app na Play Console

**Criar app:**

- Nome: `Aqua Caos: Desafio Molhado`.
- Idioma padrão: Português (Brasil).
- Tipo: **Jogo**.
- Preço: **Gratuito**.

**Integridade do app → Assinatura do app:** aceite a **Assinatura de apps
do Google Play**, que é o padrão. O Google guarda a chave final; a nossa
é só a de upload.

## 3. Conteúdo do app (Política → Conteúdo do app)

| Pergunta | Resposta |
|---|---|
| Política de privacidade | `https://github.com/RenanSantosF/Game-Aqua-caos/blob/main/PRIVACY.md` |
| Anúncios | **Sim, contém anúncios** |
| Acesso ao app | Todas as funcionalidades estão disponíveis sem restrições |
| ID de publicidade | **Não** usa (o app não declara a permissão `AD_ID`) |
| Público-alvo | Escolha as faixas de idade, por exemplo 6–8, 9–12 e 13+. Incluir menores de 13 coloca o app no programa **Famílias**, e o jogo já está preparado para isso. |
| Classificação de conteúdo (IARC) | Categoria **Jogo**. Violência: só "cartunesca/pastelão" (bonecos são empurrados e caem na água). Sem sangue, medo, linguagem imprópria, drogas, jogos de azar ou interação entre usuários. Compras no app: **não**, por enquanto. Mude para sim quando as compras forem ativadas. |
| Apps do governo, finanças, saúde, notícias | Não |

### Segurança dos dados (Data safety)

Quem coleta dados é o SDK do AdMob. O jogo em si não envia nada.

- O app coleta ou compartilha dados? **Sim**.
- Dados criptografados em trânsito? **Sim**.
- Usuário pode pedir exclusão? Não há conta. Os dados ficam no aparelho e
  somem ao desinstalar.
- Tipos de dados, todos coletados pelo SDK de anúncios, com finalidade
  "Publicidade ou marketing", "Prevenção de fraudes" e "Análise":
  - **Local aproximado** (pelo endereço IP);
  - **Interações com o app** (interação com anúncios);
  - **Diagnóstico** (falhas e desempenho do SDK);
  - **IDs do dispositivo ou outros IDs** (ID do conjunto de apps).
- Confira a lista oficial do Google para o AdMob, que pode mudar:
  https://developers.google.com/admob/android/privacy/play-data-disclosure

## 4. Ficha da loja

**Presença na loja → Página principal da loja:**

1. Copie título, descrição curta e completa de `store/LISTING.md`.
2. Envie o ícone, o banner e as 8 capturas.
3. Em **Gerenciar traduções**, adicione inglês (Estados Unidos) e espanhol
   (América Latina) com os textos e imagens de cada pasta.

**Categoria:** Jogos → **Corrida** (ou Casual). Tags: corrida,
obstáculos, casual.

**Detalhes de contato:** e-mail (obrigatório) e, se tiver, um site.

## 5. Teste fechado (obrigatório para contas novas)

Contas pessoais de desenvolvedor criadas depois de novembro de 2023
precisam fazer um **teste fechado com pelo menos 12 testadores por 14 dias
seguidos** antes de liberar a produção.

1. Vá em **Testes → Teste fechado → Criar faixa**.
2. Envie o `aqua-caos.aab`.
3. Adicione os e-mails dos testadores (amigos e família).
4. Depois dos 14 dias, peça o acesso à produção na própria Play Console.

## 6. Depois de publicar

- **AdMob:** em *Apps → Configurações do app*, vincule o app à Play Store.
  Os anúncios reais só aparecem bem depois disso.
- **app-ads.txt:** se você informar um site na ficha, publique nele o
  arquivo `app-ads.txt` que o AdMob mostra. Sem site, o AdMob mostra um
  aviso, mas os anúncios funcionam.
- **Atualizações:** cada push na `main` gera um AAB novo com número de
  versão maior. É só enviar o novo AAB numa nova versão na Play Console.

## Ainda falta no jogo

- **Compras com dinheiro real** (skins exclusivas e pacotes de moedas):
  - Na versão da loja aparecem como **"Em breve"**, para não liberar nada
    de graça.
  - Para ativar, crie os produtos na Play Console e integre o plugin
    oficial de pagamentos. Veja `docs/MONETIZACAO.md`.
