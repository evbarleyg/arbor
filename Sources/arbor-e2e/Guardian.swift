import Darwin
import Foundation

// Whatever becomes of the runner, no Arbor stays behind on the Mac it ran on.
//
// A caller's time limit ends the runner with a signal, perhaps one that cannot be caught, and the Arbor it started would go on
// arranging windows, without a menu bar item or shortcuts, brought back by its watchdog if anyone killed it. So the cleaning up is
// done by a process of its own, which waits at the far end of a pipe for the runner to end, as Arbor's watchdog waits for Arbor.
// (The test apps leave by themselves when their standard input closes.)
//
// `scripts/test-e2e-guardian.py` reads the program out of this file and holds it to a table of endings, against stand-ins for Arbor
// and its watchdog: `make check` runs it, on Linux too.

extension Runner {
  func startGuardian() throws {
    let process = Process()
    let (input, output) = (Pipe(), Pipe())
    // No child may hold the pipe open in this process's place.
    _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETFD, FD_CLOEXEC)
    process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    process.arguments = ["-e", Self.guardian, "arbor-e2e-guardian", home.path]
    process.standardInput = input
    // Not this process's: whoever reads them to the end would wait for the guardian too.
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    try? input.fileHandleForReading.close()
    try? output.fileHandleForWriting.close()
    guardianInput = input
    // Nothing is started before it says that it is in place, and nothing at all without it. If it ends instead, so does the line.
    guard let pid = Int32(readLine(from: output.fileHandleForReading)), getsid(pid) == pid else {
      throw Setup(description: "the guardian did not get a session of its own")
    }
    print("guardian: pid \(pid)")
  }

  /// The watchdog of the Arbor started last, by that Arbor's own word in its log, or in the log before it: a full one is set aside.
  func watchdogPID() -> Int32? {
    let said = "watchdog started, pid "
    let earlier = (try? String(contentsOf: home.appendingPathComponent("arbor.log.1"), encoding: .utf8)) ?? ""
    guard let line = (earlier + arborLog()).split(separator: "\n").last(where: { $0.contains(said) }), let range = line.range(of: said)
    else { return nil }
    return Int32(line[range.upperBound...].prefix { $0.isNumber })
  }

  /// It goes by the lock that keeps a second Arbor out of a home folder (`InstanceLock`), which the kernel keeps: whether anybody holds it
  /// is a question with an answer, and only the holder's number is in the file while it is held. No list of processes is read.
  static let guardian = #"""
    use strict;
    use Fcntl qw(:DEFAULT :flock);
    use File::Path qw(remove_tree);
    use POSIX qw(setsid);
    # The first argument is a name to be found by in a list of processes.
    my $home = $ARGV[1];
    # The file Arbor will lock, made before there is an Arbor.
    sysopen(my $lock, "$home/arbor.lock", O_RDWR | O_CREAT, 0600) or exit 1;
    # A caller's time limit may signal a whole group or session, and SIGKILL cannot be ignored: a session of its own. The leader of a group gets
    # none, and that is what Foundation makes of a child: so its child it is.
    my $child = fork;
    exit(defined $child ? 0 : 1) if !defined $child || $child;
    setsid() > 0 or exit 1;
    $SIG{$_} = 'IGNORE' for qw(INT TERM HUP);
    # The folder it was started from may be gone before it is done.
    chdir '/';
    # In place.
    syswrite(STDOUT, "$$\n");
    open(STDOUT, '>', '/dev/null');
    # Standard input is a pipe that only the runner holds open: it ends when the runner does, however that came about.
    while (1) {
      my $count = sysread(STDIN, my $bytes, 4096);
      last if defined $count ? $count == 0 : !$!{EINTR};
    }
    my ($asked, $since, $until) = (0, 0, time + 45);
    # Taking the lock says that nobody holds it, and keeps it that way.
    until (flock($lock, LOCK_EX | LOCK_NB)) {
      exit 1 if time > $until;
      sysseek($lock, 0, 0);
      sysread($lock, my $text, 32);
      if (defined $text && $text =~ /^(\d+)\s*$/ && $1 > 1) {
        if ($1 != $asked) {
          # A clean quit: windows come back into view and the watchdog is told to leave.
          ($asked, $since) = ($1, time);
          kill 'TERM', $asked;
        } elsif (time - $since >= 5) {
          # Its watchdog waits a moment before it starts another, and the lock is taken sooner than that.
          kill 'KILL', $asked;
        }
      }
      select(undef, undef, undef, 0.02);
    }
    # An Arbor may have been killed a moment ago, and the one its watchdog starts not be there yet. It finds the lock held and leaves, having
    # started nothing. The runner gives such an Arbor fifteen seconds to be there. Nobody waits for this.
    sleep 15;
    # Nobody else removes it: an Arbor on its way would make it anew, with a lock in it that nobody holds. Nothing but a folder of the runner's.
    remove_tree($home) if $home =~ m{/arbor-e2e-\d+$};
    """#
}
