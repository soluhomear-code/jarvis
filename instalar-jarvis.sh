#!/bin/bash
# Instalador de JARVIS para la Mac de Lucía (versión gratis: corre en la Mac + ngrok).
# Uso:  bash <(curl -fsSL https://raw.githubusercontent.com/soluhomear-code/jarvis/main/instalar-jarvis.sh)
set -e

NGROK_DOMAIN="living-tannery-employee.ngrok-free.dev"
APP="$HOME/whatsapp-assistant"
VAULT="$HOME/cerebro-jarvis"
ENVF="$HOME/.config/kapso/kapso.env"
LA="$HOME/Library/LaunchAgents"

paso() { printf "\n\033[1;32m▶ %s\033[0m\n" "$1"; }
ojo()  { printf "\033[1;33m%s\033[0m\n" "$1"; }

paso "1/9 Homebrew"
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  ojo "Te va a pedir la contraseña de la Mac (no se ve mientras escribís)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile

paso "2/9 Programas (node, git, gh, ngrok, voz gratis)"
brew install node git gh pipx
brew install ngrok/ngrok/ngrok 2>/dev/null || brew install --cask ngrok
pipx install edge-tts >/dev/null 2>&1 || true
pipx ensurepath >/dev/null 2>&1 || true

paso "3/9 Claude Code"
if [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"

paso "4/9 GitHub"
if ! gh auth status >/dev/null 2>&1; then
  ojo "Se va a abrir el navegador: copiá el código que aparece acá y autorizá con tu cuenta soluhomear-code."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git
[ -d "$APP/.git" ]   || gh repo clone soluhomear-code/jarvis "$APP"
[ -d "$VAULT/.git" ] || gh repo clone soluhomear-code/cerebro-jarvis "$VAULT"
mkdir -p "$APP/logs" "$VAULT/Journal"
cp "$VAULT/jarvis-system-prompt.md" "$APP/system-prompt.md"
git -C "$VAULT" config user.name "Lucía (JARVIS)"
git -C "$VAULT" config user.email "alunefemenina@gmail.com"

paso "5/9 Tus claves (pegalas y apretá Enter; no se ven en pantalla)"
read -r -s -p "Clave de Kapso (API key): " KAPSO_API_KEY; echo
read -r -p "Phone number ID del bot (Kapso): " KAPSO_PHONE_NUMBER_ID
read -r -s -p "Authtoken de ngrok: " NGROK_TOKEN; echo
read -r -p "Tu WhatsApp personal con código de país, solo números (ej 5491123456789): " OWNER_PHONE
ngrok config add-authtoken "$NGROK_TOKEN" >/dev/null

paso "6/9 Configuración"
mkdir -p "$(dirname "$ENVF")"
cat > "$ENVF" <<EOF
KAPSO_API_KEY=$KAPSO_API_KEY
KAPSO_PHONE_NUMBER_ID=$KAPSO_PHONE_NUMBER_ID
KAPSO_WEBHOOK_SECRET=$(openssl rand -hex 32)
OWNER_PHONE=$OWNER_PHONE
OWNER_NAME=Lucía
VAULT_PATH=$VAULT
PERMISSIONS=allowlist
GIT_SYNC=1
TZ_NAME=America/Argentina/Buenos_Aires
GREETING_TIME=08:00
GREETING_DAYS=1,2,3,4,5,6
REMIND_MINUTES=10
REMINDER_TEMPLATE=agenda_aviso
REMINDER_TEMPLATE_LANG=es
GREETING_READ=Me.md, Pendientes.md y la nota más reciente de Journal/
GREETING_STYLE=español rioplatense, de vos, cálido, directo y con energía
JARVIS_TOKEN=$(openssl rand -hex 16)
JARVIS_CALL_ME=Lucía
EDGE_TTS_VOICE=es-AR-TomasNeural
EDGE_TTS_RATE=+10%
JARVIS_WAKE_LINE=Buen día, JARVIS.
JARVIS_GREETINGS=¡Buen día|¡Buenas tardes|¡Buenas noches
JARVIS_DEMO=1
EOF
chmod 600 "$ENVF"

paso "7/9 Conectar Claude (único paso manual)"
ojo "Se abre Claude: elegí 'Claude account with subscription', iniciá sesión en el navegador,"
ojo "confiá en la carpeta y cuando veas el cuadro para escribir, escribí /exit y Enter."
read -r -p "Apretá Enter para abrir Claude... " _
( cd "$VAULT" && claude )

paso "8/9 Dejarlo andando solo (se prende con la Mac)"
mkdir -p "$LA"
PATHS="/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cat > "$LA/com.lucia.jarvis.server.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.lucia.jarvis.server</string>
  <key>ProgramArguments</key><array><string>/opt/homebrew/bin/node</string><string>$APP/server.mjs</string></array>
  <key>WorkingDirectory</key><string>$APP</string>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHS</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$APP/logs/server.log</string>
  <key>StandardErrorPath</key><string>$APP/logs/server.log</string>
</dict></plist>
EOF
cat > "$LA/com.lucia.jarvis.tunnel.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.lucia.jarvis.tunnel</string>
  <key>ProgramArguments</key><array><string>/opt/homebrew/bin/ngrok</string><string>http</string><string>--url=$NGROK_DOMAIN</string><string>8787</string><string>--log=stdout</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$APP/logs/ngrok.log</string>
  <key>StandardErrorPath</key><string>$APP/logs/ngrok.log</string>
</dict></plist>
EOF
for s in server tunnel; do
  launchctl bootout "gui/$(id -u)/com.lucia.jarvis.$s" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$LA/com.lucia.jarvis.$s.plist"
done
sleep 5
curl -fs localhost:8787/health >/dev/null && echo "Servidor: OK" || { ojo "El servidor no arrancó. Mirá $APP/logs/server.log"; tail -20 "$APP/logs/server.log"; }

paso "9/9 Conectar WhatsApp con tu Mac (webhook de Kapso)"
source "$ENVF"
RESP=$(curl -s -X POST https://api.kapso.ai/platform/v1/whatsapp/webhooks \
  -H "X-API-Key: $KAPSO_API_KEY" -H "Content-Type: application/json" -d '{
  "whatsapp_webhook": {
    "url": "https://'"$NGROK_DOMAIN"'/webhook",
    "phone_number_id": "'"$KAPSO_PHONE_NUMBER_ID"'",
    "kind": "kapso", "payload_version": "v2", "active": true,
    "secret_key": "'"$KAPSO_WEBHOOK_SECRET"'",
    "events": ["whatsapp.message.received"],
    "buffer_enabled": true, "buffer_window_seconds": 3, "max_buffer_size": 20,
    "buffer_events": ["whatsapp.message.received"]
  }}')
WID=$(printf '%s' "$RESP" | /usr/bin/python3 -c 'import json,sys
d=json.load(sys.stdin); d=d.get("data",d); d=d.get("whatsapp_webhook",d); print(d.get("id",""))' 2>/dev/null || true)
if [ -n "$WID" ]; then
  echo "KAPSO_WEBHOOK_ID=$WID" >> "$ENVF"
  echo "Webhook: OK"
else
  ojo "No pude crear el webhook. Respuesta de Kapso:"; echo "$RESP" | head -c 600; echo
fi

printf "\n\033[1;32m✅ JARVIS instalado.\033[0m\n"
echo "Probalo: desde tu WhatsApp, mandale 'hola' al número del bot."
echo "Logs: tail -f $APP/logs/server.log"
