#!/usr/bin/env bash
# termul - publishes SSH hosts/keys from this machine to the TerMul app via
# QR codes. Fully offline: nothing is uploaded anywhere, the QR code is the
# only channel. See agent/README.md for install + usage.
#
# Written for bash 3.2 (macOS's stock /bin/bash) - no associative arrays,
# no mapfile, no ${var,,}.

set -u

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"

if ! command -v qrencode >/dev/null 2>&1; then
  echo "termul needs 'qrencode' to draw QR codes in the terminal." >&2
  echo "Install it with: brew install qrencode  (or: apt install qrencode)" >&2
  exit 1
fi

# Expands a leading "~" and resolves bare filenames against $SSH_DIR, since
# IdentityFile entries in ssh config are commonly written either way.
resolve_path() {
  case "$1" in
    "~/"*) printf '%s' "$HOME/${1#\~/}" ;;
    /*) printf '%s' "$1" ;;
    *) printf '%s' "$SSH_DIR/$1" ;;
  esac
}

# Emits one line per Host block in ~/.ssh/config as:
#   host<TAB>hostname<TAB>user<TAB>port<TAB>identityfile
# Wildcard patterns (Host *) are skipped - they're defaults, not real hosts.
parse_ssh_config() {
  [ -f "$SSH_CONFIG" ] || return 0
  awk '
    function flush() {
      if (host != "" && host !~ /[*?]/) {
        printf "%s\t%s\t%s\t%s\t%s\n", host, hostname, user, port, identityfile
      }
      host = ""; hostname = ""; user = ""; port = "22"; identityfile = ""
    }
    BEGIN { host = ""; hostname = ""; user = ""; port = "22"; identityfile = "" }
    tolower($1) == "host" { flush(); $1 = ""; sub(/^[ \t]+/, ""); host = $0; next }
    tolower($1) == "hostname" { $1 = ""; sub(/^[ \t]+/, ""); hostname = $0; next }
    tolower($1) == "user" { $1 = ""; sub(/^[ \t]+/, ""); user = $0; next }
    tolower($1) == "port" { $1 = ""; sub(/^[ \t]+/, ""); port = $0; next }
    tolower($1) == "identityfile" { $1 = ""; sub(/^[ \t]+/, ""); identityfile = $0; next }
    END { flush() }
  ' "$SSH_CONFIG"
}

# Escapes a value for embedding as a JSON string, turning real newlines into
# the two characters \n so a multi-line private key survives as one line.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '
    { line[NR] = $0 }
    END { for (i = 1; i <= NR; i++) { printf "%s", line[i]; if (i < NR) printf "\\n" } }
  '
}

NAMES=()
ADDRS=()
PORTS=()
USERS=()
KEYFILES=()
USED_KEYS=""

is_used_key() {
  case " $USED_KEYS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS="$(printf '\t')" read -r host hostname user port identityfile; do
  [ -n "$host" ] || continue
  [ -n "$identityfile" ] || continue
  keyfile=$(resolve_path "$identityfile")
  [ -f "$keyfile" ] || continue

  NAMES+=("$host")
  ADDRS+=("${hostname:-$host}")
  PORTS+=("${port:-22}")
  USERS+=("${user:-$USER}")
  KEYFILES+=("$keyfile")
  USED_KEYS="$USED_KEYS $keyfile"
done <<EOF
$(parse_ssh_config)
EOF

if [ -d "$SSH_DIR" ]; then
  for f in "$SSH_DIR"/*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      *.pub|config|known_hosts|known_hosts.old|authorized_keys) continue ;;
    esac
    is_used_key "$f" && continue
    if head -c 200 "$f" 2>/dev/null | grep -q "PRIVATE KEY"; then
      NAMES+=("$base")
      ADDRS+=("")
      PORTS+=("22")
      USERS+=("$USER")
      KEYFILES+=("$f")
    fi
  done
fi

if [ "${#NAMES[@]}" -eq 0 ]; then
  echo "Tidak ada SSH key yang ketemu di $SSH_DIR." >&2
  exit 1
fi

echo "Host / key ditemukan:"
i=1
while [ "$i" -le "${#NAMES[@]}" ]; do
  idx=$((i - 1))
  addr="${ADDRS[$idx]:-"(alamat belum diketahui - isi manual di app)"}"
  printf "  [%d] %s  ->  %s@%s:%s\n" "$i" "${NAMES[$idx]}" "${USERS[$idx]}" "$addr" "${PORTS[$idx]}"
  i=$((i + 1))
done

printf "\nPilih nomor yang mau di-sync ke app (pisah spasi), contoh: 1 3 4\n> "
read -r SELECTION

if [ -z "$SELECTION" ]; then
  echo "Tidak ada yang dipilih, keluar."
  exit 0
fi

# Pack selected hosts into as few QR codes as possible instead of always
# one per host: a QR code holds a few KB, and an RSA key alone can be
# close to that, so hosts are greedily grouped into chunks capped at
# MAX_CHUNK_BYTES. A host whose own JSON already exceeds the cap (a big
# RSA key) still gets a chunk to itself - it just doesn't share with
# others. In the common case (a handful of hosts, ed25519/ecdsa keys),
# everything fits in one chunk, i.e. one QR for the whole batch.
MAX_CHUNK_BYTES=1800

CHUNK_JSON=""
CHUNK_COUNT=0
CHUNK_NAMES=""
QR_JSONS=()
QR_LABELS=()

flush_chunk() {
  [ "$CHUNK_COUNT" -gt 0 ] || return 0
  QR_JSONS+=("{\"termul_sync_batch\":1,\"hosts\":[$CHUNK_JSON]}")
  QR_LABELS+=("$CHUNK_NAMES")
  CHUNK_JSON=""
  CHUNK_COUNT=0
  CHUNK_NAMES=""
}

for sel in $SELECTION; do
  idx=$((sel - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#NAMES[@]}" ]; then
    echo "Lewati pilihan tidak valid: $sel" >&2
    continue
  fi

  name="${NAMES[$idx]}"
  addr="${ADDRS[$idx]}"
  port="${PORTS[$idx]}"
  user="${USERS[$idx]}"
  keyfile="${KEYFILES[$idx]}"
  key_content=$(cat "$keyfile")

  host_json="{\"name\":\"$(json_escape "$name")\",\"address\":\"$(json_escape "$addr")\",\"port\":$port,\"username\":\"$(json_escape "$user")\",\"privateKey\":\"$(json_escape "$key_content")\"}"

  if [ "$CHUNK_COUNT" -gt 0 ] && [ $((${#CHUNK_JSON} + ${#host_json} + 1)) -gt "$MAX_CHUNK_BYTES" ]; then
    flush_chunk
  fi

  if [ "$CHUNK_COUNT" -eq 0 ]; then
    CHUNK_JSON="$host_json"
    CHUNK_NAMES="$name"
  else
    CHUNK_JSON="$CHUNK_JSON,$host_json"
    CHUNK_NAMES="$CHUNK_NAMES, $name"
  fi
  CHUNK_COUNT=$((CHUNK_COUNT + 1))
done
flush_chunk

total="${#QR_JSONS[@]}"
if [ "$total" -eq 0 ]; then
  echo "Tidak ada yang dipilih, keluar."
  exit 0
fi

n=0
while [ "$n" -lt "$total" ]; do
  clear
  echo "QR $((n + 1))/$total: ${QR_LABELS[$n]}"
  echo "Scan QR ini di app TerMul (menu Import dari Mac):"
  echo
  # No -r here: qrencode reads stdin by default when given no data argument.
  # "-r -" looks like the usual stdin convention but qrencode takes it
  # literally as a file named "-" and fails with "Cannot read input file -."
  printf '%s' "${QR_JSONS[$n]}" | qrencode -t ANSIUTF8 -l L -o -
  echo

  n=$((n + 1))
  if [ "$n" -lt "$total" ]; then
    printf "Setelah ke-scan, tekan [Enter] untuk QR berikutnya... "
    read -r _
  else
    echo "Itu QR terakhir. Selesai."
  fi
done
