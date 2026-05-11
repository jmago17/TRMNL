# Migración a otro Mac

Pasos para reproducir el agente TRMNL en una máquina nueva. Asume que ya pasaste por el checklist general (Tailscale, gh, SSH, etc.).

## Lo que está en este repo (reproducible)

- Código Swift del agente y worker.
- `Scripts/run-trmnl-command.sh` — wrapper que envuelve cada invocación.
- `Examples/com.jmago17.trmnl.*.plist` — los 4 LaunchAgents reales, con paths absolutos a `/Users/josu/...`. Cámbialos si el `$HOME` del Mac nuevo no es `/Users/josu`.

## Lo que NO está en git (transporte manual)

| Pieza | Dónde está hoy | Cómo recuperarla |
| --- | --- | --- |
| `~/.config/trmnl-mac-agent/config.json` | `authSecret` + 4 plugin UUIDs + lista de calendarios + locale | Copiar el archivo (vía AirDrop / 1Password / pendrive). No subir a git. |
| Keychain `trmnl-brrr-webhook-secret` | login.keychain del Mac viejo | Re-añadir con `security add-generic-password -a "$USER" -s trmnl-brrr-webhook-secret -w <token>`. Opcional: si falta, las notificaciones de error se saltan. |
| TCC: Calendar / Reminders / Photos | System Settings → Privacy & Security | Se conceden la primera vez que cada comando se ejecuta a mano. No se transfieren. |
| Swift toolchain | Xcode + command line tools | `xcode-select --install` y/o Xcode desde App Store. |

## Pasos en el Mac nuevo

```sh
# 1. Clonar
git clone https://github.com/jmago17/TRMNL.git ~/Documents/Developer/trmnl
cd ~/Documents/Developer/trmnl/mac-agent

# 2. Build (genera .build/release/trmnl-mac-agent)
swift build -c release

# 3. Config (copiar del Mac viejo o reconstruir)
mkdir -p ~/.config/trmnl-mac-agent
cp /ruta/al/config.json ~/.config/trmnl-mac-agent/
# o bien:
.build/release/trmnl-mac-agent example-config > ~/.config/trmnl-mac-agent/config.json
# y editar workerURL, authSecret, los 4 *PluginUUID, calendarios, locale

# 4. Wrapper
mkdir -p ~/Library/Application\ Support/trmnl
cp Scripts/run-trmnl-command.sh ~/Library/Application\ Support/trmnl/
chmod +x ~/Library/Application\ Support/trmnl/run-trmnl-command.sh

# 5. Conceder permisos (dispara los diálogos TCC)
.build/release/trmnl-mac-agent list-calendars
.build/release/trmnl-mac-agent day-agenda
.build/release/trmnl-mac-agent slideshow-both --limit 1 --mode best

# 6. Brrr secret (opcional)
security add-generic-password -a "$USER" -s "trmnl-brrr-webhook-secret" -w "<token>"

# 7. LaunchAgents
cp Examples/com.jmago17.trmnl.*.plist ~/Library/LaunchAgents/
for label in com.jmago17.trmnl.day-agenda \
             com.jmago17.trmnl.week-overview \
             com.jmago17.trmnl.month-overview \
             com.jmago17.trmnl.slideshow-both; do
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$label.plist
done

# 8. Validar
for label in com.jmago17.trmnl.day-agenda \
             com.jmago17.trmnl.week-overview \
             com.jmago17.trmnl.month-overview \
             com.jmago17.trmnl.slideshow-both; do
  launchctl print gui/$(id -u)/$label | grep -E "state|next start"
done
```

## Verificación

A las 02:00 del día siguiente, comprobar:

```sh
ls -la /tmp/trmnl-*.log /tmp/trmnl-*.err
```

Y mirar TRMNL: las 3 vistas de agenda y el slideshow deben aparecer actualizadas.

## Notas

- Los `selectedCalendarIdentifiers` de `config.json` son opacos pero estables entre Macs si la cuenta iCloud es la misma. Si no resuelven, el agente cae a los `selectedCalendarTitles`.
- Los UUIDs de plugin son de TRMNL (no de Apple) — se mantienen iguales para el mismo dispositivo TRMNL.
- Si el binario cambia de path (otra `$HOME`), edita los plists antes de hacer `bootstrap`.
- Locale `eu_ES` (euskera): se queda igual en otro Mac, no depende de System Settings.
