# NtfyBar

macOS menu bar client for [ntfy](https://ntfy.sh). Works with ntfy.sh or any self-hosted server.

Lives in the menu bar, keeps a subscribe stream open, shows native banners, and groups the inbox by topic.

## Install

```bash
brew tap kaiserlich-dev/tap
brew trust kaiserlich-dev/tap
brew install --cask ntfybar
```

Or download `NtfyBar-x.y.z.dmg` from [Releases](https://github.com/kaiserlich-dev/kaiserlich-ntfy/releases/latest). It is signed with a Developer ID and notarized, and checks for updates every 4 hours.

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

Release (signed, notarized DMG plus the Sparkle update feed):

```bash
bash scripts/release.sh 1.1.0            # build and verify only
bash scripts/release.sh 1.1.0 --publish  # also create the GitHub release
```

Needs the Developer ID certificate, the `pastefast-notarize` app password and the
Sparkle signing key (`generate_keys --account ntfy-bar`) in the login keychain.
