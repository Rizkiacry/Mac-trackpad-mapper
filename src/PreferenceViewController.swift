import SwiftUI
import Cocoa

class PreferenceViewController: NSViewController, NSWindowDelegate {
    var mainMenu: MainMenu? = nil
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
    }
    
    init(mainMenu: MainMenu) {
        super.init(nibName: nil, bundle: nil)
        self.mainMenu = mainMenu
    }

    override func loadView() {
        title = "Preference"
        view = NSView(frame: NSMakeRect(0.0, 0.0, 300, 300))
        
        let ui = NSHostingView(rootView: PreferenceUIView(mainMenu: mainMenu!))
        ui.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(ui)
        
        NSLayoutConstraint.activate([
            ui.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ui.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.delegate = self
        view.window?.makeFirstResponder(view)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // 53 is the keycode for Escape
            view.window?.performClose(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
