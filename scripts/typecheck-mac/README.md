# Type-checking macOS-only code without a Mac

Half of Arbor builds only on macOS: `Sources/ArborKit/{AX,UI,Input,App,IPC}`, `Sources/ArborIPC/ControlClient.swift`, `Sources/Arbor`,
`Sources/arborctl`, `Sources/arbor-e2e`, `Sources/ArborTestWindows`, the tests that draw off screen or look at Carbon, and the Mac shell's helper tools
(`scripts/mac-shell/*.swift`), which not even `swift build` on a Mac sees. From a Linux container the only compiler for it is a Mac somewhere
else: minutes of waiting, and not there at all when Actions is down. This folder has stand-ins for the parts of
Apple's frameworks that code uses: declarations with the SDK's names, types, optionality and actor isolation, and bodies that do nothing (but see "The part that does something"). Against
them the Swift 6 compiler on Linux checks what a compiler checks: names, labels, types, optionals, overrides, required initializers,
`private`, isolation, `Sendable`.

```bash
make typecheck-mac                              # the checkout
make typecheck-mac REF=origin/feat/F99-thing    # that commit's Sources, Tests and helpers, with this checkout's stand-ins
make typecheck-mac ALL=1                        # also the tests the branch has not changed (see "What is covered"); a minute
make typecheck-mac-selftest                     # does it notice, and only then? what is wrong in probes/ must be reported, what is right must not
```

Half a minute, two after a stand-in changed. It works on a copy in `.build/typecheck-mac`, so nothing in the checkout changes.
All of a target's errors come in one run; a library that fails keeps what imports it from being looked at, and the output says so.

**What a result means.** An error is nearly always a real error. A pass is not proof: a stand-in can be more lenient than the SDK, and nothing runs.
In October 2026 the Accessibility layer's rewrite (900 lines), the runner's new sessions and a 700-line probe each compiled on a Mac at
the first attempt after passing here.

## What is covered

All macOS-only sources, whole. **Of the tests, the files with something in them for the Mac alone** (`#if os(macOS)`, `#if canImport(AppKit)`, `import AppKit`…): Linux's
compiler skips those blocks, so without this they meet their first compiler on a Mac. **And the test files that make a set, a dictionary or a hash and that the branch has changed** since it left the trunk
(`origin/swarm/trunk`, else `origin/main`, or `BASE=<ref>`): those may hash geometry, which Linux allows and macOS 14 does not, and the trunk has passed this check. The rest of
a test target is read for what it declares, not checked: `make check` compiles it. `ArborCore` and `ArborTesting` are checked whole, beside the rest, so they cost no time.

