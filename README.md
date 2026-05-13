# Codex in a Box

A turnkey Docker setup for [OpenAI Codex CLI](https://github.com/openai/codex) — .NET 10, Node, Python, Playwright, ImageMagick, SSH, tmux, and more.

---

# Getting Started

> **Upgrading from an older version?** Your Codex auth and sessions live in a Docker named volume from the old layout — they're safe but no longer mounted, so it'll look like you've been signed out. Before running Codex for the first time on the new layout, double-click **`Migrate Old Codex Settings.lnk`** to copy them into the new `container/persistent-codex-settings/` folder. See [Upgrading from an older version](#upgrading-from-an-older-version) for full details. Skip this if you're a new user.

## 0 — Enable Virtualization (one-time)

Docker requires hardware virtualization. Most PCs have it but it's often **disabled by default** in the BIOS/UEFI. If Docker Desktop fails to start or complains about virtualization, you'll need to enable it.

**Check if it's already on:** Open Task Manager (`Ctrl+Shift+Esc`) → Performance → CPU. Look for **"Virtualization: Enabled"** in the bottom-right. If it says Enabled, skip to step 1.

**If it's disabled**, you need to enter your BIOS/UEFI settings and turn it on:

1. Open **Settings → System → Recovery → Advanced startup → Restart now**.
2. After reboot: **Troubleshoot → Advanced options → UEFI Firmware Settings → Restart**.
3. Find the virtualization setting — it goes by different names depending on your hardware:

| Manufacturer | Setting name to look for |
|-------------|--------------------------|
| Intel | `Intel Virtualization Technology (VT-x)` or `Intel VT` |
| AMD | `SVM Mode` or `AMD-V` |
| Generic | `Virtualization Technology`, `VT`, or just `Virtualization` |

It's usually under **Advanced**, **CPU Configuration**, **Security**, or **Tweaker** — varies by motherboard.

4. Set it to **Enabled**, then save and exit (usually `F10`).

> For a detailed walkthrough with screenshots, see [Microsoft's guide](https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-c5578302-6e43-4b4b-a449-8ced115f58e1) or [this step-by-step](https://pureinfotech.com/enable-virtualization-uefi-bios-windows-11/).

## 1 — Install Docker

Already have Docker Desktop? Skip ahead.

Double-click **`Install Docker.lnk`** in the project folder. It will prompt for administrator access (UAC) and then install Docker Desktop via `winget`, falling back to a direct download if `winget` isn't available.

Restart your machine after install, then launch **Docker Desktop** once so it finishes setup.

## 2 — Configure

Open **`Settings.txt`** in the project root with any text editor. Here's what each setting does:

| Variable | Default | What it controls |
|----------|---------|-----------------|
| `ENABLE_XRDP` | `false` | Build the image with the XRDP + Cinnamon desktop + Firefox browser. When `false`, the container is headless. |
| `USER_PASSWORD` | `changeme` | Password for SSH login and sudo inside the container. **Change this.** |
| `TZ` | `America/Los_Angeles` | Container timezone — affects logs, file timestamps, and cron jobs. See common values below. |
| `OPENAI_API_KEY` | *(empty)* | Your OpenAI API key. (optional) |
| `OPENAI_OAUTH_TOKEN` | *(empty)* | Alternative auth via OAuth token (from `codex login`). Optionally use either this **or** the API key. Otherwise authentication is manual. |

Host port mappings (HTTP, HTTPS, RDP, SSH) are derived automatically from your project folder name so multiple checkouts don't collide. The actual numbers in use are printed at the top of the console when the container starts.

Common timezone values for *TZ*

| Zone | Value |
|------|-------|
| US Eastern | `America/New_York` |
| US Central | `America/Chicago` |
| US Mountain | `America/Denver` |
| US Mountain (no DST) | `America/Phoenix` |
| US Pacific | `America/Los_Angeles` |
| US Alaska | `America/Anchorage` |
| US Hawaii | `Pacific/Honolulu` |
| Myanmar | `Asia/Yangon` |
| Singapore | `Asia/Singapore` |

## 3 — Run

Double-click **`Codex.lnk`** in the project folder.

> **Heads up:** The first build pulls and installs everything (.NET SDK, FFmpeg, ImageMagick, etc.). Expect it to take several minutes. Subsequent runs start in seconds.

The container is **persistent** — when you exit Codex, the container stops but is not removed. Double-clicking `Codex.lnk` again restarts the same container with all your installed packages, shell history, and login credentials intact. Across full rebuilds, the host **`files/`** and **`container/persistent-codex-settings/`** folders are preserved (they're bind-mounted into the container at `/<your project folder name>` and `/home/user/.codex`).

## 4 — First-Time Login

On first launch Codex will prompt you to authenticate:

```
? How would you like to authenticate?
  1. Sign in with ChatGPT
▸ 2. Sign in with Device Code
  3. Use an API key
```

**Choose option 2** (device code), open the link in a browser, log in to ChatGPT, and enter the code provided (you can ctrl+click the link)
Your credentials are cached in the host `container/persistent-codex-settings/` folder (mapped to `~/.codex` inside the container) — you won't be asked again.

## 5 — The `files` Folder

The `./files` directory on your machine is mapped directly into the container at `/<your project folder name>`, which is also the default working directory. For example, if this repo is checked out at `C:\stuff\codex-test-1`, the host `files/` folder appears inside the container as `/codex-test-1`. Anything you drop in there is immediately visible to Codex, and anything Codex creates lands right back on your host.

Use this as your workspace — projects, scripts, data files all go here.

## 6 — Useful Commands

| Command | What it does |
|---------|-------------|
| `/exit` | Cleanly ends the current session and stops the container. |
| `/init` | Setup codex for the current project folder |
| `/resume` | Reopens a previous session. You'll see a list of past conversations — pick one and Codex reloads the full history so you can continue right where you left off. |
| `/plan` | Begin a task with a plan |
| `/status` | Shows your current API usage and rate limits. |

That's it — you're up and running.

---

# Troubleshooting

## Upgrading from an older version

Old releases stored Codex's auth, sessions, and config inside a Docker **named volume** that lived entirely inside Docker (no presence on your host filesystem). The new layout uses a regular folder on disk — `container/persistent-codex-settings/` — bind-mounted into the container. After upgrading, the old volume is still there but it's no longer mounted, so on first launch it can look like all your sign-ins and sessions have vanished.

To recover that data, double-click **`Migrate Old Codex Settings.lnk`** in the project root.

### What the script does

1. **Verifies Docker is installed and running.** If not, it tells you what to do and exits.
2. **Finds the old volume.** Compose prefixes named volumes with the project name, so the actual volume is named `<project>_codex-home` (e.g. `codex_codex-home`). The script:
   - First looks for a volume matching this project's folder name.
   - If only one `*codex-home` volume exists on the system, uses it.
   - If multiple exist (e.g. you've had several project checkouts), shows a numbered list and lets you pick.
   - If none exist, reports **"Nothing to migrate"** and exits — safe to run on a clean install.
3. **Previews the contents** of the old volume's `.codex` subdirectory using a temporary `alpine` container so you can confirm it has what you expect (`auth.json`, `config.toml`, session logs, etc.).
4. **Asks for confirmation** before copying anything.
5. **Copies** the `.codex` contents into `container/persistent-codex-settings/` with `cp -a` (preserves permissions and timestamps). Files with the same name as something already in the destination are **overwritten**; files that exist only in the destination are left alone.
6. **Offers to delete the old volume** to reclaim disk space (typically a few hundred MB). You can decline and remove it later with `docker volume rm <name>`.

### Safe to re-run

Every step is idempotent — re-running won't make things worse. If you've already migrated and the old volume is gone, you'll just get the "Nothing to migrate" message.

### When you don't need it

- Fresh install — nothing to migrate.
- You only ever ran the new layout — nothing to migrate.
- You want to start from scratch — skip the migration; the new `container/persistent-codex-settings/` folder will be populated on first Codex login.

## Rebuilding from scratch

To pick up Dockerfile changes (new tools, updated plugins, etc.), force a clean rebuild from a PowerShell window opened in the project folder:

```
docker compose -f container/docker/docker-compose.yaml build --pull --no-cache
```

This rebuilds the image with no cache. Your `files/` and `container/persistent-codex-settings/` folders are **not** affected — only the container image is replaced. Double-click `Codex.lnk` afterwards to start fresh.

## Startup failures

If Codex fails to start, `Codex.lnk` will offer to run cleanup and retry automatically.

You can also double-click **`Docker Cleanup.lnk`** at any time — it shuts down containers and prunes unused images to free up space.

> **About the shortcut windows:** They auto-close when their script finishes successfully and stay open with an error message if something went wrong. If a window stays open after double-clicking a shortcut, read the message and press any key to dismiss it.

> **Warning:** Cleanup will stop all running Codex containers and interrupt any active sessions.

---

# Advanced (Optional)

Everything below is optional. Codex works fine without any of it.

---

## Plugins

The [Superpowers](https://github.com/obra/superpowers) plugin is installed automatically on first launch and updated via `git pull` on every subsequent start. It adds skills like brainstorming, systematic debugging, test-driven development, and code review workflows to Codex.

The multi-agent feature flag is also enabled by default (`~/.codex/config.toml`), allowing Codex to spin up multiple parallel agents that work on different parts of a task simultaneously — significantly speeding up complex, multi-step work.

No action needed — this is all handled by the entrypoint script.

---

## Web Server Access

The container's HTTP (8080) and HTTPS (4430) ports are mapped to host ports that are auto-derived from your project folder name (printed in the console when the container starts). When Codex spins up a dev server or you ask it to serve a site, bind to `0.0.0.0` inside the container and access it from your browser at `http://localhost:<HTTP port>`.

This is useful for previewing websites, testing APIs, or running any web application Codex builds for you.

---

## SSH Access

An OpenSSH server starts automatically alongside Codex. This gives you a second way into the container — useful for running commands in parallel, editing files, or attaching to a tmux session while Codex is working.

To enable it, uncomment the SSH port lines in `container/docker/docker-compose.yaml`:

```yaml
- "${SSH_PORT:-2222}:22"
- "60000-60010:60000-60010/udp"
```

Then connect (substitute the actual SSH port shown in the Codex console):

```
ssh user@localhost -p <SSH port>
```

The password is whatever you set as `USER_PASSWORD` in `Settings.txt` (default: `changeme`).

You also get [mosh](https://mosh.org/) support (UDP 60000–60010) for flaky or high-latency connections.

> **Important:** Set a strong `USER_PASSWORD` before exposing the SSH port.

---

## Using tmux Over SSH

[tmux](https://github.com/tmux/tmux) is a terminal multiplexer — it lets you run multiple shell sessions inside a single connection and keeps them alive even if you disconnect. The container comes pre-configured with mouse scrolling and 256-color support.

**Why bother?** Codex occupies your main terminal. If you need to install a package, check a log, or edit a file while Codex is thinking, tmux over SSH gives you that without interrupting it.

### Quick start

SSH in and start a new tmux session:

```
ssh user@localhost -p <SSH port>
tmux new -s work
```

You now have a persistent shell. Split it, create windows, do whatever you need — Codex keeps running undisturbed in the main container process.

### Handy tmux basics

| Keys | What it does |
|------|-------------|
| `Ctrl+b c` | Create a new window |
| `Ctrl+b n` / `Ctrl+b p` | Next / previous window |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b d` | Detach (session keeps running) |
| Mouse scroll | Scroll through output (enabled by default) |

### Reattach after disconnect

If your SSH drops or you detach, just reconnect and reattach:

```
ssh user@localhost -p <SSH port>
tmux attach -t work
```

Everything is exactly as you left it — running processes, scroll history, all of it.
