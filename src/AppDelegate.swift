import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var mainMenu: MainMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the main application menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenu.addItem(appMenuItem)
        NSApp.mainMenu = appMenu

        // Create the "Edit" menu for shortcuts
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        
        // Create the main application menu item (e.g., "Trackpad Mapper")
        let appName = ProcessInfo.processInfo.processName
        let appMenuItemTitle = NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let appSubMenu = NSMenu()
        appSubMenu.addItem(appMenuItemTitle)
        appSubMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appSubMenu
        
        appMenu.addItem(editMenuItem)

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Bundle.main.image(forResource: "trackpad_status_icon")!
        statusItem.button?.image!.isTemplate = true

        // Create the menu for the status bar item
        mainMenu = MainMenu()

        // Hook the menu to the status bar item
        statusItem.menu = mainMenu
    }
}
