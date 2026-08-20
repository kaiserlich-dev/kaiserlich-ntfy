# kaiserlich-ntfy

macOS menu bar client for the self-hosted ntfy at `https://ntfy.kaiserlich.dev`.

Lives in the menu bar, keeps an HTTP subscribe stream open, shows native banners, and groups the inbox by topic.

## Install

```bash
bash scripts/install.sh
```

Puts `NtfyBar.app` in `~/Applications` and launches it.

First run: enter the ntfy username and password (Keychain), allow notifications, Save & reconnect.

## Build only

```bash
bash scripts/build.sh
open dist/NtfyBar.app
```
