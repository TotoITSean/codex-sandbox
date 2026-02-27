# Codex in a Box

A turnkey Docker setup for [OpenAI Codex CLI](https://github.com/openai/codex) — .NET 10, Node, Python, Playwright, ImageMagick, SSH, tmux, and more.

---

# Getting Started

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

```
install-docker.bat        # right-click → Run as administrator
```

Restart your machine after install, then launch **Docker Desktop** once so it finishes setup.

## 2 — Configure

Copy the sample environment file to create your own:

```
copy .env.sample .env
```

Open `.env` in any text editor. Here's what each setting does:

| Variable | Default | What it controls |
|----------|---------|-----------------|
| `USER_PASSWORD` | `changeme` | Password for SSH login and sudo inside the container. **Change this.** |
| `TZ` | `America/Los_Angeles` | Container timezone — affects logs, file timestamps, and cron jobs. See common values below. |
| `OPENAI_API_KEY` | *(empty)* | Your OpenAI API key. (optional) |
| `OPENAI_OAUTH_TOKEN` | *(empty)* | Alternative auth via OAuth token (from `codex login`). Optionally use either this **or** the API key. Otherwise authentication is manual |
| `HTTP_PORT` | `8080` | Host port mapped to the container's port 8080. |
| `HTTPS_PORT` | `4430` | Host port mapped to the container's port 4430. |
| `SSH_PORT` | `2222` | Host port for SSH access (mapped to container port 22). |

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

```
start.bat
```

> **Heads up:** The first build pulls and installs everything (.NET SDK, FFmpeg, ImageMagick, etc.). Expect it to take several minutes. Subsequent runs start in seconds.

## 4 — First-Time Login

On first launch Codex will prompt you to authenticate:

```
? How would you like to authenticate?
  1. Sign in with ChatGPT
▸ 2. 
  3. Use an API key
```

**Choose option 2** and paste your OpenAI API key.
Your credentials are cached inside the persistent home volume — you won't be asked again.

## 5 — The `files` Folder

The `./files` directory on your machine is mapped directly into the container at `/files` (the default working directory). Anything you drop in there is immediately visible to Codex, and anything Codex creates lands right back on your host.

Use this as your workspace — projects, scripts, data files all go here.

## 6 — Useful Commands

| Command | What it does |
|---------|-------------|
| `/exit` | Cleanly ends the current session and stops the container. |
| `/init` | Setup codex for the project in /files |
| `/resume` | Reopens a previous session. You'll see a list of past conversations — pick one and Codex reloads the full history so you can continue right where you left off. |
| `/plan` | Begin a task with a plan |

That's it — you're up and running.

---

# Troubleshooting

## Startup Failures

If Codex fails to start, `start.bat` will offer to run `docker-cleanup.bat` and retry automatically.

You can also run `docker-cleanup.bat` directly at any time — it shuts down containers and prunes unused images to free up space.

> **Warning:** Cleanup will stop all running Codex containers and interrupt any active sessions.

---

# Advanced (Optional)

Everything below is optional. Codex works fine without any of it.

---

## SSH Access

An OpenSSH server starts automatically alongside Codex. This gives you a second way into the container — useful for running commands in parallel, editing files, or attaching to a tmux session while Codex is working.

To enable it, uncomment the SSH port lines in `docker-compose.yaml`:

```yaml
- "${SSH_PORT:-2222}:22"
- "60000-60010:60000-60010/udp"
```

Then connect:

```
ssh root@localhost -p 2222
```

The password is whatever you set as `USER_PASSWORD` in `.env` (default: `changeme`). The port is controlled by `SSH_PORT`.

You also get [mosh](https://mosh.org/) support (UDP 60000–60010) for flaky or high-latency connections.

> **Important:** Set a strong `USER_PASSWORD` before exposing the SSH port.

---

## Using tmux Over SSH

[tmux](https://github.com/tmux/tmux) is a terminal multiplexer — it lets you run multiple shell sessions inside a single connection and keeps them alive even if you disconnect. The container comes pre-configured with mouse scrolling and 256-color support.

**Why bother?** Codex occupies your main terminal. If you need to install a package, check a log, or edit a file while Codex is thinking, tmux over SSH gives you that without interrupting it.

### Quick start

SSH in and start a new tmux session:

```
ssh root@localhost -p 2222
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
ssh root@localhost -p 2222
tmux attach -t work
```

Everything is exactly as you left it — running processes, scroll history, all of it.
