# ETAPA 1 — Criar o projeto e configurar a tela horizontal

Objetivo: ter o projeto aberto no **Godot 4.3 para Android**, rodando em tela
horizontal 16:9, com a estrutura de pastas pronta para as próximas etapas.

> **Atualização:** o jogo agora é 3D. As instruções de instalação e
> importação abaixo continuam valendo. Veja [JOGO_3D.md](JOGO_3D.md).

---

## 1. Instalar o Godot 4.3 no celular

A versão da Play Store sempre instala a mais nova (pode ser 4.4, 4.5…). Como o
projeto é para **4.3**, use o APK oficial dessa versão:

1. No navegador do celular, abra
   `https://github.com/godotengine/godot/releases/tag/4.3-stable`
2. Em **Assets**, baixe `Godot_v4.3-stable_android_editor.apk`.
3. Abra o arquivo baixado. Se o Android pedir, permita
   **"Instalar apps desconhecidos"** para o navegador/gerenciador de arquivos.
4. Abra o Godot. Quando ele pedir **"Acesso a todos os arquivos"**, permita
   (sem isso ele não enxerga as pastas do projeto).

> Dica: um teclado como o **Hacker's Keyboard** (grátis) facilita digitar
> código, pois tem Tab, Ctrl e setas. Um teclado Bluetooth ajuda ainda mais.

## 2. Colocar o projeto no celular

### Opção A — MGit (recomendado: atualiza com um toque)

1. Instale o **MGit** (grátis, F-Droid ou Play Store).
2. Toque em **+** → **Clone** e use:
   - Remote URL: `https://github.com/RenanSantosF/Game-Aqua-caos.git`
   - Local path: `Game-Aqua-caos`
3. Nas configurações do MGit, ative o armazenamento em uma pasta acessível
   (ex.: `Documents/MGit`). Anote o caminho.
4. Nas próximas etapas, basta abrir o repositório no MGit e tocar em
   **Pull** para receber os novos arquivos.

> Para *enviar* alterações feitas no celular de volta ao GitHub (Push), o
> MGit pede um **token de acesso pessoal** do GitHub no lugar da senha
> (GitHub → Settings → Developer settings → Personal access tokens).

### Opção B — Baixar ZIP

1. Abra o repositório no navegador → botão **Code** → **Download ZIP**.
2. No app **Arquivos** (Files by Google) toque no ZIP → **Extrair**.
3. Mova a pasta extraída para `Documents/Godot/Game-Aqua-caos`.

## 3. Importar no Godot

1. Abra o Godot → **Gerenciador de Projetos**.
2. Toque em **Importar** e navegue até a pasta do projeto.
3. Selecione o arquivo **`project.godot`** → **Importar e Editar**.
4. Na primeira abertura o Godot cria a pasta oculta `.godot/` (cache). Isso é
   normal e ela não vai para o GitHub (está no `.gitignore`).

## 4. Conferir as configurações (já vêm prontas)

Menu **Projeto → Configurações do Projeto**. Ative a chave
**"Configurações Avançadas"** (canto superior direito) para ver tudo.

| Caminho | Valor | Por quê |
|---|---|---|
| Aplicação → Executar → Cena Principal | `res://scenes/main/main.tscn` | Cena que abre ao apertar ▶ |
| Exibição → Janela → Tamanho → Largura/Altura da Viewport | `1280` × `720` | Base 16:9 leve para celulares modestos |
| Exibição → Janela → Esticar → Modo | `canvas_items` | Interface e sprites escalam com nitidez |
| Exibição → Janela → Esticar → Aspecto | `expand` | Telas mais largas (19.5:9, 20:9) mostram mais cenário, sem barras pretas |
| Exibição → Janela → Portátil → Orientação | `Sensor Landscape` | Sempre horizontal, girando para qualquer um dos dois lados |
| Renderização → Renderizador → Método de renderização (e `.mobile`) | `gl_compatibility` | O mais leve e compatível para 2D em Android modesto |
| Renderização → Texturas → Compressão VRAM → Importar ETC2 ASTC | ligado | Exigido para exportar para Android |
| Física → 2D → Gravidade Padrão | `1800` | Pulo mais “cartoon”, rápido (será usado na Etapa 3) |
| Dispositivos de Entrada → Apontamento → Emular Toque com Mouse | ligado | Permite testar botões de toque também no PC, se um dia usar |

