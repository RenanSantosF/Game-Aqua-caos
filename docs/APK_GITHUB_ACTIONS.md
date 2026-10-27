# APK automático pelo GitHub Actions

A cada `push` na branch **main**, o GitHub compila o jogo e gera um APK
instalável. Não é preciso computador nem Android Studio.

Workflow: `.github/workflows/android-apk.yml`

## Como baixar o APK pelo celular

### Opção 1: Release "apk-teste" (mais fácil)

1. No navegador, abra
   `https://github.com/RenanSantosF/Game-Aqua-caos/releases/tag/apk-teste`
2. Em **Assets**, toque em **`aqua-caos.apk`**.
3. Abra o arquivo baixado e toque em **Instalar**. Se pedir, permita
   **"Instalar apps desconhecidos"** para o navegador.

Essa release é recriada a cada build e sempre tem o APK mais novo.

### Opção 2: Artefato do Actions

1. Abra o repositório → aba **Actions** → **Build APK Android**.
2. Toque na execução mais recente (✅ verde).
3. Em **Artifacts**, baixe **aqua-caos-apk**. Vem um **.zip**; é preciso
   estar logado no GitHub.
4. No app **Arquivos**, extraia o zip e toque no `aqua-caos.apk`.

### Rodar o build manualmente

Aba **Actions** → **Build APK Android** → **Run workflow** → **Run workflow**.
Leva de 3 a 6 minutos.

## O que o workflow faz

1. Instala o Java 17. O Android SDK já vem na máquina do GitHub.
2. Baixa o **Godot 4.3-stable** e os **templates de exportação**, e guarda
   em cache para os próximos builds.
3. Configura o Godot com o SDK e com a keystore de teste `ci/debug.keystore`.
4. Usa o número da execução como `version/code`, para que cada APK seja
   uma versão nova e instale por cima da anterior.
5. Exporta com o preset **"Android"** de `export_presets.cfg`.
6. Publica o APK como artefato e na release `apk-teste`.

## Sobre a assinatura (importante)

- O APK é assinado com a keystore **de teste** `ci/debug.keystore` (senha
  `android`). Por ser sempre a mesma, as atualizações instalam **por cima**
  sem desinstalar.
- Essa keystore é **pública** (está no repositório). Serve só para teste.
- **Para publicar na Google Play** (Etapa 10) será criada uma keystore de
  **release** privada, guardada nos *Secrets* do GitHub e nunca no
  repositório. A Play Store também exige **AAB**, que precisa do "Gradle
  build". Isso também será configurado no Actions.

## Se o build falhar

1. Abra a execução com ❌ → job **apk** → veja o passo em vermelho.
2. Erros comuns:
   - **"No export template found"**: o download dos templates falhou. Rode
     de novo em *Re-run jobs*.
   - **"Could not find keystore"**: o arquivo `ci/debug.keystore` sumiu do
     repositório.
   - **Erro de script GDScript**: o mesmo erro aparece no editor do Godot
     ao abrir o projeto. Corrija lá primeiro.
3. O ícone e o nome do app vêm de `project.godot` e `export_presets.cfg`
   (`package/name`).
