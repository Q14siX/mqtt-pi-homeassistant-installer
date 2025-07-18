#!/bin/bash
clear

# Sprache erkennen
LANGUAGE=$(echo "$LANG" | cut -d_ -f1)
if [[ "$LANGUAGE" == "de" ]]; then
  LANG_IS_DE=true
else
  LANG_IS_DE=false
fi

# Prüfen, ob Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  if $LANG_IS_DE; then echo "❌ Bitte führe dieses Skript mit 'sudo' aus."; else echo "❌ Please run this script with 'sudo'."; fi
  exit 1
fi

if $LANG_IS_DE; then echo "🔧 MQTT-Einrichtung für Raspberry Pi und Home Assistant"; else echo "🔧 MQTT setup for Raspberry Pi and Home Assistant"; fi
echo "----------------------------------------------"

DEFAULT_HA_IP=$(getent hosts homeassistant | head -n1 | awk '{ print $1 }')
if [ -z "$DEFAULT_HA_IP" ]; then DEFAULT_HA_IP="192.168.178.100"; fi

if $LANG_IS_DE; then read -p "IP-Adresse deines Home Assistant (ENTER für $DEFAULT_HA_IP): " MQTT_BROKER; else read -p "Home Assistant IP address (ENTER for $DEFAULT_HA_IP): " MQTT_BROKER; fi
MQTT_BROKER=${MQTT_BROKER:-$DEFAULT_HA_IP}

if $LANG_IS_DE; then read -p "MQTT-Benutzer (ENTER für HomeAssistant): " MQTT_USER; else read -p "MQTT username (ENTER for HomeAssistant): " MQTT_USER; fi
MQTT_USER=${MQTT_USER:-HomeAssistant}

if $LANG_IS_DE; then read -p "MQTT-Passwort (ENTER für HomeAssistant): " MQTT_PASS; else read -p "MQTT password (ENTER for HomeAssistant): " MQTT_PASS; fi
MQTT_PASS=${MQTT_PASS:-HomeAssistant}

if $LANG_IS_DE; then read -p "Gerätename (DEVICE_NAME) (ENTER für Hostname $(hostname)): " DEVICE_NAME; else read -p "Device name (DEVICE_NAME) (ENTER for hostname $(hostname)): " DEVICE_NAME; fi
DEVICE_NAME=${DEVICE_NAME:-$(hostname)}

if $LANG_IS_DE; then read -p "Geräte-ID (DEVICE_ID) (ENTER für Hash des Hostnames): " DEVICE_ID; else read -p "Device ID (DEVICE_ID) (ENTER for hash of hostname): " DEVICE_ID; fi
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID=$(echo -n "$DEVICE_NAME" | sha256sum | cut -c1-8)
  if $LANG_IS_DE; then
    echo "🔐 Automatisch generierte DEVICE_ID: $DEVICE_ID"
  else
    echo "🔐 Automatically generated DEVICE_ID: $DEVICE_ID"
  fi
fi

PI_USER=$(logname)
USER_HOME=$(eval echo ~$PI_USER)

apt update && apt upgrade -y
apt install -y mosquitto-clients

mkdir -p "$USER_HOME/.local/bin"

# mqtt_register_buttons.sh
cat <<EOF > "$USER_HOME/.local/bin/mqtt_register_buttons.sh"
#!/bin/bash

MQTT_BROKER="$MQTT_BROKER"
MQTT_USER="$MQTT_USER"
MQTT_PASS="$MQTT_PASS"
DEVICE_NAME="$DEVICE_NAME"
DEVICE_ID="$DEVICE_ID"
MANUFACTURER=\$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "Raspberry Pi Foundation")
MODEL=\$(tr -d ' ' < /proc/device-tree/model 2>/dev/null || echo "Raspberry Pi")

publish_button() {
  local NAME=\$1
  local PAYLOAD=\$2
  mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "homeassistant/button/\${DEVICE_NAME}_\${NAME}/config" -m "{
    \"name\": \"\${NAME^}\",
    \"unique_id\": \"\${DEVICE_ID}_\${NAME}\",
    \"command_topic\": \"\${DEVICE_NAME}/control\",
    \"payload_press\": \"\$PAYLOAD\",
    \"device\": {\"identifiers\": [\"\${DEVICE_ID}\"], \"name\": \"\${DEVICE_NAME}\", \"manufacturer\": \"\${MANUFACTURER}\", \"model\": \"\${MODEL}\"}
  }" -r
}

