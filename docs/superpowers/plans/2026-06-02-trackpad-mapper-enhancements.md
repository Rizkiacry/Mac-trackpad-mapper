# Trackpad Mapper Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork lokxii Mac-trackpad-mapper into trackpad-absolute-osx with auto-start, updated defaults, keyboard nav, preference fixes, and requireCommandKey toggle.

**Architecture:** SwiftUI status bar app spawns C CLI util. Settings passed via CLI args. Swift sets defaults and UI, C util handles trackpad callback and cursor movement.

**Tech Stack:** Swift (SwiftUI, Cocoa), C (CoreGraphics, MultitouchSupport private framework), make

---

### Task 1: Settings.swift — update defaults + requireCommandKey

**Files:**
- Create: `trackpad-absolute-osx/src/Settings.swift`

- [ ] **Write Settings.swift** with updated defaults: `trackpadRange = "0.25,0.25,0.75,0.75"`, `emitMouseEvent = true`, `requireCommandKey = false` (new field). Invert `toArgs()` logic to pass CLI args when `!useHeader`, and include `-c` flag for `requireCommandKey`.

```swift
import Cocoa

struct Settings: Codable {
    struct Range: Codable {
        var low: NSPoint
        var up: NSPoint

        init(low: NSPoint, up: NSPoint) {
            self.low = low
            self.up = up
        }

        init?(from string: String) {
            if Settings.Range.stringIsValid(string: string) {
                let compoenents = string.components(separatedBy: ",")
                                        .map { CGFloat(Float($0)!) }
                low = NSPoint(x: compoenents[0], y: compoenents[1])
                up = NSPoint(x: compoenents[2], y: compoenents[3])
            } else {
                return nil
            }
        }

        func toString() -> String {
            return "\(low.x),\(low.y),\(up.x),\(up.y)"
        }

        static func stringIsValid(string: String, name: String = "") -> Bool {
            let components = string.components(separatedBy: ",")
                                   .map({ (s: String) -> Bool in
                                       let f = Float(s)
                                       return f != nil && (0.0...1.0).contains(f!)
                                   })
            let isValid = components.count == 4 &&
                          components.reduce(true) { $0 && $1 }
            if !isValid && name != "" {
                alert(msg: name + " range not valid")
            }
            return isValid
        }
    }

    var useHeader: Bool = false
    var trackpadRange: Range? = Range(from: "0.25,0.25,0.75,0.75")
    var screenRange: Range? = nil
    var emitMouseEvent: Bool = true
    var requireCommandKey: Bool = false

    init(trackpad: Range? = nil, screen: Range? = nil) {
        trackpadRange = trackpad
        screenRange = screen
    }

    func toArgs() -> [String] {
        var args: [String] = []
        if !useHeader {
            if let trackpadRange = trackpadRange {
                args.append("-i")
                args.append(trackpadRange.toString())
            }
            if let screenRange = screenRange {
                args.append("-o")
                args.append(screenRange.toString())
            }
            if emitMouseEvent {
                args.append("-e")
            }
            if requireCommandKey {
                args.append("-c")
            }
        }
        return args
    }
}
```

### Task 2: main.swift — auto-start tracking, .accessory policy

**Files:**
- Create: `trackpad-absolute-osx/src/main.swift`

- [ ] **Write main.swift** with `.accessory` activation policy and auto-start.

```swift
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
```

### Task 3: MainMenu.swift — fix openPreference window handling

**Files:**
- Create: `trackpad-absolute-osx/src/MainMenu.swift`

- [ ] **Write MainMenu.swift** with kotkota-style `openPreference` (center, activate, floating level).

