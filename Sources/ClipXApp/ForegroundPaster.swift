import ApplicationServices
import AppKit
import Foundation

final class ForegroundPaster {
    func hasAccessibilityPermission(promptForPermission: Bool = true) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptForPermission
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func paste(into application: NSRunningApplication, completion: @escaping (Bool) -> Void) {
        guard !application.isTerminated else {
            completion(false)
            return
        }

        let activated = application.activate(options: [.activateAllWindows])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
            completion((activated || isFrontmost) && self.postCommandV())
        }
    }

    private func postCommandV() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return down != nil && up != nil
    }
}
