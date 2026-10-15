#!/bin/bash
# Makes, once, the certificate this Mac signs its own builds of Arbor with, so that Accessibility permission
# survives rebuilds. Why that works is in scripts/sign.sh and docs/INSTALL.md.
#
#   scripts/make-signing-identity.sh            make "Arbor Local Signing" in the login keychain
#   scripts/make-signing-identity.sh --remove   delete it again
#   … --keychain <file>                         another keychain, which must exist, be unlocked and be on the search
#                                               list: codesign finds no identity in any other, whatever --keychain says
#   … --name <name>                             another name; sign with it through ARBOR_SIGN_IDENTITY
#
# It is a self-signed certificate that is good for code signing and nothing else, with a new private key that
# cannot be exported from the keychain. Nothing is trusted, installed system-wide or sent anywhere, and no
# administrator rights are needed: codesign signs with a certificate nobody trusts, and macOS's permission
# database only asks whether the next build is signed with the same one. Running it again changes nothing.
#
# This script asks for no password, takes none, and changes nothing about any key but its own. Whether codesign can use the new key is not
# reasoned out but tried: the script ends by signing something, and goes by that. If macOS wants the owner's leave first it asks in a
# dialog of its own: type the keychain's password THERE and choose Always Allow. (On GitHub's Macs with macOS 14, 15 and 26 none
# came.) With nobody at a terminal the trial has $ARBOR_DIALOG_WAIT seconds (20), and a dialog goes with it. A run that fails or is
# interrupted takes the certificate and the key out again.
#
# What goes into, or out of, a person's login keychain is theirs to decide: without a terminal on standard input (a script, a loop, an
# agent that follows a page) it declines with exit code 77, unless --keychain names another keychain or ARBOR_UNATTENDED=1 says
# that the owner asked for it.
set -euo pipefail

name="Arbor Local Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"
theirs=yes
action=create

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --remove) action=remove ;;
    --keychain)
      keychain=${2:?--keychain needs a file}
      theirs=no
      shift
      ;;
    --name)
      name=${2:?--name needs a name}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
  shift
done

# GitHub's Macs are nobody's, and run their jobs as `runner`; a runner on somebody's own Mac says GITHUB_ACTIONS=true too.
nobodys_mac() { [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ]; }
if [ "$theirs" = yes ] && [ ! -t 0 ] && [ "${ARBOR_UNATTENDED:-}" != 1 ] && ! nobodys_mac; then
  echo "make-signing-identity.sh: nobody is at a terminal here, and this would change the login keychain of whoever owns this Mac." >&2
  echo "Nothing was touched. Run it from a terminal; or, if the owner asked for it, with ARBOR_UNATTENDED=1." >&2
  exit 77
fi
[ "$(uname)" = Darwin ] || { echo "make-signing-identity.sh: keychains and codesign exist only on macOS" >&2; exit 1; }
[ -f "$keychain" ] || { echo "make-signing-identity.sh: there is no keychain at $keychain" >&2; exit 1; }

# The lines of `security find-identity` for our certificate: `  1) <SHA-1> "Arbor Local Signing" (<why it is not valid>)`.
# Without -v, which hides certificates that are not trusted. An identity that is valid is listed twice.
identity_lines() { security find-identity -p codesigning "$keychain" 2>/dev/null | grep -F "\"$name\"" || true; }
identity_hashes() { identity_lines | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) .*/\1/p' | sort -u; }
# The SHA-1 of every certificate called just that, with a key or without. -c alone will not do: it finds every name that contains the one
# asked for, and "Arbor Local Signing 2" is somebody's too.
certificate_hashes() {
  { security find-certificate -a -Z -c "$name" "$keychain" 2>/dev/null || true; } | awk -v wanted="\"$name\"" '
    /^SHA-1 hash: / { sha = $3 }
    /^ *"labl"<blob>=/ { label = $0; sub(/^[^=]*=/, "", label); if (label == wanted) print sha }' | sort -u
}
# take_out <SHA-1>: the certificate and its key; the certificate alone where an import was cut short. Whether it has gone.
take_out() {
  security delete-identity -Z "$1" "$keychain" >/dev/null 2>&1 || security delete-certificate -Z "$1" "$keychain" >/dev/null 2>&1 || true
  case "$(certificate_hashes)" in *"$1"*) return 1 ;; *) return 0 ;; esac
}

