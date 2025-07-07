import ApplicationServices
import Cocoa
import Foundation
import SwiftUI

func alert(msg: String = "") {
    let alert = NSAlert.init()
    alert.messageText = msg
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

var settings: Settings = Settings()

func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    // Check accessibility
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true] as CFDictionary?

    if !AXIsProcessTrustedWithOptions(options) {
        return
    }

    // Start app
    app.run()
}

main()