Se você preferir criar tudo do zero em vez de importar, basta criar um projeto
novo com o renderizador **Compatibilidade** e ajustar os valores da tabela.

## 5. Estrutura do projeto

```
Game-Aqua-caos/
├── project.godot          ← configurações acima
├── icon.svg               ← ícone provisório
├── assets/
│   ├── sprites/
│   │   ├── characters/    ← personagens (Etapa 2/8)
│   │   ├── obstacles/     ← martelos, cilindros, jatos (Etapa 5)
│   │   ├── environment/   ← água, plataformas, fundo (Etapa 4)
│   │   └── ui/            ← botões, ícones (Etapa 2/7)
│   ├── audio/music/ e audio/sfx/
│   └── fonts/
├── scenes/
│   ├── main/              ← main.tscn + main.gd (teste desta etapa)
│   ├── player/            ← personagem (Etapa 2)
│   ├── levels/            ← fases (Etapa 4)
│   ├── obstacles/         ← um .tscn por obstáculo (Etapa 5)
│   └── ui/                ← HUD, controles de toque, resultados
├── scripts/
│   ├── autoload/          ← scripts globais: save, áudio (Etapa 7–9)
│   └── components/        ← scripts reutilizáveis
└── docs/                  ← este guia e os das próximas etapas
```

Os arquivos `.gitkeep` só existem para o Git guardar pastas vazias; pode
ignorá-los.

### Cena de teste: `scenes/main/main.tscn`

```
Main (Control, tela inteira)         ← script: main.gd
├── Background (ColorRect)           ← céu azul, tela inteira
├── Water (ColorRect)                ← faixa de água de 180 px na base
└── Center (CenterContainer)
    └── VBox (VBoxContainer)
        ├── TitleLabel  "AQUA CAOS"
        ├── SubtitleLabel "Desafio Molhado — Etapa 1 OK!"
        └── InfoLabel   (preenchido pelo script)
```

O script `main.gd` apenas escreve a resolução da tela no `InfoLabel` e se
atualiza se a tela mudar. Nenhum sinal precisa ser conectado manualmente: a
conexão (`size_changed`) é feita no próprio código. Essa cena será
substituída pelo menu/fase nas próximas etapas.

## 6. Testar

1. Toque em **▶ (Executar Projeto)** no canto superior direito do editor.
2. O jogo abre em outra janela, **deitada**, mostrando:
   - "AQUA CAOS" em amarelo;
   - "Desafio Molhado — Etapa 1 OK!";
   - `Tela física: ... Área do jogo: ... Orientação: HORIZONTAL`.
3. Gire o celular para o outro lado: a imagem deve girar junto e continuar
   horizontal.
4. A **Área do jogo** deve ter altura 720 e largura **≥ 1280** (ex.: 1560 em
   celulares 19.5:9). Isso confirma o aspecto `expand`.
5. Para voltar ao editor, use o botão Voltar do Android ou o ■ (Parar).

## 7. Problemas comuns

| Sintoma | Solução |
|---|---|
| Godot não mostra a pasta do projeto | Dê ao Godot a permissão **"Acesso a todos os arquivos"** (Configurações do Android → Apps → Godot → Permissões). |
| "Projeto criado em versão mais nova/antiga" | Você está com outra versão do Godot. Instale o APK **4.3-stable** (passo 1). |
| Aparece "Nenhuma cena principal definida" | Configurações do Projeto → Aplicação → Executar → Cena Principal → escolha `scenes/main/main.tscn`. |
| Jogo abre em pé | Confira **Orientação = Sensor Landscape**. Verifique também se o bloqueio de rotação do Android não está forçando retrato. |
| Barras pretas nas laterais | Confira **Aspecto = expand**. |
| Tela preta/erro de renderização | Confira o renderizador **gl_compatibility** e reinicie o editor (Projeto → Recarregar Projeto Atual). |
| Erro no script `main.gd` | Veja a aba **Saída/Depurador** embaixo. Geralmente é indentação: o GDScript usa **Tab**; não misture com espaços. |

---

✅ **Etapa concluída quando:** o jogo abre deitado, sem barras pretas, com o
texto "Etapa 1 OK!" e a orientação "HORIZONTAL".

Próxima: **ETAPA 2 — personagem e controles de movimento** (botões de toque
← → e pular, mapa de entradas e cena do jogador).
