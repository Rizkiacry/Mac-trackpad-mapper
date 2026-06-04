import SwiftUI

struct PreferenceUIView: View {
    @State private var useHeader: Bool = settings.useHeader
    @State private var trackpadRange: String = settings.trackpadRange?.toString() ?? "0.25,0.25,0.75,0.75"
    @State private var screenRange: String = settings.screenRange?.toString() ?? "0,0,1,1"
    @State private var emitMouseEvent: Bool = settings.emitMouseEvent
    @State private var requireCommandKey: Bool = settings.requireCommandKey
    @State private var disableGesture: Bool = settings.disableGesture

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
                Toggle("Disable gesture detection", isOn: $disableGesture)
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
        localSettings.disableGesture = disableGesture
        localSettings.useHeader = useHeader
        settings = localSettings

        if mainMenu.process != nil {
            mainMenu.stopProcess(nil)
            mainMenu.startProcess(nil)
        }
    }
}