```swift
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

        versionItem = NSMenuItem(
            title: "Version 0.0.1",
            action: nil,
            keyEquivalent: "")

        startItem = NSMenuItem(
                            title: "Start absolute tracking",
                            action: #selector(MainMenu.startProcess(_:)),
                            keyEquivalent: "s")
        startItem!.target = self

        stopItem = NSMenuItem(
                            title: "Stop absolute tracking",
                            action: #selector(MainMenu.stopProcess(_:)),
                            keyEquivalent: "s")
        stopItem!.target = self

        preferenceItem = NSMenuItem(
                            title: "Preference",
                            action: #selector(MainMenu.openPreference(_:)),
                            keyEquivalent: ",")
        preferenceItem!.target = self

        quitItem = NSMenuItem(
                            title: "Quit trackpad mapper",
                            action: #selector(MainMenu.terminate(_:)),
                            keyEquivalent: "q")
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
```

### Task 4: PreferenceUIView.swift — local settings copy, keyboard nav, requireCommandKey

**Files:**
- Create: `trackpad-absolute-osx/src/PreferenceUIView.swift`

- [ ] **Write PreferenceUIView.swift** with `@State private var localSettings = settings`, `@FocusState` for Tab, `.onSubmit` for Return-to-next-field, `.keyboardShortcut(.defaultAction)` on Apply, `requireCommandKey` toggle.

```swift
import SwiftUI

struct PreferenceUIView: View {
    @State private var useHeader: Bool = settings.useHeader
    @State private var trackpadRange: String = settings.trackpadRange?.toString() ?? "0.25,0.25,0.75,0.75"
    @State private var screenRange: String = "0,0,1,1"
    @State private var emitMouseEvent: Bool = settings.emitMouseEvent
    @State private var requireCommandKey: Bool = settings.requireCommandKey

    @State private var localSettings = settings
    @FocusState private var focusedField: Field?

    enum Field {
        case trackpad
        case screen
    }

    var mainMenu: MainMenu

    var isValid: Bool {
        return Settings.Range.stringIsValid(string: trackpadRange, name: "Trackpad region") &&
               Settings.Range.stringIsValid(string: screenRange, name: "Screen region")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Use settings in header file (settings.h)", isOn: $useHeader)
                .toggleStyle(.checkbox)
            if !useHeader {
                Form {
                    TextField("Trackpad region:", text: $trackpadRange)
                        .focused($focusedField, equals: .trackpad)
                        .onSubmit { focusedField = .screen }
                    TextField("Screen region:", text: $screenRange)
                        .focused($focusedField, equals: .screen)
                        .onSubmit { apply() }
                }
                Toggle("Emit mouse events", isOn: $emitMouseEvent)
                    .toggleStyle(.checkbox)
                Toggle("Activate only while ⌘ pressed", isOn: $requireCommandKey)
                    .toggleStyle(.checkbox)
            }
        }
        .padding()
        Button(action: apply) {
            Text("Apply").padding()
        }
        .keyboardShortcut(.defaultAction)
    }

    private func apply() {
        if isValid && !useHeader {
            localSettings.trackpadRange = Settings.Range(from: trackpadRange)
            localSettings.screenRange = Settings.Range(from: screenRange)
        }
        localSettings.emitMouseEvent = emitMouseEvent
        localSettings.requireCommandKey = requireCommandKey
        localSettings.useHeader = useHeader
        settings = localSettings

        if mainMenu.process != nil {
            mainMenu.stopProcess(nil)
            mainMenu.startProcess(nil)
        }
    }
}
```

### Task 5: PreferenceViewController.swift — set proper window size

**Files:**
- Create: `trackpad-absolute-osx/src/PreferenceViewController.swift`

- [ ] **Write PreferenceViewController.swift** with 400x300 frame.

```swift
import SwiftUI
import Cocoa

class PreferenceViewController: NSViewController {
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
        view = NSView(frame: NSMakeRect(0.0, 0.0, 400, 250))

        let ui = NSHostingView(rootView: PreferenceUIView(mainMenu: mainMenu!))
        ui.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(ui)

        NSLayoutConstraint.activate([
            ui.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ui.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
```

### Task 6: trackpad_mapper_util.c — add -c flag for requireCommandKey

**Files:**
- Create: `trackpad-absolute-osx/src/trackpad_mapper_util.c`

