import Cocoa
import SwiftUI

struct PreferenceUIView: View {
    @State private var trackpadRange: String = "0.275,0.3,0.725,0.7"
    @State private var screenRange: String = "0,0,1,1"
    @State private var emitMouseEvent: Bool = true
    @State private var requireCommandKey: Bool = false
    @State private var centerCursorOnRelease: Bool = false

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

    private enum Field: Int, CaseIterable {
        case trackpadRange, screenRange, emitMouseEvent, requireCommandKey, centerCursorOnRelease, apply
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Form {
                    HStack {
                        Text("Trackpad region:")
                        TextField("", text: $trackpadRange)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .trackpadRange)
                    }
                    HStack {
                        Text("Screen region:")
                        TextField("", text: $screenRange)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .screenRange)
                    }
                }
                Toggle("Emit mouse events", isOn: $emitMouseEvent)
                    .toggleStyle(.checkbox)
                    .focusable()
                    .focused($focusedField, equals: .emitMouseEvent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusedField == .emitMouseEvent ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Toggle("Activate only while ⌘ pressed", isOn: $requireCommandKey)
                    .toggleStyle(.checkbox)
                    .focusable()
                    .focused($focusedField, equals: .requireCommandKey)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusedField == .requireCommandKey ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Toggle("Center cursor on release", isOn: $centerCursorOnRelease)
                    .toggleStyle(.checkbox)
                    .focusable()
                    .focused($focusedField, equals: .centerCursorOnRelease)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusedField == .centerCursorOnRelease ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
            .focusSection()

            HStack {
                Spacer()
                Button(action: {
                    if isValid {
                        localSettings.trackpadRange = Settings.Range(from: trackpadRange)
                        localSettings.screenRange = Settings.Range(from: screenRange)
                    }
                    localSettings.emitMouseEvent = emitMouseEvent
                    localSettings.requireCommandKey = requireCommandKey
                    localSettings.centerCursorOnRelease = centerCursorOnRelease

                    settings = localSettings

                    if mainMenu.process != nil {
                        mainMenu.stopProcess(nil)
                        mainMenu.startProcess(nil)
                    }
                }) {
                    Text("Apply").padding()
                }
                .buttonStyle(.borderedProminent)
                .focusable()
                .focused($focusedField, equals: .apply)
                Spacer()
            }
        }
        .padding()
        .onAppear {
            trackpadRange = settings.trackpadRange?.toString() ?? "0.275,0.3,0.725,0.7"
            screenRange = settings.screenRange?.toString() ?? "0,0,1,1"
            emitMouseEvent = settings.emitMouseEvent
            requireCommandKey = settings.requireCommandKey
            centerCursorOnRelease = settings.centerCursorOnRelease
            focusedField = .trackpadRange
        }
        .onKeyPress { press in
            if press.characters == "\u{0009}" {
                if press.modifiers.contains(.shift) {
                    focusedField = focusedField.map {
                        Field(rawValue: ($0.rawValue - 1 + Field.allCases.count) % Field.allCases.count) ?? .trackpadRange
                    }
                } else {
                    focusedField = focusedField.map {
                        Field(rawValue: ($0.rawValue + 1) % Field.allCases.count) ?? .trackpadRange
                    }
                }
                return .handled
            }

            if press.key == .upArrow {
                focusedField = focusedField.map {
                    Field(rawValue: ($0.rawValue - 1 + Field.allCases.count) % Field.allCases.count) ?? .trackpadRange
                }
                return .handled
            }

            if press.key == .downArrow {
                focusedField = focusedField.map {
                    Field(rawValue: ($0.rawValue + 1) % Field.allCases.count) ?? .trackpadRange
                }
                return .handled
            }

            if press.key == .return || press.key == .space {
                switch focusedField {
                case .emitMouseEvent:
                    emitMouseEvent.toggle()
                    return .handled
                case .requireCommandKey:
                    requireCommandKey.toggle()
                    return .handled
                case .centerCursorOnRelease:
                    centerCursorOnRelease.toggle()
                    return .handled
                case .apply:
                    if isValid {
                        localSettings.trackpadRange = Settings.Range(from: trackpadRange)
                        localSettings.screenRange = Settings.Range(from: screenRange)
                    }
                    localSettings.emitMouseEvent = emitMouseEvent
                    localSettings.requireCommandKey = requireCommandKey
                    localSettings.centerCursorOnRelease = centerCursorOnRelease

                    settings = localSettings

                    if mainMenu.process != nil {
                        mainMenu.stopProcess(nil)
                        mainMenu.startProcess(nil)
                    }
                    return .handled
                default:
                    return .ignored
                }
            }

            return .ignored
        }
        
    }
}