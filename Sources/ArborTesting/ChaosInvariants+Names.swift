import ArborCore
import ArborKit
import CoreGraphics

/// What named spaces promise, whatever else happens (docs/features/F20-named-spaces.md).
extension ChaosRunner {
  func nameViolations(_ problems: inout [InvariantViolation]) {
    let connected = controller.workspaces.map { (id: $0.key, workspace: $0.value) }
    let waiting = controller.dormant.map { (id: $0.key, workspace: $0.value.workspace) }
    for (display, workspace) in connected + waiting {
      let (tree, names) = (workspace.tree, workspace.names)
      // Never the names themselves: a failure's text ends up in reports.
      if Set(names.keys.map(SpaceName.key)).count != names.count {
        problems.append(.init("names", "two spaces on \(display) have the same name"))
      }
      if Set(names.values).count != names.count { problems.append(.init("names", "a space on \(display) has two names")) }
      if !names.keys.allSatisfy(SpaceName.isTidy) { problems.append(.init("names", "a name on \(display) could not have been given")) }
      for node in names.values.sorted() {
        guard tree.contains(node) else {
          problems.append(.init("names", "a name on \(display) is on \(node), which is gone"))
          continue
        }
        // Something to go to and find nothing. A place kept for a window that is still to come counts as that window.
        if tree.windows(under: node).isEmpty, !tree.subtree(node, contains: tree.desktop) {
          problems.append(.init("names", "the named space \(node) on \(display) is empty"))
        }
      }
      let kept = Set(tree.kept(for: .name)), named = Set(names.values.filter(tree.isSplit))
      if kept != named {
        problems.append(
          .init("names", "on \(display) \(kept.sorted()) are kept for a name, and the named groups are \(named.sorted())"))
      }
    }

    // The field belongs to the space it was opened on, and there is one keyboard.
    let fields = harness.overlays.scenes.compactMap(\.value.namePrompt)
    if fields.count > 1 { problems.append(.init("name-field", "\(fields.count) name fields are showing")) }
    for field in fields {
      guard case .space(let node, _, _, _) = field.subject else { continue }
      guard let workspace = controller.workspaces[field.display] else {
        problems.append(.init("name-field", "the name field is showing on \(field.display), which is not connected"))
        continue
      }
      if workspace.camera != node {
        problems.append(.init("name-field", "the name field is about \(node) and the view on \(field.display) is on \(workspace.camera)"))
      }
    }
  }
}
