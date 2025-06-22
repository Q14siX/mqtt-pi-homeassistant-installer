# DE: Automatisiertes MQTT-Installationsskript für Raspberry Pi mit Home Assistant Integration
# EN: Automated MQTT installation script for Raspberry Pi with Home Assistant integration

Ein Installationsskript für Raspberry Pi, das MQTT verwendet, um das Gerät vollständig in Home Assistant einzubinden und fernzusteuern.

An installation script for Raspberry Pi that uses MQTT to fully integrate the device into Home Assistant and enable remote control.

---

## 🛠️ Funktionen | Features

🇩🇪 **Deutsch:**

- Automatische Registrierung von MQTT-Entitäten in Home Assistant (via Discovery):
  - Statussensor („online“ / „offline“)
  - Feedback-Sensor zur Ausgabe von Rückmeldungen (Text)
  - Steuerbare Schaltflächen: `Reboot`, `Shutdown`, `Update`, `Ping`
- Automatisch generierte `DEVICE_ID` auf Basis des Gerätenamens
- Sprachunterstützung: Deutsch & Englisch
- MQTT-Statusverfolgung über `will message`
- Feedback über MQTT bei Steuerbefehlen
- Systemd-Dienst für automatischen Start bei Boot

🇬🇧 **English:**

- Automatically registers MQTT entities in Home Assistant (via Discovery):
  - Status sensor (“online” / “offline”)
  - Feedback sensor for textual responses
  - Controllable buttons: `Reboot`, `Shutdown`, `Update`, `Ping`
- Automatically generated `DEVICE_ID` based on the device name
- Language support: German & English
- MQTT status tracking via `will message`
- Feedback via MQTT for issued control commands
- Systemd service for autostart on boot

---

## ⚙️ Installation

### 🔐 Voraussetzungen | Prerequisites

- Raspberry Pi mit Raspberry Pi OS (Lite empfohlen)
- Mosquitto MQTT Broker (z. B. integriert in Home Assistant)
- Home Assistant mit aktivierter MQTT Discovery

### 📥 Ausführung | Execution

```bash
wget https://github.com/Q14siX/mqtt-pi-homeassistant-installer/mqtt_pi_installer.sh
chmod +x mqtt_pi_installer.sh
sudo ./mqtt_pi_installer.sh
```

Das Skript fragt dich nach folgenden Angaben:

- IP-Adresse deines Home Assistant
- MQTT-Benutzername & Passwort
- Gerätename (optional)
- Geräte-ID (optional, sonst automatisch generiert)

Nach der Installation startet ein systemd-Dienst automatisch und verbindet sich über MQTT.

---

## 🔄 Steuerung in Home Assistant

Sobald das Gerät eingebunden ist, kannst du in Home Assistant:

- Den Status des Geräts sehen
- Rückmeldungen über Befehle empfangen (z. B. „🔄 Rebooting...“)
- Über Schaltflächen `shutdown`, `reboot`, `update`, `ping` auslösen

---

## 🧪 Beispielhafte Topics

| Topic                         | Beschreibung / Description              |
|------------------------------|------------------------------------------|
| `DEVICE_NAME/status`         | Online-/Offline-Zustand                 |
| `DEVICE_NAME/feedback`       | Rückmeldungen nach Befehlen             |
| `DEVICE_NAME/control`        | Steuerbefehle über Buttons              |

---

## 🚨 Hinweise / Notes

- Die Buttons in Home Assistant senden einfache Payloads (`reboot`, `shutdown`, etc.).
- Der Status wird retained (`-r`) veröffentlicht, Feedback nicht.
- Die `will message` sorgt für ein automatisches „offline“ bei Verbindungsabbruch.

---

## 📄 Lizenz | License

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).

---

## 👤 Autor | Author

**Q14siX**

Ein Projekt für einfache Raspberry-Pi-Integration in Home Assistant via MQTT.  
A project for easy Raspberry Pi integration into Home Assistant via MQTT.