| Module | Stand-in | How much of it |
|---|---|---|
| Foundation, Darwin, ObjectiveC: what Linux lacks | `stubs/MacFoundation`, `stubs/Darwin` | Core Foundation (run loops, mach ports, notification centres), the dispatch sources for files, processes and memory pressure, key-value observing, Apple events, `Selector`, `DistributedNotificationCenter`, `UndoManager`, a dozen Darwin-only calls |
| CoreGraphics | `stubs/CoreGraphics` | Window list, displays, events and event taps, paths, colours, images, contexts, transforms |
| ApplicationServices | `stubs/ApplicationServices` | The Accessibility API |
| QuartzCore | `stubs/QuartzCore` | Layers (plain, shape, gradient, text), animations, transactions, display links |
| AppKit | `stubs/AppKit`, seven files | Application, workspace, screens, events, responders, windows, panels, views, Auto Layout, drawing, text drawing, menus, the status bar, the usual controls |
| Carbon.HIToolbox | `stubs/Carbon` (C), `stubs/CarbonSwift` | Hot keys, event handlers, virtual key codes, `UCKeyTranslate`, text input sources |
| os | `stubs/os` | `Logger`, `OSAllocatedUnfairLock`, signposts |
| ServiceManagement | `stubs/ServiceManagement` | `SMAppService` |
| ScreenCaptureKit | `stubs/ScreenCaptureKit`, with the little of `CoreMedia` and `CoreVideo` it refers to | As of macOS 14: shareable content, filters, configurations, screenshots, streams |
| ImageIO, UniformTypeIdentifiers | `stubs/ImageIO`, `stubs/UniformTypeIdentifiers` | Image sources and destinations with their usual keys; `UTType` |
| CoreAudio, CoreMediaIO | `stubs/CCoreAudio`, `stubs/CCoreMediaIO` (C: types and constants), `stubs/CoreAudio`, `stubs/CoreMediaIO` (the functions) | The hardware objects' properties and listeners |
| UserNotifications | `stubs/UserNotifications` | The centre, requests, content, settings |
| Combine | `stubs/Combine`, three files | Publishers, subscribers, subjects, cancellables, `@Published`, `ObservableObject`, the operators with the types under `Publishers` they return, schedulers (`DispatchQueue`, `RunLoop`, `OperationQueue`), and the publishers of `NotificationCenter`, `Timer`, `URLSession` and key-value observing |
| SwiftUI | `stubs/SwiftUI`, fifteen files | As of macOS 14: `View`, `ViewModifier` and the real result builders; the property wrappers, bindings, the environment and preferences; text, fonts, images, colours and shape styles; shapes and paths; stacks, grids, lists, forms, tabs, navigation; the controls and their styles; the common modifiers; animation and transitions; gestures; sheets, alerts, toolbars; accessibility; `Layout`; `App`, scenes and commands; `NSHostingView`, `NSHostingController`, `NSViewRepresentable`. What is left out is listed under "Known differences" |

Not there at all yet: IOKit, CoreImage, CoreText, Metal, AVFoundation, Security. A file that imports one fails with "no such module".

## The part that does something

What Arbor's Accessibility layer calls (the Accessibility API, `NSWorkspace`, `NSRunningApplication`, `NSScreen`, `NSEvent`'s monitors and class properties, `CGWindowListCopyWindowInfo`, `CGEventSource`, type ids, booleans and run loop sources of Core Foundation) has bodies that ask a model of a
Mac, `stubs/FakeMacOS`, which comes first in `check.sh`'s order. `make mac-on-linux` compiles these same files for real, links them with the layer and runs it (`scripts/mac-on-linux/README.md`). To this tool it makes no difference: it reads what is declared. **Keep the declarations as the SDK has them**; what the
model needs besides begins with an underscore (`_stands`, `_pid`, `_onRunLoop`). Some of it has to be public, one module to the next; `prepare.py` reports it, and `import FakeMacOS`, wherever Arbor's sources, tests or helpers use it: no Mac has it.

## When it complains about something Apple does have

Add a line with the construct to the folder's file in `probes/` as well, so that it stays accepted. A mistake that slipped through goes there too, marked `// wrong`.

