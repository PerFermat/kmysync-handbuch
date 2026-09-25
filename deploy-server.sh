#!/usr/bin/env bash
#
# Laedt das KMySync-Handbuch per scp/SSH nach kmysync.michaelspahr.de hoch.
# Vorbild: deploy-server.sh der Homepage (gleiches Verfahren: Paket, Backup, Austausch).
#
# 1) Konfiguration anlegen:   cp deploy.env.example deploy.env  (dann ausfuellen)
# 2) Deployen:                bash deploy-server.sh
#    Vorher neu erzeugen:     bash deploy-server.sh --neu
#
# Alle Werte lassen sich auch als Environment-Variablen uebergeben, z. B.:
#   DEPLOY_HOST=example.com DEPLOY_USER=user DEPLOY_PATH=/var/www/kmysync bash deploy-server.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR"
GENERATOR="${GENERATOR:-$HOME/git/Ausgaben/docs/build_manual_web.py}"

# ---- Konfiguration laden -----------------------------------------------------
[ -f "$SCRIPT_DIR/deploy.env" ] && source "$SCRIPT_DIR/deploy.env"

: "${DEPLOY_HOST:?DEPLOY_HOST fehlt -- in deploy.env setzen (Server-Hostname oder IP)}"
: "${DEPLOY_USER:?DEPLOY_USER fehlt -- in deploy.env setzen (SSH-Benutzer)}"
: "${DEPLOY_PATH:?DEPLOY_PATH fehlt -- in deploy.env setzen (Web-Root auf dem Server)}"

# Der Web-Root wird vor dem Auspacken geleert -- nur einen echten Unterordner von /var/www zulassen.
case "$DEPLOY_PATH" in
  /var/www/?*) ;;
  *) echo "DEPLOY_PATH muss unter /var/www/ liegen (ist: '$DEPLOY_PATH')" >&2; exit 1 ;;
esac

DEPLOY_PORT="${DEPLOY_PORT:-22}"
SSH_KEY="${SSH_KEY:-}"                                # optionaler Pfad zum Private Key
REMOTE_SUDO="${REMOTE_SUDO-sudo}"                    # "" wenn kein sudo noetig ist (leer bleibt leer)
REMOTE_OWNER="${REMOTE_OWNER-www-data:www-data}"     # "" um chown zu ueberspringen
DO_RELOAD="${DO_RELOAD:-0}"                           # statische Dateien brauchen keinen nginx-Reload
RELOAD_CMD="${RELOAD_CMD:-systemctl reload nginx}"
SITE_URL="${SITE_URL:-https://kmysync.michaelspahr.de/}"

STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="$DEPLOY_USER@$DEPLOY_HOST"
SSH_OPTS=(-p "$DEPLOY_PORT"); SCP_OPTS=(-P "$DEPLOY_PORT")
if [ -n "$SSH_KEY" ]; then SSH_OPTS+=(-i "$SSH_KEY"); SCP_OPTS+=(-i "$SSH_KEY"); fi

# ---- 0/4  Optional neu erzeugen ---------------------------------------------
if [ "${1:-}" = "--neu" ]; then
  echo "==> 0/4  Handbuch neu erzeugen"
  python3 "$GENERATOR" --ziel "$SRC"
fi
[ -f "$SRC/index.html" ] && [ -f "$SRC/en/index.html" ] || {
  echo "index.html fehlt -- zuerst erzeugen: bash deploy-server.sh --neu" >&2; exit 1; }

# ---- 1/4  Paket schnueren ----------------------------------------------------
echo "==> 1/4  Paket schnueren"
TARBALL="$(mktemp -t kmysync-XXXXXX).tgz"
trap 'rm -f "$TARBALL" "${APPLY:-}"' EXIT
tar czf "$TARBALL" -C "$SRC" \
  --exclude='deploy-server.sh' --exclude='deploy.env' --exclude='deploy.env.example' \
  --exclude='nginx' --exclude='README.md' \
  --exclude='.git' --exclude='.gitignore' \
  .
echo "    Groesse: $(du -h "$TARBALL" | cut -f1)"

# ---- 2/4  Remote-Apply-Skript erzeugen --------------------------------------
echo "==> 2/4  Remote-Apply-Skript erzeugen"
APPLY="$(mktemp -t apply-XXXXXX).sh"
cat > "$APPLY" <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail
DEST="$1"; STAMP="$2"; SUDO="$3"; OWNER="$4"; TARBALL="$5"; DO_RELOAD="$6"; RELOAD_CMD="$7"

case "$DEST" in /var/www/?*) ;; *) echo "Unerwarteter Zielpfad: $DEST" >&2; exit 1 ;; esac
if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  echo "    Backup -> ${DEST}.bak-${STAMP}"
  $SUDO cp -a "$DEST" "${DEST}.bak-${STAMP}"
  # Nur die 2 neuesten Backups behalten, aeltere loeschen (Speicher sparen)
  ls -dt "${DEST}".bak-* 2>/dev/null | tail -n +3 | while IFS= read -r old; do
    $SUDO rm -rf "$old" && echo "    altes Backup entfernt: $old"
  done
fi
$SUDO mkdir -p "$DEST"
$SUDO find "$DEST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
$SUDO tar xzf "$TARBALL" -C "$DEST"
[ -n "$OWNER" ] && $SUDO chown -R "$OWNER" "$DEST"
$SUDO find "$DEST" -type d -exec chmod 755 {} +
$SUDO find "$DEST" -type f -exec chmod 644 {} +
if [ "$DO_RELOAD" = "1" ]; then
  echo "    Reload: ${SUDO:+$SUDO }$RELOAD_CMD"
  $SUDO $RELOAD_CMD
fi
$SUDO rm -f "$TARBALL"
echo "    Remote fertig."
REMOTE

# ---- 3/4  Uebertragen (scp) --------------------------------------------------
echo "==> 3/4  Uebertragen nach $TARGET:$DEPLOY_PATH"
REMOTE_TGZ="/tmp/kmysync-${STAMP}.tgz"
REMOTE_APPLY="/tmp/kmysync-apply-${STAMP}.sh"
scp "${SCP_OPTS[@]}" "$TARBALL" "$TARGET:$REMOTE_TGZ"
scp "${SCP_OPTS[@]}" "$APPLY"   "$TARGET:$REMOTE_APPLY"

# ---- 4/4  Auf dem Server anwenden -------------------------------------------
echo "==> 4/4  Auf dem Server anwenden"
ssh "${SSH_OPTS[@]}" "$TARGET" \
  "bash '$REMOTE_APPLY' '$DEPLOY_PATH' '$STAMP' '$REMOTE_SUDO' '$REMOTE_OWNER' '$REMOTE_TGZ' '$DO_RELOAD' '$RELOAD_CMD'; rm -f '$REMOTE_APPLY'"

echo
echo "Fertig. Aufrufbar unter: $SITE_URL"
