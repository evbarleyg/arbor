#!/bin/bash
# Makes, once, the certificate this Mac signs its own builds of Arbor with, so that Accessibility permission
# survives rebuilds. Why that works is in scripts/sign.sh and docs/INSTALL.md.
#
#   scripts/make-signing-identity.sh            make "Arbor Local Signing" in the login keychain
#   scripts/make-signing-identity.sh --remove   delete it again
#   … --keychain <file>                         another keychain, which must exist and be unlocked; if it is not on
#                                               the search list, sign with ARBOR_SIGN_KEYCHAIN=<file>
#   … --name <name>                             another name; sign with it through ARBOR_SIGN_IDENTITY
#
# It is a self-signed certificate that is good for code signing and nothing else, with a new private key that
# cannot be exported from the keychain. Nothing is trusted, installed system-wide or sent anywhere, and no
# administrator rights are needed: codesign signs with a certificate nobody trusts, and macOS's permission
# database only asks whether the next build is signed with the same one. Running it again changes nothing.
#
# codesign may use the new key only with the owner's leave. The recommended way to give it is macOS's own dialog: press
# Return at the one question this script asks, type the keychain's password into the dialog and choose Always Allow.
# Typing the password here instead saves the dialog; it is then, for an instant, an argument of `security`, which `ps`
# can show. $ARBOR_KEYCHAIN_PASSWORD answers the question for scripts.
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

if [ "$action" = remove ]; then
  removed=0
  for hash in $(identity_hashes); do
    security delete-identity -Z "$hash" "$keychain" >/dev/null
    echo "Deleted the certificate $hash and its private key from $keychain"
    removed=$((removed + 1))
  done
  # A certificate left without its key, by an import that was interrupted.
  for hash in $(security find-certificate -a -c "$name" -Z "$keychain" 2>/dev/null | sed -n 's/^SHA-1 hash: //p'); do
    security delete-certificate -Z "$hash" "$keychain" >/dev/null
    echo "Deleted the certificate $hash from $keychain"
    removed=$((removed + 1))
  done
  if [ "$removed" -eq 0 ]; then
    echo "There is no \"$name\" in $keychain; nothing to remove"
  else
    echo "Builds are signed ad hoc from now on. Arbor's entry under Accessibility still names the old certificate:"
    echo "  tccutil reset Accessibility com.evbarleyg.arbor   removes it, and the next build asks again."
  fi
  exit 0
fi

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
  echo "Nothing to do."
  exit 0
fi

# macOS's own openssl (LibreSSL) first, so that whatever else is on the PATH makes no difference.
openssl=${ARBOR_OPENSSL:-/usr/bin/openssl}
[ -x "$openssl" ] || openssl=$(command -v openssl) || { echo "make-signing-identity.sh: no openssl" >&2; exit 1; }

umask 077
work=$(mktemp -d) || { echo "make-signing-identity.sh: no temporary folder" >&2; exit 1; }
trap 'rm -rf "${work:?}"' EXIT

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
  -out "$work/identity.p12" -passout "pass:$transport" 2>"$work/openssl.log" \
  || { cat "$work/openssl.log" >&2; echo "make-signing-identity.sh: $openssl could not pack the certificate" >&2; exit 1; }

# -x: the key cannot be exported again. -T: codesign is on the key's list of applications.
security import "$work/identity.p12" -k "$keychain" -f pkcs12 -P "$transport" -x -T /usr/bin/codesign >/dev/null
hash=$(identity_hashes)
[ -n "$hash" ] || { echo "make-signing-identity.sh: the import went through, but $keychain shows no identity" >&2; exit 1; }
echo "Made the code-signing certificate \"$name\" in $keychain"
echo "  SHA-1 $hash, $("$openssl" x509 -in "$work/certificate.pem" -noout -enddate | sed 's/notAfter=/valid until /')"

# Being on the key's list of applications has not been enough since macOS 10.12: the key also has a "partition
# list", and changing that takes the keychain's password. Only the key with our label is touched.
allow_codesign() {
  security set-key-partition-list -S apple-tool:,apple: -s -l "$name" -k "$1" "$keychain" >/dev/null 2>&1
}

silent=no
if [ -n "${ARBOR_KEYCHAIN_PASSWORD:-}" ]; then
  if allow_codesign "$ARBOR_KEYCHAIN_PASSWORD"; then silent=yes; else echo "\$ARBOR_KEYCHAIN_PASSWORD is not this keychain's password"; fi
elif [ -t 0 ]; then
  echo
  echo "codesign may use the new key only with your leave."
  echo "  Recommended: press Return. macOS then asks in a dialog of its own, in a moment."
  echo "  Or type this keychain's password here (for the login keychain, the one you log in with) and there is no dialog."
  echo "  It goes to macOS's \`security\` tool and nowhere else, as an argument that \`ps\` could show for an instant. A login"
  echo "  password is not something to type into a script from a repository out of habit, however honest this one is."
  tries=0
  while [ "$tries" -lt 3 ]; do
    tries=$((tries + 1))
    password=""
    IFS= read -r -s -p "Return, or the keychain's password: " password || true
    echo
    [ -n "$password" ] || break
    if allow_codesign "$password"; then
      silent=yes
      break
    fi
    echo "That is not the keychain's password."
  done
  unset password
fi

# Sign something now, so that a dialog, if there is going to be one, comes while someone is looking.
if [ "$silent" = yes ] || [ -t 0 ]; then
  if [ "$silent" = no ]; then
    echo
    echo "macOS now asks whether codesign may use the key \"$name\". Type the keychain's password and choose"
    echo "ALWAYS ALLOW. (Allow would ask again, twice for every build.)"
  fi
  cp /usr/bin/true "$work/probe"
  if codesign --force --sign "$hash" --keychain "$keychain" --timestamp=none --identifier com.evbarleyg.arbor.probe "$work/probe"; then
    echo "codesign can sign with it. What macOS will remember about a build signed this way:"
    codesign --display --requirements - "$work/probe" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => /  /p'
  else
    echo "codesign could not use the key. Run this script with --remove, then again." >&2
    exit 1
  fi
else
  echo "The first build will make macOS ask whether codesign may use the key: choose Always Allow."
fi

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