- [ ] **Write trackpad_mapper_util.c** with `-c` flag support in `parseSettings` and `isCmdKeyPressed()` guard in `moveCursor`. Keep jitter/smoothing and `DISABLE_CURSOR_ON_MULTITOUCH`.

```c
#include <pthread.h>
#include <Carbon/Carbon.h>
#include <CoreGraphics/CoreGraphics.h>
#include "MultitouchSupport.h"
#include "../settings.h"

#define try(...) \
    if ((__VA_ARGS__) == -1) { \
        fprintf(stderr, "`%s` failed", #__VA_ARGS__); \
        exit(1); \
    }

typedef struct {
    float lowx, lowy, upx, upy;
} Range;

typedef struct {
    bool useArg;
    Range trackpadRange;
    Range screenRange;
    bool emitMouseEvent;
    bool requireCommandKey;
} Settings;

Settings settings = { false, { 0.25, 0.25, 0.75, 0.75 }, { 0, 0, 1, 1, }, true, false };
CGSize screenSize;

int mouseEventNumber = 0;
pthread_mutex_t mouseEventNumber_mutex;
#define MAGIC_NUMBER 12345

bool isCmdKeyPressed() {
    CGEventFlags flags = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState);
    return (flags & kCGEventFlagMaskCommand) != 0;
}

double _rangeRatio(double n, double lower, double upper) {
    if (n < lower || n > upper) {
        return -1;
    }
    return (n - lower) / (upper - lower);
}

double _reverseRangeRatio(double n, double lower, double upper) {
    if (n < 0) {
        return n;
    }
    return n * (upper - lower) + lower;
}

MTPoint _map(double normx, double normy) {
    MTPoint point = {
        .x = _rangeRatio(
            normx, settings.trackpadRange.lowx, settings.trackpadRange.upx),
        .y = _rangeRatio(
            normy, settings.trackpadRange.lowy, settings.trackpadRange.upy),
    };

    point.x = _reverseRangeRatio(
            point.x, settings.screenRange.lowx, settings.screenRange.upx);
    point.y = _reverseRangeRatio(
            point.y, settings.screenRange.lowy, settings.screenRange.upy);

    point.x *= screenSize.width;
    point.y *= screenSize.height;
    return point;
}

void moveCursor(double x, double y) {
    if (settings.requireCommandKey && !isCmdKeyPressed()) {
        return;
    }

    static double lastX = -1.0;
    static double lastY = -1.0;

    const double threshold = JITTER_THRESHOLD;
    double alpha = JITTER_ALPHA;

    if (alpha <= 0.0) {
        alpha = 0.1;
    } else if (alpha > 1.0) {
        alpha = 1.0;
    }

    if (lastX >= 0.0 && lastY >= 0.0) {
        double dx = x - lastX;
        double dy = y - lastY;
        double dist2 = dx * dx + dy * dy;

        if (dist2 < threshold * threshold) {
            return;
        }

        x = lastX + alpha * dx;
        y = lastY + alpha * dy;
    }

    lastX = x;
    lastY = y;

    CGPoint point = (CGPoint){
        .x = x < 0 ? 0 : x >= screenSize.width  ? screenSize.width  - 1 : x,
        .y = y < 0 ? 0 : y >= screenSize.height ? screenSize.height - 1 : y,
    };

    if (settings.useArg && settings.emitMouseEvent ||
        !settings.useArg && emitMouseEvent)
    {
        CGEventRef event = CGEventCreateMouseEvent(
            NULL,
            kCGEventMouseMoved,
            point,
            kCGMouseButtonLeft);
        CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);
        CGEventSetIntegerValueField(event, kCGMouseEventSubtype, 3);

        try(pthread_mutex_lock(&mouseEventNumber_mutex));
        CGEventSetIntegerValueField(event, kCGMouseEventNumber, mouseEventNumber);
        try(pthread_mutex_unlock(&mouseEventNumber_mutex));

        CGEventPost(kCGHIDEventTap, event);
    } else {
        CGWarpMouseCursorPosition(point);
    }
}

int trackpadCallback(
    MTDeviceRef device,
    MTTouch *data,
    size_t nFingers,
    double timestamp,
    size_t frame)
{
    #define GESTURE_PHASE_NONE 0
    #define GESTURE_PHASE_MAYSTART 1
    #define GESTURE_PHASE_BEGAN 2
    #define GESTURE_TIMEOUT 0.02

    static MTPoint fingerPosition = { 0, 0 },
                   oldFingerPosition = { 0, 0 };
    static int32_t oldPathIndex = -1;
    static double oldTimeStamp = 0,
                  startTrackTimeStamp = 0;
    static size_t oldFingerCount = 1;
    static int gesturePhase = GESTURE_PHASE_NONE;
    static bool gesturePaths[20] = { 0 };

    if (nFingers == 0) {
        for (int i = 0; i < 20; i++) {
            gesturePaths[i] = false;
        }
        gesturePhase = GESTURE_PHASE_NONE;
        oldFingerCount = nFingers;
        startTrackTimeStamp = 0;
        return 0;
    }

    if (!startTrackTimeStamp) {
        startTrackTimeStamp = timestamp;
    }

    if (oldFingerCount != 1 && nFingers == 1 && !gesturePhase) {
        gesturePhase = GESTURE_PHASE_MAYSTART;
        oldFingerCount = nFingers;
        return 0;
    };

    if (nFingers == 1 && timestamp - startTrackTimeStamp < GESTURE_TIMEOUT) {
        return 0;
    }

    if (nFingers != 1 && (
        timestamp - startTrackTimeStamp < GESTURE_TIMEOUT ||
        gesturePhase != GESTURE_PHASE_NONE))
    {
        gesturePhase = GESTURE_PHASE_BEGAN;
        for (int i = 0; i < nFingers; i++) {
            gesturePaths[data[i].pathIndex] = true;
        }
        if (!(DISABLE_CURSOR_ON_MULTITOUCH && nFingers > 1)) {
            moveCursor(fingerPosition.x, fingerPosition.y);
        }
        oldFingerCount = nFingers;
        return 0;
    };

    if (gesturePhase == GESTURE_PHASE_BEGAN) {
        for (int i = 0; i < nFingers; i++) {
            if (gesturePaths[data[i].pathIndex]) {
                if (!(DISABLE_CURSOR_ON_MULTITOUCH && nFingers > 1)) {
                    moveCursor(fingerPosition.x, fingerPosition.y);
                }
                return 0;
            }
        }
    }

    gesturePhase = GESTURE_PHASE_NONE;

    MTTouch *f = &data[0];
    for (int i = 0; i < nFingers; i++){
        if (data[i].pathIndex == oldPathIndex) {
            f = &data[i];
            break;
        }
    }

    oldFingerPosition = fingerPosition;
    fingerPosition = (settings.useArg ? _map : map)(
            f->normalizedVector.position.x, 1 - f->normalizedVector.position.y);
    MTPoint velocity = f->normalizedVector.velocity;

    if (fingerPosition.x < 0 || fingerPosition.y < 0) {
        if (f->pathIndex == oldPathIndex) {
            if (fingerPosition.x < 0) {
                fingerPosition.x = oldFingerPosition.x +
                    velocity.x * (timestamp - oldTimeStamp) * 1000;
            }
            if (fingerPosition.y < 0) {
                fingerPosition.y = oldFingerPosition.y -
                    velocity.y * (timestamp - oldTimeStamp) * 1000;
            }

        } else {
            fingerPosition = oldFingerPosition;
        }
    } else {
        oldPathIndex = f->pathIndex;
    }

    if (!(DISABLE_CURSOR_ON_MULTITOUCH && nFingers > 1)) {
        moveCursor(fingerPosition.x, fingerPosition.y);
    }

    oldTimeStamp = timestamp;
    return 0;
}

bool check_privileges(void) {
    bool result;
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *values[] = { kCFBooleanTrue };

    CFDictionaryRef options;
    options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys, values, sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);

    return result;
}

Range parseRange(char* s) {
    char* token[4 + 1];
    int i = 0;
    for (;(token[i] = strsep(&s, ",")) != NULL && i < 4; i++) { }
    if (i != 4 || token[4] != NULL) {
        fputs("Range format: lowx,lowy,upx,upy and numbers in range [0, 1]", stderr);
        exit(1);
    }
    float num[4];
    for (i = 0; i < 4; i++){
        char* endptr;
        num[i] = strtof(token[i], &endptr);
        if (*endptr) {
            fprintf(stderr, "Invalid number %s\n", token[i]);
            exit(1);
        }
    }
    return (Range) {
        num[0], num[1], num[2], num[3]
    };
}

void parseSettings(int argc, char** argv) {
    int opt;
    while ((opt = getopt(argc, argv, "i:o:ec")) != -1) {
        switch (opt) {
            case 'i':
                settings.trackpadRange = parseRange(optarg);
                settings.useArg = true;
                break;
            case 'o':
                settings.screenRange = parseRange(optarg);
                settings.useArg = true;
                break;
            case 'e':
                settings.emitMouseEvent = true;
                settings.useArg = true;
                break;
            case 'c':
                settings.requireCommandKey = true;
                settings.useArg = true;
                break;
            default:
                fprintf(stderr, "Usage: %s [-i lowx,lowy,upx,upy] [-o lowx,lowy,upx,upy] [-e] [-c]\n", argv[0]);
                exit(EXIT_FAILURE);
        }
    }
}

CGEventRef loggerCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void* context)
{
    int magic_number = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    if (magic_number == MAGIC_NUMBER) {
        return event;
    }
    int eventNumber = CGEventGetIntegerValueField(event, kCGMouseEventNumber);
    try(pthread_mutex_lock(&mouseEventNumber_mutex));
    mouseEventNumber = eventNumber;
    try(pthread_mutex_unlock(&mouseEventNumber_mutex));
    return event;
}

int main(int argc, char** argv) {
    parseSettings(argc, argv);
    screenSize = CGDisplayBounds(CGMainDisplayID()).size;

    try(pthread_mutex_init(&mouseEventNumber_mutex, NULL));

    CFArrayRef deviceList = MTDeviceCreateList();
    for (CFIndex i = 0; i < CFArrayGetCount(deviceList); i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(deviceList, i);
        int familyId;
        MTDeviceGetFamilyID(device, &familyId);
        if (
            familyId >= 98
            && familyId != 112 && familyId != 113
        ) {
            MTRegisterContactFrameCallback(device, (MTFrameCallbackFunction)trackpadCallback);
            MTDeviceStart(device, 0);
        }
    }

    CFRunLoopRun();
    return 0;
}
```