Add the declaration to `stubs/`, copied from the SDK's interface as exactly as you know it: optionality, `@MainActor`, `@Sendable`, `open` (Arbor
subclasses and overrides), which initializers are designated, convenience and `required`, `@discardableResult` (C functions' results may be ignored).
Add its siblings while you are there. If you are not sure that a method exists with that signature on macOS 14, that is worth knowing before a Mac tells you.
**When in doubt, be strict**: not `Sendable`, on the main actor, optional. Code that satisfies a strict stand-in compiles against a lenient SDK; the
other way round it does not. What the trunk does and a Mac has compiled is evidence, and outranks memory.

## What `prepare.py` does to the copy

Linux's Swift has no Objective-C and glibc is not Darwin, so the copy is rewritten, line for line, before it is compiled:

- `@objc` is removed, and `#selector(x)` becomes `Selector(checked: x)`, a reference to the method, so that its name and labels are still checked.
- `stdout`, `stderr`, `SOCK_STREAM`, `SHUT_WR`, `tv_usec:` and `sun_len`, which glibc spells with other types, are adapted. `NSAttributedString()` gets an argument.
- Every file imports `MacFoundation`; a file that imports Carbon also gets what Carbon brings.
- `import Synchronization` (`Mutex`, `Atomic`), `Int128`, `RangeSet` and `InlineArray` are reported: Linux's toolchain has them whatever the version, a Mac from macOS 15 or 26 on. Not in a file
  that asks `#available(macOS 15`. **`@available(macOS 15, *)` in a stand-in would do nothing**: the compiler is compiling for Linux, where `*` applies. So what is newer than
  macOS 14 is left out of the stand-ins, and using it is an error, also behind `#available`; if that is ever wanted, add it deprecated with the words "only available in macOS 15.0 or newer".
- `Set<CGRect>` and `[CGPoint: …]` are reported: `CGRect`, `CGPoint` and `CGSize` can be hashed only from macOS 15, Arbor runs on 14, and Linux's always can. Where the type is not
  spelt out, `Set(frames)`, the compiler finds it: `stubs/MacFoundation/HashedGeometry.swift` has more specialised, deprecated twins of the ways into a set, a dictionary and a
  hasher, and `check.sh` makes an error of that warning. Not found: a set or dictionary literal whose type is inferred, `.hashValue`, and a struct's own synthesised `Hashable` over a
  `CGRect`, which the Mac does not refuse either (`Seam` compiled there).
- Conditions are answered as a Mac answers them: `os(macOS)` is true, every other `os(…)` false, and `canImport` of `Glibc` or `FoundationNetworking` false.
  Otherwise the compiler, being on Linux, would check the `#else` and skip the very lines this tool is for.

And it checks two things that only the Mac's compiler would, in the compiler's format:

- `#selector` of a method that no file marks `@objc`;
- `as?` and `is` with a Core Foundation type (`AXUIElement`, `CGColor`, `CFString`…), which the Mac refuses because such a test cannot fail.

## The Mac shell's helpers

Each `scripts/mac-shell/<tool>.swift` is a program of one file that a script compiles on the Mac before it does anything else, so a slip in one costs a whole run there. Each
is checked as a program of its own, in language mode 5, as `lib.sh` compiles it, after `prepare.py`. One that fails fails the check and keeps none of the others from being
looked at. They see a second set of the stand-ins' modules (`.build/typecheck-mac/modules5`) in which every declaration's `@MainActor` is `@preconcurrency`, which is what
the SDK's is, coming from Objective-C: in mode 5 code at the top level may say `NSApplication.shared.run()`. In the first set that would turn mistakes in Arbor's own Swift 6
code into warnings. "Result of call is unused" is not reported for them: what comes from C and Objective-C may be called for its effect alone, and Foundation on Linux,
written in Swift, says otherwise.

## Known differences

- **C callbacks.** `AXObserverCallback`, `CGEventTapCallBack`, `CFNotificationCallback` and `CGDisplayReconfigurationCallBack` are `@convention(c)` on the Mac, so what is passed for one
  must capture nothing. Linux refuses that convention for functions that take classes, so here they are ordinary closure types. A capture is noticed all the same: in the helpers' copy of the
  stand-ins the four are `@convention(thin)`, and every file that speaks of one goes a stage further than the type checker (`-emit-silgen`, in language mode 5), which refuses a closure or a function
  with a context; `check.sh` puts the Mac's words in place of the compiler's own ("INTERNAL ERROR: feature not implemented…"). It tells a top-level `let` of a script, which is a global, from what a top-level
  `guard let` binds, which is not, as a Mac does. It rests on how this compiler happens to treat that convention: the self-test has probes for it, and fails if that changes. Not covered: the tests, and a
  callback type that is not among the four. (Carbon's `EventHandlerUPP` is a real C pointer here too.)
- **Availability.** Nothing checks `@available`: an API newer than macOS 14 used without `if #available` passes here and fails there. The stand-ins hold to
  macOS 14; think twice before adding something newer. What the macOS 15 SDK took away (`CGWindowListCreateImage`) is marked unavailable.
- **Imports.** The Mac's toolchain checks that each file imports the module whose members it uses (`scripts/lint-imports.py`).
  The stand-ins re-export one another as Apple's frameworks do, but every file gets Foundation here whatever it imports.
- **Optional protocol methods** (`NSApplicationDelegate`, `NSWindowDelegate`, `NSMenuDelegate`…) are requirements with default bodies. A delegate method with a
  misspelt name is a method nobody calls, here as on the Mac; the Mac at least warns when it is nearly right.
- **Stricter on purpose:** no CoreGraphics class is `Sendable`; `NSAnimationContext`'s completion handlers are `@Sendable`; key-value observers' handlers are `@Sendable`.
- **SwiftUI, where it is more lenient than the SDK.** Blocks in a scene, commands or toolbar builder may be of any length (ten in the SDK). A view with several accessibility
  modifiers has another type than on the Mac, which only code that spells the type out could notice. Views that SwiftUI draws itself conform to a `_PrimitiveView`
  the SDK does not have (likewise `_PrimitiveScene`, `_PrimitiveGesture`…): do not use those names. Deprecations are marked only where they are old and well known.
- **SwiftUI, where it may be stricter.** The initialisers of views (`VStack`, `Button`, `List`…), gestures and styles are on the main actor; newer SDKs have made some `nonisolated`.
  `LocalizedStringKey`, `EnvironmentValues`, `Transaction`, `AnyTransition` and `GeometryProxy` are not `Sendable`. The closure of `onPreferenceChange` and the first of `onGeometryChange` are `@Sendable`.
- **`Binding(get:set:)`.** The SDK declares the closures `@Sendable @isolated(any)` under `@preconcurrency`, and so does the stand-in. A `@Sendable` closure is not on the main
  actor just because the view that makes it is, so `Binding(get: { model.text }, …)` draws *warnings* ("can not be referenced from a Sendable closure") and compiles.
  Whether the Mac gives the same warnings has not been looked up in a build log yet. If it does not, the SDK's parameters also inherit the actor
  (`@_inheritActorContext`), and the two initialisers in `stubs/SwiftUI/Data.swift` should say so. `{ @MainActor in … }` is silent either way.
- **SwiftUI, what is left out.** Macros, which a stand-in cannot be: `#Preview`, `@Entry` (`@Observable` is the toolchain's own and works). `Table`, `Canvas` and `GraphicsContext`, `OutlineGroup`,
  `NavigationView`, documents, `ShareLink` and everything about drag, drop, `Transferable`, item providers and file dialogues, `symbolEffect`, `visualEffect`, phase and keyframe animators,
  `sensoryFeedback`, the deprecated `Alert` and `ActionSheet`, and every overload that takes a `LocalizedStringResource`, an `ImageResource` or a `CTFont`, types Linux has no counterpart for.
  Whatever came after macOS 14 (`Tab`, `Color.mix`, `containerBackground(_:for: .window)`, the window modifiers of macOS 15) is left out on purpose.
- **Combine.** The types under `Publishers` have the SDK's names, generic parameters, `Output` and `Failure`, but no initialisers (except `MergeMany`) and no stored properties: build chains with the operators.
  `merge(with:)` stops at four publishers (eight in the SDK). `Record` and the `Just`-, `Sequence`- and `Optional`-specific operators that keep the concrete type are not there, so
  `Just(1).map { … }` is a `Publishers.Map<Just<Int>, …>` here and a `Just<…>` on the Mac. Nothing but `Demand` and `Completion` is `Sendable`, as in the SDK.
- `CFString`, `CFDictionary`, `CFArray`, `CFData`, `CFNumber` and `CFURL` are Foundation's classes, so that `as` bridges as on the Mac. Other Core Foundation types are empty classes.
  The price: a bare string literal passes for a `CFString` here (`AXUIElementSetAttributeValue(element, "AXMain", value)`), and the Mac wants `"AXMain" as CFString`.
- Key paths for `observe(_:)` need `@objc dynamic` properties on the Mac; here any key path will do.
- Nothing is linked, so a function that exists in no library goes unnoticed (`make mac-on-linux` links the Accessibility layer, and only that).
- `AXObserverCreate`'s callback is `@escaping` here, because the model keeps it. On the Mac it is a C function pointer, to which the word does not apply.