if [ "$action" = remove ]; then
  removed=0
  for hash in $(certificate_hashes); do
    if take_out "$hash"; then
      echo "Deleted the certificate $hash and its private key from $keychain"
      removed=$((removed + 1))
    else
      echo "make-signing-identity.sh: the certificate $hash could not be deleted from $keychain. Is the keychain locked?" >&2
      exit 1
    fi
  done
  if [ "$removed" -eq 0 ]; then
    echo "There is no \"$name\" in $keychain; nothing to remove"
  else
    echo "Builds are signed ad hoc from now on. Arbor's entry under Accessibility still names the old certificate:"
    echo "  tccutil reset Accessibility com.evbarleyg.arbor   removes it, and the next build asks again."
  fi
  exit 0
fi

# What this run has put into the keychain and has not yet seen to work. Whatever ends the run before that (a failure, ⌃C at macOS's dialog,
# a closed window, a reader of the output that has left) takes it out again: a certificate that is there and of no use is worse than
# none, because sign.sh finds it, and every build then fails or waits for a dialog.
imported=""
umask 077
work=$(mktemp -d) || { echo "make-signing-identity.sh: no temporary folder" >&2; exit 1; }
clean_up() {
  if [ -n "$imported" ]; then
    if take_out "$imported"; then
      echo "  The certificate and its key were taken out of the keychain again: builds are signed ad hoc as before." >&2
    else
      echo "  The certificate could not be taken out of the keychain again: run this script with --remove." >&2
    fi
  fi
  rm -rf "${work:?}"
}
trap clean_up EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 141' PIPE
trap 'exit 143' TERM

# codesign looks for an identity in the keychains on the search list and nowhere else, whatever --keychain says: macOS 14, 15 and 26
# alike. The list shows paths without symbolic links.
on_the_search_list() {
  local real listed
  real=$(cd "$(dirname "$keychain")" && pwd -P)/$(basename "$keychain")
  listed=$(security list-keychains 2>/dev/null || true)
  case "$listed" in *"\"$real\""* | *"\"$keychain\""*) return 0 ;; *) return 1 ;; esac
}

patience=${ARBOR_DIALOG_WAIT:-20}
# What perl reads as 0 would be no limit at all.
case "$patience" in
  "" | *[!0-9]* | 0) echo "make-signing-identity.sh: \$ARBOR_DIALOG_WAIT is a whole number of seconds, not \"$patience\"" >&2; exit 64 ;;
esac
# can_sign <SHA-1>: signs a copy of /usr/bin/true, now, so that a dialog, if there is going to be one, comes while someone is looking. With
# nobody there it must not wait for an answer: it is gone again in seconds, dialog and all. 142: the time ran out.
can_sign() {
  local code=0 command=(codesign --force --sign "$1" --keychain "$keychain" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/probe")
  cp /usr/bin/true "$work/probe"
  if [ -t 0 ]; then
    # macOS 15 and 26 call every key they import by the first name, whatever name came with it; macOS 14 uses the second.
    echo "If macOS now asks whether codesign may use the key \"Imported Private Key\" or \"$name\": type the keychain's password"
    echo "into ITS dialog and choose ALWAYS ALLOW. (Allow would ask again, twice for every build.)"
    "${command[@]}" || code=$?
  else
    # perl waits and ends codesign itself: of a child that an alarm kills, bash prints a line of its own with all of this in it.
    perl -e '$patience = shift; $child = fork; exec @ARGV or exit 127 unless $child;
      $SIG{ALRM} = sub { kill "TERM", $child; waitpid $child, 0; exit 142 }; alarm $patience; waitpid $child, 0;
      exit($? & 127 ? 128 + ($? & 127) : $? >> 8)' "$patience" "${command[@]}" || code=$?
  fi
  return "$code"
}
say_that_it_can() {
  echo "codesign can sign with it. What macOS will remember about a build signed this way:"
  { codesign --display --requirements - "$work/probe" 2>/dev/null || true; } | sed -n 's/^\(# \)\{0,1\}designated => /  /p'
}
# say_why_not <can_sign's exit code>: after codesign has said its own piece, if it had one. 0 if starting afresh could help.
say_why_not() {
  if ! on_the_search_list; then
    echo "  $keychain is not on the keychain search list, and codesign finds an identity nowhere else, whatever --keychain says." >&2
    echo "  \`security list-keychains -d user\` shows the list; with -s and every keychain that is to be on it, it sets it." >&2
    return 1
  elif [ "$1" -eq 142 ]; then
    echo "  It had no answer in $patience seconds: macOS wants to ask in a dialog, and nobody is at a terminal here. Run this from a terminal" >&2
    echo "  and answer it with Always Allow." >&2
    return 1
  fi
  echo "  If a dialog came, it was answered Deny or closed. If the keychain is locked, as it is over ssh: \`security unlock-keychain\`." >&2
}

existing=$(identity_hashes)
if [ -n "$existing" ]; then
  echo "\"$name\" is already in $keychain:"
  identity_lines | sort -u | sed 's/^ *[0-9]*) /  /'
  case "$(identity_lines)" in
    *EXPIRED*) echo "It has expired. Run this script with --remove, then again; Arbor will need its permission once more." ;;
  esac
  if [ "$(printf '%s\n' "$existing" | wc -l)" -gt 1 ]; then
    echo "There is more than one, which codesign refuses as ambiguous. Run this script with --remove, then again."
    exit 1
  fi
  # To be there is not to be of use: an earlier version of this script could leave a key behind that codesign had no leave to use.
  code=0
  can_sign "$existing" || code=$?
  if [ "$code" -ne 0 ]; then
    echo "make-signing-identity.sh: it is there, but codesign cannot sign with it, so builds fail or wait for a dialog." >&2
    # It is left where it is: macOS's permission database may name it.
    if say_why_not "$code"; then echo "  If neither: this script with --remove, then once more; Arbor will need its permission again." >&2; fi
    exit 1
  fi
  say_that_it_can
  echo "Nothing to do."
  exit 0
