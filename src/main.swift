import Cocoa
import Foundation
import SwiftUI
import ApplicationServices

func alert(msg: String = "") {
    let alert = NSAlert.init()
    alert.messageText = msg
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

var settings: Settings = Settings()

func main() {
    let _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)

    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true] as CFDictionary?

    if (!AXIsProcessTrustedWithOptions(options)) {
        return
    }

    let statusItem = NSStatusBar.system.statusItem(
                        withLength: NSStatusItem.variableLength)
    statusItem.button?.image = Bundle.main.image(forResource: "trackpad_status_icon")!
    statusItem.button?.image!.isTemplate = true

    let menu = MainMenu()
    statusItem.menu = menu

    menu.startProcess(nil)

    NSApp.run()
}

main()
