# What a step of CI's Mac job leaves behind, printed at its end. Sourced by the probe-step-*.sh. Only reads.
probe_state() {
  echo
  echo "== what this step leaves behind ($(uptime | sed 's/.*up/up/'))"
  echo "-- processes of Arbor's:"
  # safe anywhere: whoever sources this has ended by now anywhere but on one of GitHub's Macs, where nobody has anything open
  pgrep -lf 'Arbor|arbor-|arborctl|xctest|swiftpm-testing' | cut -c 1-160 || true
  echo "-- in front: $(.build/mac-shell/pointer front 2>&1 | head -n 1)"
  echo "-- the pointer: $(.build/mac-shell/pointer where 2>&1), the button: $(.build/mac-shell/pointer button 2>&1 | head -n 1)"
  echo "-- Accessibility for this process: $(.build/mac-shell/pointer ax-access 2>&1 | head -n 1)"
  echo "-- Spaces:"
  .build/mac-shell/vdisplay spaces 2>&1 | head -n 6
  echo "-- windows on screen:"
  .build/mac-shell/pointer windows 2>&1 | head -n 25 | cut -c 1-140
  echo "-- macOS's own tiling and the wallpaper click:"
  defaults read com.apple.WindowManager 2>/dev/null | grep -E "EnableTiling|EnableStandardClickToShowDesktop|GloballyEnabled" || echo "(all at their defaults)"
  echo "-- secure input: $(ioreg -l -w 0 | grep -c kCGSSessionSecureInputPID)"
}
