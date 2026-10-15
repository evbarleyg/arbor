#!/bin/bash
# A probe, not to be merged: how does a script give codesign the use of a key it has just imported, without a dialog, on this macOS?
#
#   scripts/mac-shell/run.sh --bare scripts/mac-shell/probe-signing.sh
#
# scripts/make-signing-identity.sh, given the right password, says it is wrong: the key it imports is labelled "Imported Private Key", so
# `set-key-partition-list -l "Arbor Local Signing"` matches none, and the script takes every failure for a wrong password. And with every key let
# at, codesign still did not sign within twenty seconds. So: a dozen trials, each in a keychain of its own with a known password, signing a copy of
# /usr/bin/true under a time limit. When codesign hangs: who has come on screen, and what the dialog says.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-520}
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "make keychains, put them on the account's search list and take them off again, and dismiss macOS's dialogs"
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "a rehearsal has no keychains and no codesign"; exit 77; }

AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
scratch_dir signing work real
name="Arbor Local Signing"
pw="probe$RANDOM"
listed_before=$(security list-keychains -d user | sed 's/^ *"//; s/"$//')
restore_list() {
  # shellcheck disable=SC2086
  echo "$listed_before" | tr '\n' '\0' | xargs -0 security list-keychains -d user -s
}
at_exit restore_list

on_screen() { "$ARBOR_POINTER" windows --on-screen | awk '{ $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); print }' | sort -u; }
pid_named() {
  "$ARBOR_POINTER" windows --on-screen | awk -v name="$1" '{ pid = $2; $1 = $2 = $3 = $4 = $5 = $6 = $7 = $8 = ""; sub(/^ +/, ""); if ($0 == name) { print pid; exit } }'
}
told() {
  local pid; pid=$(pid_named "$1"); [ -n "$pid" ] || return 0
  limit 5 "$AXFIND" "$pid" tree 2>/dev/null | grep -E "AXStaticText|AXButton|AXTextField|AXCheckBox" | grep -vE '"" "" ' | sed -E 's/^ +//; s/ -?[0-9]+ -?[0-9]+ [0-9]+ [0-9]+$//' \
    | cut -c 1-220 | head -n 12 | sed 's/^/        /'
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m); /usr/bin/openssl: $(/usr/bin/openssl version)"
other=$(ls -d /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl 2>/dev/null | head -n 1)
echo "another openssl: ${other:-none} $([ -n "$other" ] && "$other" version)"
echo "the search list: $(echo "$listed_before" | tr '\n' ' ')"
echo "the default keychain: $(security default-keychain -d user 2>&1)"
newest=$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -viE 'beta|_rc' | sort -V | tail -n 1)
[ -n "$newest" ] && export DEVELOPER_DIR="$newest/Contents/Developer"
mkdir -p "$(dirname "$ARBOR_POINTER")"
limit 120 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/pointer.swift" -o "$ARBOR_POINTER" > "$ARBOR_OUT/build-pointer.log" 2>&1 &
started $!; first=$!
limit 120 swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1
ended "$first" 1300
[ -x "$ARBOR_POINTER" ] && [ -x "$AXFIND" ] || { cat "$ARBOR_OUT"/build-*.log; die "the tools did not compile"; }

cat > "$work/openssl.cnf" <<CONFIG
[ req ]
prompt = no
distinguished_name = subject
x509_extensions = extensions
[ subject ]
CN = $name
[ extensions ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG

# pack <openssl> <stem>: a new key and certificate, as make-signing-identity.sh makes them
pack() {
  local openssl=$1 stem=$2 legacy=""
  "$openssl" req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 -config "$work/openssl.cnf" -keyout "$stem.key.pem" -out "$stem.cert.pem" 2> /dev/null
  case "$("$openssl" version)" in LibreSSL* | "OpenSSL 0."* | "OpenSSL 1."*) ;; *) legacy=-legacy ;; esac
  # shellcheck disable=SC2086
  "$openssl" pkcs12 -export $legacy -inkey "$stem.key.pem" -in "$stem.cert.pem" -name "$name" -out "$stem.p12" -passout pass:transport 2> /dev/null
}
label_of() { security dump-keychain "$1" 2> /dev/null | awk '/class: 0x00000010/ { key = 1 } key && /0x00000001 <blob>=/ { sub(/.*<blob>=/, ""); print; exit }'; }
hash_of() { security find-identity -p codesigning "$1" 2> /dev/null | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) .*/\1/p' | head -n 1; }

