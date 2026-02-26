FROM ghcr.io/openai/codex-universal:latest

ENV DEBIAN_FRONTEND=noninteractive

# ---------- Additional packages ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
        imagemagick \
        ffmpeg \
        openssh-server \
        tmux \
        nano \
        mosh \
        locales \
    && rm -rf /var/lib/apt/lists/*

# ---------- .NET SDK 10 ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
    && curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends dotnet-sdk-10.0 \
    && rm -rf /var/lib/apt/lists/*

# ---------- Codex CLI ----------
RUN . "$NVM_DIR/nvm.sh" && npm install -g @openai/codex

# ---------- Sudo for all users ----------
RUN echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd \
    && chmod 0440 /etc/sudoers.d/nopasswd

# ---------- SSH ----------
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ---------- Locale ----------
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen

# ---------- Ports ----------
EXPOSE 22 80 443 60000-61000/udp

# ---------- Inline entrypoint ----------
RUN cat <<'ENTRY' > /opt/codex-entrypoint.sh
#!/usr/bin/env bash
set -e

# --- Password ---
echo "root:${USER_PASSWORD:-codex}" | chpasswd

# --- Timezone ---
TZ="${TZ:-America/Los_Angeles}"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone

# --- Locale ---
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- Tmux config (only write if not already customised) ---
if [ ! -f "$HOME/.tmux.conf" ]; then
  cat > "$HOME/.tmux.conf" <<'TMUX'
set -g mouse on
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
TMUX
fi

# --- Source node/nvm so `codex` is on PATH ---
export NVM_DIR="${NVM_DIR:-/root/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# --- Start SSH daemon ---
/usr/sbin/sshd

# --- Launch Codex ---
exec codex --dangerously-bypass-approvals-and-sandbox "$@"
ENTRY
chmod +x /opt/codex-entrypoint.sh

ENTRYPOINT ["/opt/codex-entrypoint.sh"]
