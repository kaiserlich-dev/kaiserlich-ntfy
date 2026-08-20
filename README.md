# NtfyBar

macOS menu bar client for [ntfy](https://ntfy.sh). Works with ntfy.sh or any self-hosted server.

Lives in the menu bar, keeps a subscribe stream open, shows native banners, and groups the inbox by topic.

## Install

```bash
brew tap kaiserlich-dev/tap
brew install --cask ntfybar
```

If Gatekeeper blocks the ad-hoc signature:

```bash
xattr -cr /Applications/NtfyBar.app
```

From source:

```bash
bash scripts/install.sh
```

## Setup

First launch opens settings. Set:

1. Server URL (`https://ntfy.sh` or your host)
2. Topics (one per line)
3. Username/password or an access token

There is a **Kaiserlich preset** if you use `ntfy.kaiserlich.dev`.

## Build

```bash
bash scripts/build.sh
open dist/NtfyBar.app
```

Release zip:

```bash
bash scripts/package.sh
```