fi

# macOS's own openssl (LibreSSL) first, so that whatever else is on the PATH makes no difference.
openssl=${ARBOR_OPENSSL:-/usr/bin/openssl}
[ -x "$openssl" ] || openssl=$(command -v openssl) || { echo "make-signing-identity.sh: no openssl" >&2; exit 1; }

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

"$openssl" req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 -config "$work/openssl.cnf" \
  -keyout "$work/key.pem" -out "$work/certificate.pem" 2>"$work/openssl.log" \
  || { cat "$work/openssl.log" >&2; echo "make-signing-identity.sh: $openssl could not make the certificate" >&2; exit 1; }
# From the file, not from what the keychain lists afterwards: this is the one thing in there that is this run's to take out again.
hash=$("$openssl" x509 -in "$work/certificate.pem" -noout -fingerprint -sha1 | sed 's/.*=//' | tr -d ':' | tr 'a-f' 'A-F')
case "$hash" in
  *[!0-9A-F]* | "") echo "make-signing-identity.sh: $openssl did not say the certificate's SHA-1" >&2; exit 1 ;;
esac

# `security import` reads only the old PKCS#12 algorithms. They are LibreSSL's defaults; OpenSSL 3 and later need
# to be asked for them.
legacy=()
case "$("$openssl" version)" in
  LibreSSL* | "OpenSSL 0."* | "OpenSSL 1."*) ;;
  *) legacy=(-legacy) ;;
esac
# The file lives for a moment in a folder only this user can read; `security import` refuses an empty password.
transport=$("$openssl" rand -hex 16)
"$openssl" pkcs12 -export ${legacy[@]+"${legacy[@]}"} -inkey "$work/key.pem" -in "$work/certificate.pem" -name "$name" \
  -out "$work/$name.p12" -passout "pass:$transport" 2>"$work/openssl.log" \
  || { cat "$work/openssl.log" >&2; echo "make-signing-identity.sh: $openssl could not pack the certificate" >&2; exit 1; }

# -x: the key cannot be exported again. -T: codesign is on the key's list of applications, which on the Macs that were tried is all it takes.
imported=$hash
security import "$work/$name.p12" -k "$keychain" -f pkcs12 -P "$transport" -x -T /usr/bin/codesign >/dev/null
case "$(identity_hashes)" in
  *"$hash"*) ;;
  *) echo "make-signing-identity.sh: the import went through, but $keychain shows no identity" >&2; exit 1 ;;
esac
echo "Made the code-signing certificate \"$name\" in $keychain"
echo "  SHA-1 $hash, $("$openssl" x509 -in "$work/certificate.pem" -noout -enddate | sed 's/notAfter=/valid until /')"

code=0
can_sign "$hash" || code=$?
if [ "$code" -ne 0 ]; then
  echo "make-signing-identity.sh: codesign cannot sign with the new certificate." >&2
  say_why_not "$code" || true
  exit 1
fi
# It works, so it stays, whatever becomes of the words that follow: their reader may have left.
imported=""
say_that_it_can

echo
if [ "$name" = "Arbor Local Signing" ]; then
  echo "\`make app\` and \`make install\` sign with it from now on."
else
  echo "To sign with it: ARBOR_SIGN_IDENTITY=\"$name\" make install"
fi
echo "The first build signed this way needs Accessibility permission once more. If an older build is listed there, clear"
echo "its entry, but NOT YET: an Arbor that is running needs it to bring its windows back when it quits. In this order:"
echo "  make install LAUNCH=0"
echo "  tccutil reset Accessibility com.evbarleyg.arbor"
echo "  open ~/Applications/Arbor.app"
echo "Remove the certificate with scripts/make-signing-identity.sh --remove."