count=0
# trial "<what>" <openssl> "<import flags>" "<partition ids, or none>" "<label: name, none, or the key's own>" <on the list: yes|no>
trial() {
  local what=$1 openssl=$2 flags=$3 partitions=$4 label=$5 listed=$6 kc stem hash code before said asker tries
  count=$((count + 1))
  stem="$work/t$count"
  kc="$stem.keychain-db"
  echo
  echo "-- $count  $what"
  security create-keychain -p "$pw" "$kc" && security set-keychain-settings "$kc" && security unlock-keychain -p "$pw" "$kc"
  if [ "$listed" = yes ]; then
    { echo "$listed_before"; echo "$kc"; } | tr '\n' '\0' | xargs -0 security list-keychains -d user -s
  fi
  pack "$openssl" "$stem"
  # shellcheck disable=SC2086
  security import "$stem.p12" -k "$kc" -f pkcs12 -P transport $flags > /dev/null 2> "$stem.import.txt" || echo "     import failed: $(head -n 2 "$stem.import.txt" | tr '\n' ' ')"
  hash=$(hash_of "$kc")
  echo "     the key's label: $(label_of "$kc"); the identity: ${hash:-NONE}"
  if [ "$partitions" != none ]; then
    case "$label" in
      none) security set-key-partition-list -S "$partitions" -s -k "$pw" "$kc" > /dev/null 2> "$stem.partition.txt" ;;
      own) security set-key-partition-list -S "$partitions" -s -l "$(label_of "$kc" | tr -d '"')" -k "$pw" "$kc" > /dev/null 2> "$stem.partition.txt" ;;
      *) security set-key-partition-list -S "$partitions" -s -l "$label" -k "$pw" "$kc" > /dev/null 2> "$stem.partition.txt" ;;
    esac
    echo "     set-key-partition-list -S $partitions, label $label: exit code $?; it says: $(head -n 2 "$stem.partition.txt" | tr '\n' ' ' | cut -c 1-160)"
  fi
  cp /usr/bin/true "$stem.probe"
  before=$(on_screen)
  limit 12 codesign --force --sign "$hash" --keychain "$kc" --timestamp=none --identifier com.evbarleyg.arbor.probe "$stem.probe" > "$stem.codesign.txt" 2>&1 &
  started $!; said=$!
  tries=0
  while [ "$tries" -lt 40 ] && kill -0 "$said" 2> /dev/null; do
    asker=$(on_screen | grep -vxF -e "$before" | head -n 1)
    [ -n "$asker" ] && break
    sleep 0.25
    tries=$((tries + 1))
  done
  if [ -n "${asker:-}" ]; then
    echo "     ASKED by $asker:"
    told "$asker"
    shot "trial-$count"
    key escape > /dev/null
    sleep 1
  fi
  ended "$said" 140
  if codesign --verify "$stem.probe" 2> /dev/null && codesign --display --verbose=2 "$stem.probe" 2>&1 | grep -q "Authority=$name"; then
    echo "     SIGNED${asker:+ (after a dialog?)}: $(codesign --display --requirements - "$stem.probe" 2> /dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | cut -c 1-110)"
  else
    echo "     NOT SIGNED: $(head -n 2 "$stem.codesign.txt" | tr '\n' ' ' | cut -c 1-170)"
  fi
  asker=""
  [ "$listed" = yes ] && restore_list
  LAST_KC=$kc LAST_HASH=$hash LAST_STEM=$stem
}

ssl=/usr/bin/openssl
step "as the script does it, and one thing changed at a time"
trial "as make-signing-identity.sh does it"                      $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:"           "$name" no
trial "no partition list at all: what does macOS ask?"           $ssl "-x -T /usr/bin/codesign" none                           none    no
trial "every signing key of the keychain, no label"              $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:"           none    no
trial "by the label the key really has"                          $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:"           own     no
trial "no label, and codesign: among the partitions"             $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:,codesign:" none    no
trial "no label, the keychain on the search list"                $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:"           none    yes
trial "no label, codesign:, on the search list"                  $ssl "-x -T /usr/bin/codesign" "apple-tool:,apple:,codesign:" none    yes
trial "the same, the key exportable (no -x)"                     $ssl "-T /usr/bin/codesign"    "apple-tool:,apple:,codesign:" none    yes
trial "the same, any application (-A)"                           $ssl "-x -A"                   "apple-tool:,apple:,codesign:" none    yes
if [ -n "$other" ]; then
  trial "OpenSSL 3: which label? as the script does it"          "$other" "-x -T /usr/bin/codesign" "apple-tool:,apple:"       "$name" no
  trial "OpenSSL 3, no label, on the search list"                "$other" "-x -T /usr/bin/codesign" "apple-tool:,apple:"       none    yes
fi

step "what security says to a wrong password, to no matching key, and to a locked keychain"
kc=$LAST_KC
security set-key-partition-list -S apple-tool:,apple: -s -k "not-the-password" "$kc" > /dev/null 2> "$work/wrong.txt"; echo "a wrong password: exit code $?: $(head -n 2 "$work/wrong.txt" | tr '\n' ' ')"
security set-key-partition-list -S apple-tool:,apple: -s -l "No Such Label" -k "$pw" "$kc" > /dev/null 2> "$work/nokey.txt"; echo "no key of that label: exit code $?: $(head -n 2 "$work/nokey.txt" | tr '\n' ' ')"
security unlock-keychain -p "not-the-password" "$kc" 2> "$work/unlock.txt"; echo "unlock-keychain, a wrong password: exit code $?: $(head -n 1 "$work/unlock.txt")"
security unlock-keychain -p "$pw" "$kc" 2> "$work/unlock2.txt"; echo "unlock-keychain, the right one: exit code $?: $(head -n 1 "$work/unlock2.txt")"

step "locked, unlocked again, off the search list: does the leave last?"
security lock-keychain "$kc"
cp /usr/bin/true "$work/locked.probe"
before=$(on_screen)
limit 8 codesign --force --sign "$LAST_HASH" --keychain "$kc" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/locked.probe" > "$work/locked.txt" 2>&1 &
started $!; said=$!
sleep 4
asker=$(on_screen | grep -vxF -e "$before" | head -n 1)
[ -n "$asker" ] && { echo "locked: ASKED by $asker:"; told "$asker"; shot locked; key escape > /dev/null; sleep 1; }
ended "$said" 100
echo "locked: $(head -n 2 "$work/locked.txt" | tr '\n' ' ' | cut -c 1-170)"
security unlock-keychain -p "$pw" "$kc"
cp /usr/bin/true "$work/unlocked.probe"
limit 12 codesign --force --sign "$LAST_HASH" --keychain "$kc" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/unlocked.probe" > "$work/unlocked.txt" 2>&1
echo "unlocked again: exit code $?: $(head -n 2 "$work/unlocked.txt" | tr '\n' ' ' | cut -c 1-170)"
true
