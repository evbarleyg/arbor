// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// Darwin's sockets, which glibc spells with other types (prepare.py).
import Foundation

func probeSockets() {
  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  var address = sockaddr_un()
  address.sun_family = sa_family_t(AF_UNIX)
  address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
  var limit = timeval(tv_sec: 1, tv_usec: Int32(0))
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
  shutdown(fd, SHUT_WR)
  fputs("x", stderr)
  shutdown(fd, SHUT_WR, 0)  // wrong
  address.sun_familly = 1  // wrong
  close(fd, now: true)  // wrong
}
