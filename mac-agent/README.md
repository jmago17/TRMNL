# TRMNL Mac Agent

Small macOS command line agent for sending local iCloud Calendar and Photos data to TRMNL without an Apple Developer Program subscription.

The agent uses local macOS frameworks:

- `EventKit` for calendars synced into the Calendar app.
- `PhotoKit` for the Photos library synced into Photos.
- `URLSession` for Cloudflare Worker uploads and TRMNL custom plugin webhooks.

## Build

```sh
cd mac-agent
swift build -c release
```

The binary will be available at:

```sh
.build/release/trmnl-mac-agent
```

## Configure

Create the config folder:

```sh
mkdir -p ~/.config/trmnl-mac-agent
```

Generate a starter config:

```sh
.build/release/trmnl-mac-agent example-config > ~/.config/trmnl-mac-agent/config.json
```

Edit `~/.config/trmnl-mac-agent/config.json` and set:

- `workerURL`: your Cloudflare Worker base URL.
- `authSecret`: the bearer secret expected by the worker.
- `photoPluginUUID`: TRMNL custom plugin UUID for photos.
- `dayAgendaPluginUUID`: TRMNL custom plugin UUID for day agenda.
- `weekOverviewPluginUUID`: TRMNL custom plugin UUID for week overview.
- `monthOverviewPluginUUID`: TRMNL custom plugin UUID for month overview.
- `selectedCalendarIdentifiers`: optional list from `list-calendars`.
- `selectedCalendarTitles`: optional list of calendar names. Useful if identifiers change.

Secrets can also be overridden with environment variables:

- `TRMNL_WORKER_URL`
- `TRMNL_AUTH_SECRET`
- `TRMNL_PHOTO_PLUGIN_UUID`
- `TRMNL_DAY_AGENDA_PLUGIN_UUID`
- `TRMNL_WEEK_OVERVIEW_PLUGIN_UUID`
- `TRMNL_MONTH_OVERVIEW_PLUGIN_UUID`

## Commands

```sh
trmnl-mac-agent list-calendars
trmnl-mac-agent day-agenda
trmnl-mac-agent week-overview
trmnl-mac-agent month-overview
trmnl-mac-agent photo-file /path/to/image.jpg
trmnl-mac-agent photo-library --album "Favorites" --mode latest
trmnl-mac-agent photo-library --mode random
trmnl-mac-agent slideshow-library --type portrait --album "TRMNL" --limit 5
trmnl-mac-agent slideshow-library --type landscape --album "TRMNL" --limit 5
trmnl-mac-agent slideshow-both --album "TRMNL" --limit 5
```

Photo commands default to `--delivery polling`. This uploads `photo.jpg` to Cloudflare and prints the polling URL for the TRMNL private plugin:

```sh
https://your-worker.example.workers.dev/photo
```

Use `--delivery webhook` only with a TRMNL private plugin whose Strategy is set to Webhook.

`slideshow-both` replicates the shortcut flow for slideshows: it scans the selected Photos album or full library, excludes screenshots, picks up to 5 random landscape photos and up to 5 random portrait photos, then uploads them as:

```text
landscape-1.jpg ... landscape-5.jpg
portrait-1.jpg ... portrait-5.jpg
```

Use these polling URLs in TRMNL slideshow plugins:

```text
https://your-worker.example.workers.dev/slideshow?type=landscape&count=5
https://your-worker.example.workers.dev/slideshow?type=portrait&count=5
```

Use `--mode latest` if you want the newest matching photos instead of random selection.

Date-based calendar commands accept:

```sh
--date yyyy-mm-dd
```

## macOS permissions

On first use, macOS may ask for Calendar and Photos permission. If a prompt does not appear or access is denied, open:

```text
System Settings > Privacy & Security
```

Then allow the built binary or Terminal for Calendars and Photos.

For Photos with iCloud optimized storage, the agent allows network access so macOS can download the selected original if needed.

## launchd

Copy and edit one of the plist examples from `Examples/`, replacing the binary path with the absolute path to your release binary.

Install it with:

```sh
cp Examples/com.jmago17.trmnl.day-agenda.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.jmago17.trmnl.day-agenda.plist
```

Unload it with:

```sh
launchctl unload ~/Library/LaunchAgents/com.jmago17.trmnl.day-agenda.plist
```
