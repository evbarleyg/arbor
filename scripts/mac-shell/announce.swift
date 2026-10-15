// announce: tells running processes that an Accessibility permission has changed, for Mac shell scripts.
//
// The switch in System Settings does three things: it writes a row into the permission database, the service that keeps the
// permissions knows of it, and this notification goes round. A process that is already running hears of a grant or a loss through the
// notification alone. So a script that writes the row itself restarts the service (`sudo killall -9 tccd`), waits a moment, and
// then runs this. In that order: announced before the restart, the flag says yes and event taps stay refused in that process.
//
// A script compiles it itself (swiftc -O -swift-version 5 scripts/mac-shell/announce.swift -o …). Needs no permission.

import Foundation

DistributedNotificationCenter.default().postNotificationName(
  Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
