#!/usr/bin/env bash
#
# remove-waydroid.sh - Tear down the Waydroid setup used to run gCOB and
# remove everything it left behind (package, apt/dnf repo, container images,
# per-user data, Android app launchers, gCOB shortcuts, network bridge).
#
# Usage:
#   sudo ./scripts/remove-waydroid.sh            # dry run: show what would be removed
#   sudo ./scripts/remove-waydroid.sh --apply    # actually remove it
#
set -euo pipefail

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  ""|--dry-run) ;;
  -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo), it needs to touch /var/lib and /etc." >&2
  exit 1
fi

log() { printf '%s\n' "$*"; }

run() {
  if (( APPLY )); then
    log "+ $*"
    "$@" || log "  (ignored failure: $*)"
  else
    log "[dry-run] $*"
  fi
}

remove_path() {
  local p=$1
  [[ -e $p || -L $p ]] || return 0
  run rm -rf -- "$p"
}

# Home directories of real users plus root.
user_homes() {
  getent passwd | awk -F: '$3 == 0 || $3 >= 1000 { print $6 }' | sort -u |
    while read -r h; do [[ -d $h ]] && printf '%s\n' "$h"; done
}

log "== Stopping Waydroid session and container"
if command -v waydroid >/dev/null 2>&1; then
  # Sessions run per user; stop each one that is running.
  for h in $(user_homes); do
    u=$(stat -c %U "$h")
    [[ $u == root ]] && continue
    run sudo -u "$u" waydroid session stop
  done
  run waydroid container stop
fi
if systemctl list-unit-files waydroid-container.service >/dev/null 2>&1; then
  run systemctl disable --now waydroid-container.service
fi

log "== Removing the Waydroid package"
if command -v apt-get >/dev/null 2>&1 && dpkg -s waydroid >/dev/null 2>&1; then
  run apt-get purge -y waydroid
  run apt-get autoremove -y
elif command -v dnf >/dev/null 2>&1 && rpm -q waydroid >/dev/null 2>&1; then
  run dnf remove -y waydroid
elif command -v pacman >/dev/null 2>&1 && pacman -Qi waydroid >/dev/null 2>&1; then
  run pacman -Rns --noconfirm waydroid
elif command -v waydroid >/dev/null 2>&1; then
  log "waydroid is installed but not through apt/dnf/pacman; remove it manually: $(command -v waydroid)"
fi

log "== Removing Waydroid package repositories"
for f in /etc/apt/sources.list.d/waydroid*.list /etc/apt/sources.list.d/waydroid*.sources \
         /usr/share/keyrings/waydroid*.gpg /etc/apt/trusted.gpg.d/waydroid*.gpg \
         /etc/yum.repos.d/*waydroid*.repo; do
  remove_path "$f"
done

log "== Removing system-wide Waydroid data and images"
for p in /var/lib/waydroid /home/.waydroid /usr/share/waydroid-extra /etc/waydroid-extra \
         /etc/systemd/system/waydroid-container.service \
         /etc/systemd/system/multi-user.target.wants/waydroid-container.service; do
  remove_path "$p"
done

log "== Removing per-user Waydroid data, app launchers and gCOB shortcuts"
for h in $(user_homes); do
  for p in "$h/waydroid" "$h/.waydroid" "$h/.share/waydroid" "$h/.local/share/waydroid" \
           "$h/.cache/waydroid"; do
    remove_path "$p"
  done
  # Waydroid writes one .desktop file per Android app (waydroid.<package>.desktop)
  # plus its own launcher entries.
  shopt -s nullglob nocaseglob
  for f in "$h"/.local/share/applications/*waydroid*; do
    remove_path "$f"
  done
  shopt -u nocaseglob
  # gCOB shortcuts/launchers are removed only if they go through Waydroid,
  # so anything unrelated that happens to be named gcob is left alone.
  for dir in "$h/.local/share/applications" "$h/Desktop" "$h/.config/autostart" \
             "$h/.local/bin" "$h/bin"; do
    [[ -d $dir ]] || continue
    while IFS= read -r -d '' f; do
      b=${f##*/}; [[ ${b,,} == *waydroid* ]] && continue  # already handled above
      if grep -qi waydroid -- "$f" 2>/dev/null; then
        remove_path "$f"
      else
        log "kept (does not reference waydroid): $f"
      fi
    done < <(find "$dir" -maxdepth 1 -iname '*gcob*' \( -type f -o -type l \) -print0)
  done
  shopt -u nullglob
done

log "== Removing the waydroid0 network bridge"
if command -v ip >/dev/null 2>&1 && ip link show waydroid0 >/dev/null 2>&1; then
  run ip link delete waydroid0
fi

if (( APPLY )); then
  command -v systemctl >/dev/null 2>&1 && run systemctl daemon-reload
  for h in $(user_homes); do
    [[ -d $h/.local/share/applications ]] && command -v update-desktop-database >/dev/null 2>&1 &&
      run update-desktop-database "$h/.local/share/applications"
  done
fi

log "== Left in place (review manually if you no longer need them)"
# binder/ashmem kernel modules may be used by other Android tooling, so only report them.
for f in /etc/modules-load.d/* /etc/modprobe.d/*; do
  [[ -f $f ]] && grep -qiE 'binder|ashmem' "$f" && log "binder/ashmem module config: $f"
done
{ lsmod 2>/dev/null || true; } | awk '$1 ~ /^(binder_linux|ashmem_linux)$/ { print "loaded kernel module: " $1 }'

if (( APPLY )); then
  log "Done. Waydroid and its gCOB setup have been removed."
else
  log "Dry run only. Re-run with --apply to remove the items above."
fi
