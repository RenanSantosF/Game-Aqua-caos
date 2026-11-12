#!/usr/bin/env bash
# Ajustes no modelo Gradle do Godot (android/build) para os avisos da Play Console:
#  1. "O app usa APIs ou parâmetros descontinuados para exibição de ponta a ponta"
#     - core-splashscreen 1.0.1 -> 1.2.0 (a 1.0.1 chama Window.setStatusBarColor /
#       setNavigationBarColor, descontinuados no Android 15);
#     - build release com R8 só removendo código que nunca é usado (sem ofuscar
#       nem otimizar): sai o androidx.activity.EdgeToEdge*, que o jogo não usa e
#       que também chama essas APIs.
#  2. "Remova as restrições de redimensionamento e orientação" é resolvido no
#     projeto (orientação Sensor + autoload ScreenFit), não aqui.
# Uso: ci/android_play_compat.sh [pasta do android/build]
set -euo pipefail
B="${1:-android/build}"
test -f "$B/build.gradle"

sed -i "s/splashscreenVersion *: *'[^']*'/splashscreenVersion: '1.2.0'/" "$B/config.gradle"
grep -n "splashscreenVersion" "$B/config.gradle"

cat > "$B/play-compat-rules.pro" <<'EOF'
# Mantém TODO o código como está (Godot chama Java por nome via JNI/reflexão);
# só não força manter as classes EdgeToEdge do androidx.activity, que ninguém usa.
-dontobfuscate
-dontoptimize
-dontwarn **
-ignorewarnings
-keepattributes *
-keep class !androidx.activity.EdgeToEdge**,** { *; }
EOF

if ! grep -q "play-compat-rules.pro" "$B/build.gradle"; then
  # adiciona minify no bloco "release {" de buildTypes (primeira ocorrência após buildTypes)
  awk '
    /buildTypes[[:space:]]*\{/ { inbt=1 }
    inbt && !done && /^[[:space:]]*release[[:space:]]*\{/ {
      print
      print "            minifyEnabled true"
      print "            shrinkResources false"
      print "            proguardFiles \"play-compat-rules.pro\""
      done=1; next
    }
    { print }
  ' "$B/build.gradle" > "$B/build.gradle.tmp" && mv "$B/build.gradle.tmp" "$B/build.gradle"
fi
grep -n -A4 "^[[:space:]]*release[[:space:]]*{" "$B/build.gradle" | head -8
grep -q "play-compat-rules.pro" "$B/build.gradle"
