#!/bin/bash
# Arreglo post-instalación: corrige Phone number ID, número de Lucía, comillas del env y crea el webhook.
set -e
NGROK_DOMAIN="living-tannery-employee.ngrok-free.dev"
ENVF="$HOME/.config/kapso/kapso.env"
get() { grep -m1 "^$1=" "$ENVF" | cut -d= -f2-; }
setv() { if grep -q "^$1=" "$ENVF"; then /usr/bin/sed -i '' "s|^$1=.*|$1=$2|" "$ENVF"; else echo "$1=$2" >> "$ENVF"; fi; }

echo "▶ Corrigiendo configuración"
setv KAPSO_PHONE_NUMBER_ID 1394509480411473
setv OWNER_PHONE 5491136365797
setv CLAUDE_MODEL opus
chmod 600 "$ENVF"

echo "▶ Reiniciando JARVIS"
launchctl kickstart -k "gui/$(id -u)/com.lucia.jarvis.server"
sleep 4
curl -fs localhost:8787/health >/dev/null && echo "Servidor: OK" || { echo "El servidor no arrancó:"; tail -20 "$HOME/whatsapp-assistant/logs/server.log"; exit 1; }
curl -fs "https://$NGROK_DOMAIN/health" >/dev/null && echo "Túnel ngrok: OK" || { echo "El túnel no responde:"; tail -20 "$HOME/whatsapp-assistant/logs/ngrok.log"; }

echo "▶ Conectando WhatsApp (webhook de Kapso)"
if [ -n "$(get KAPSO_WEBHOOK_ID)" ]; then echo "Ya estaba conectado."; exit 0; fi
KEY=$(get KAPSO_API_KEY); PID=$(get KAPSO_PHONE_NUMBER_ID); SEC=$(get KAPSO_WEBHOOK_SECRET)
RESP=$(curl -s -X POST https://api.kapso.ai/platform/v1/whatsapp/webhooks \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" -d '{
  "whatsapp_webhook": {
    "url": "https://'"$NGROK_DOMAIN"'/webhook",
    "phone_number_id": "'"$PID"'",
    "kind": "kapso", "payload_version": "v2", "active": true,
    "secret_key": "'"$SEC"'",
    "events": ["whatsapp.message.received"],
    "buffer_enabled": true, "buffer_window_seconds": 3, "max_buffer_size": 20,
    "buffer_events": ["whatsapp.message.received"]
  }}')
WID=$(printf '%s' "$RESP" | /usr/bin/python3 -c 'import json,sys
d=json.load(sys.stdin); d=d.get("data",d); d=d.get("whatsapp_webhook",d); print(d.get("id",""))' 2>/dev/null || true)
if [ -n "$WID" ]; then
  setv KAPSO_WEBHOOK_ID "$WID"
  echo "Webhook: OK"
  printf "\n✅ Listo. Mandale 'hola' desde tu WhatsApp al +1 208-464-0688.\n"
else
  echo "No pude crear el webhook. Respuesta de Kapso:"; echo "$RESP" | head -c 800; echo
fi
