import Cocoa

class MainMenu: NSMenu {
    var process: Process? = nil
    var versionItem: NSMenuItem? = nil
    var startItem: NSMenuItem? = nil
    var stopItem: NSMenuItem? = nil
    var preferenceItem: NSMenuItem? = nil
    var quitItem: NSMenuItem? = nil

    let toggleTrackingItemIndex = 2
    let preferenceItemIndex = 3

    var preferenceWindow: NSWindow? = nil

    required init(coder: NSCoder) {
        super.init(coder: coder)
        preferenceWindow = NSWindow(
            contentViewController: PreferenceViewController(mainMenu: self))
        preferenceWindow?.styleMask = [.titled, .closable, .miniaturizable]
        preferenceWindow?.title = "Preferences"
    }

    public init() {
        super.init(title: "")

        delegate = self

        // Version
        versionItem = NSMenuItem(
            title: "Version 0.0.1",
            action: nil,
            keyEquivalent: "")

        // Start process
        startItem = NSMenuItem(
            title: "Start absolute tracking",
            action: #selector(MainMenu.startProcess(_:)),
            keyEquivalent: "s")
        startItem!.keyEquivalentModifierMask = .command
        startItem!.target = self

        // Stop process
        stopItem = NSMenuItem(
            title: "Stop absolute tracking",
            action: #selector(MainMenu.stopProcess(_:)),
            keyEquivalent: "s")
        stopItem!.keyEquivalentModifierMask = .command
        stopItem!.target = self

        // Preference
        preferenceItem = NSMenuItem(
            title: "Preference",
            action: #selector(MainMenu.openPreference(_:)),
            keyEquivalent: ",")
        preferenceItem!.keyEquivalentModifierMask = .command
        preferenceItem!.target = self

        // Quit app
        quitItem = NSMenuItem(
            title: "Quit trackpad mapper",
            action: #selector(MainMenu.terminate(_:)),
            keyEquivalent: "q")
        quitItem!.keyEquivalentModifierMask = .command
        quitItem!.target = self

        addItem(versionItem!)
        addItem(NSMenuItem.separator())
        addItem(startItem!)
        addItem(preferenceItem!)
        addItem(NSMenuItem.separator())
        addItem(quitItem!)

        preferenceWindow = NSWindow(
            contentViewController: PreferenceViewController(mainMenu: self))
        preferenceWindow?.styleMask = [.titled, .closable, .miniaturizable]
        preferenceWindow?.title = "Preferences"

        startProcess(nil)
    }

    @objc
    public func startProcess(_: Any?) {
        if process == nil {
            var processUrl = Bundle.main.bundleURL
            processUrl.appendPathComponent("Contents/MacOS/trackpad_mapper_util")
            do {
                process = try Process.run(
                    processUrl,
                    arguments: settings.toArgs(),
                    terminationHandler: nil)

                items[toggleTrackingItemIndex] = stopItem!
            } catch {
                alert(msg: "Cannot spawn process")
            }
        }
    }

    @objc
    public func stopProcess(_: Any?) {
        if let process = process {
            process.terminate()
            self.process = nil

            items[toggleTrackingItemIndex] = startItem!
        }
    }

    @objc
    public func terminate(_: Any?) {
        if let process = process {
            process.terminate()
        }
        NSApp.terminate(nil)
    }

    @objc
    public func openPreference(_: Any?) {
        if let window = preferenceWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.level = .floating
        }
    }
}

extension MainMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: false)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}