publish_button reboot reboot
publish_button shutdown shutdown
publish_button update update
publish_button ping ping

mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "homeassistant/binary_sensor/\${DEVICE_NAME}_status/config" -m "{
  \"name\": \"\${DEVICE_NAME^} Online\",
  \"unique_id\": \"\${DEVICE_ID}_status\",
  \"state_topic\": \"\${DEVICE_NAME}/status\",
  \"payload_on\": \"online\",
  \"payload_off\": \"offline\",
  \"device_class\": \"connectivity\",
  \"device\": {\"identifiers\": [\"\${DEVICE_ID}\"], \"name\": \"\${DEVICE_NAME}\", \"manufacturer\": \"\${MANUFACTURER}\", \"model\": \"\${MODEL}\"}
}" -r

mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "homeassistant/sensor/\${DEVICE_NAME}_feedback/config" -m "{
  \"name\": \"\${DEVICE_NAME^} Feedback\",
  \"unique_id\": \"\${DEVICE_ID}_feedback\",
  \"state_topic\": \"\${DEVICE_NAME}/feedback\",
  \"device\": {\"identifiers\": [\"\${DEVICE_ID}\"], \"name\": \"\${DEVICE_NAME}\", \"manufacturer\": \"\${MANUFACTURER}\", \"model\": \"\${MODEL}\"}
}" -r
EOF

chmod +x "$USER_HOME/.local/bin/mqtt_register_buttons.sh"

# mqtt_listener.sh
cat <<EOF > "$USER_HOME/.local/bin/mqtt_listener.sh"
#!/bin/bash

MQTT_BROKER="$MQTT_BROKER"
MQTT_USER="$MQTT_USER"
MQTT_PASS="$MQTT_PASS"
DEVICE_NAME="$DEVICE_NAME"
STATUS_TOPIC="\${DEVICE_NAME}/status"
CONTROL_TOPIC="\${DEVICE_NAME}/control"
FEEDBACK_TOPIC="\${DEVICE_NAME}/feedback"

mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$STATUS_TOPIC" -m "online" -r
mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "📡 IP-Adresse: $(hostname -I | awk '{print $1}')"

mosquitto_sub -v -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$CONTROL_TOPIC" \
  --will-topic "\$STATUS_TOPIC" --will-payload "offline" --will-retain --id "\${DEVICE_NAME}-listener" |
while read -r line; do
  cmd=\$(echo "\$line" | cut -d' ' -f2)
  case "\$cmd" in
    reboot)
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$STATUS_TOPIC" -m "offline" -r
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "🔄 Rebooting..."
      sudo reboot
      ;;
    shutdown)
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$STATUS_TOPIC" -m "offline" -r
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "⏻ Shutting down..."
      sudo shutdown now
      ;;
    update)
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "⬇️ Updating system..."
      sudo apt update && sudo apt upgrade -y
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "✅ Update complete."
      ;;
    ping)
      ts=\$(date '+%Y-%m-%d %H:%M:%S')
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "🏓 pong (\$ts)"
      ;;
    *)
      mosquitto_pub -h "\$MQTT_BROKER" -u "\$MQTT_USER" -P "\$MQTT_PASS" -t "\$FEEDBACK_TOPIC" -m "❓ Unknown command: \$cmd"
      ;;
  esac
done
EOF

chmod +x "$USER_HOME/.local/bin/mqtt_listener.sh"

# systemd Service
cat <<EOF > /etc/systemd/system/mqtt-listener.service
[Unit]
Description=MQTT Listener for $DEVICE_NAME
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$PI_USER
ExecStartPre=$USER_HOME/.local/bin/mqtt_register_buttons.sh
ExecStart=$USER_HOME/.local/bin/mqtt_listener.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mqtt-listener.service
systemctl start mqtt-listener.service

echo "$PI_USER ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot, /usr/bin/apt, /usr/bin/apt-get" >> /etc/sudoers

if $LANG_IS_DE; then echo "✅ Installation abgeschlossen. Gerät '$DEVICE_NAME' ist jetzt über Home Assistant steuerbar."; else echo "✅ Installation complete. Device '$DEVICE_NAME' is now controllable via Home Assistant."; fi

wget https://raw.githubusercontent.com/Q14siX/mqtt-pi-homeassistant-installer/main/mqtt_pi_uninstaller.sh && sudo chmod +x ./mqtt_pi_uninstaller.sh

sudo reboot