### Task 7: Copy remaining support files

**Files:**
- Create: `trackpad-absolute-osx/src/MultitouchSupport.h` (same as lokxii)
- Create: `trackpad-absolute-osx/settings.def.h` (update defaults)
- Create: `trackpad-absolute-osx/makefile` (same as lokxii)
- Create: `trackpad-absolute-osx/Info.plist` (same as lokxii)
- Create: `trackpad-absolute-osx/.gitignore` (same as lokxii)
- Create: `trackpad-absolute-osx/LICENSE.txt` (same as lokxii)
- Create: `trackpad-absolute-osx/README.md` (same as lokxii)

- [ ] **Write MultitouchSupport.h** — copy from lokxii unchanged.
- [ ] **Write settings.def.h** — update `emitMouseEvent` default to `true`.
- [ ] **Write makefile** — copy from lokxii unchanged (includes `settings.h` auto-copy from `settings.def.h`).
- [ ] **Write Info.plist** — copy from lokxii unchanged.
- [ ] **Write .gitignore** — copy from lokxii unchanged.
- [ ] **Write LICENSE.txt** — copy from lokxii unchanged.
- [ ] **Write README.md** — copy from lokxii unchanged.
- [ ] **Copy Resources/** — note: manually copy `.icns` files from lokxii.
