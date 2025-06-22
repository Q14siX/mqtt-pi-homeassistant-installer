#!/bin/bash

# Sprachlogik
LANGUAGE=$(echo "$LANG" | cut -d_ -f1)
if [[ "$LANGUAGE" == "de" ]]; then
  LANG_IS_DE=true
else
  LANG_IS_DE=false
fi

if [[ $EUID -ne 0 ]]; then
  if $LANG_IS_DE; then
    echo "❌ Bitte führe dieses Skript mit 'sudo' aus."
  else
    echo "❌ Please run this script with 'sudo'."
  fi
  exit 1
fi

USER_HOME=$(eval echo ~${SUDO_USER})
BIN_DIR="$USER_HOME/.local/bin"

# Stop and disable systemd service
systemctl stop mqtt-listener.service 2>/dev/null
systemctl disable mqtt-listener.service 2>/dev/null
rm -f /etc/systemd/system/mqtt-listener.service

# Remove binaries
rm -f "$BIN_DIR/mqtt_listener.sh"
rm -f "$BIN_DIR/mqtt_register_buttons.sh"

# Reload systemd daemon
systemctl daemon-reload

if $LANG_IS_DE; then
  echo "✅ MQTT-Dienst, Skripte und Dienstdefinition wurden entfernt."
  echo "ℹ️ Entferne das Gerät manuell aus Home Assistant, falls gewünscht."
else
  echo "✅ MQTT service, scripts, and unit files have been removed."
  echo "ℹ️ Remove the device manually from Home Assistant if needed."
fi
