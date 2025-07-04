import Cocoa
import SwiftUI

struct PreferenceUIView: View {
    @State private var trackpadRange: String = "0.275,0.3,0.725,0.7"
    @State private var screenRange: String = "0,0,1,1"
    @State private var emitMouseEvent: Bool = true
    @State private var requireCommandKey: Bool = false

    var mainMenu: MainMenu
    @State private var localSettings = settings

    var isValid: Bool {
        return Settings.Range.stringIsValid(
            string: trackpadRange,
            name: "Trackpad region")
            && Settings.Range.stringIsValid(
                string: screenRange,
                name: "Screen region")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                HStack {
                    Text("Trackpad region:")
                    TextField("", text: $trackpadRange)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Text("Screen region:")
                    TextField("", text: $screenRange)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            Toggle("Emit mouse events", isOn: $emitMouseEvent)
                .toggleStyle(.checkbox)
            Toggle("Activate only while ⌘ pressed", isOn: $requireCommandKey)
                .toggleStyle(.checkbox)
        }
        .padding()
        Button(action: {
            if isValid {
                localSettings.trackpadRange = Settings.Range(from: trackpadRange)
                localSettings.screenRange = Settings.Range(from: screenRange)
            }
            localSettings.emitMouseEvent = emitMouseEvent
            localSettings.requireCommandKey = requireCommandKey

            settings = localSettings

            if mainMenu.process != nil {
                mainMenu.stopProcess(nil)
                mainMenu.startProcess(nil)
            }
        }) {
            Text("Apply").padding()
        }
    }
}
