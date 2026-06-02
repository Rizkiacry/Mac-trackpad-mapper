# Trackpad Mapper Enhancements

## Source: lokxii Mac-trackpad-mapper → trackpad-absolute-osx

### Changes

1. **Auto-start tracking** — `main.swift` calls `menu.startProcess(nil)` after menu init. Activation policy `.accessory`.
2. **Trackpad region default** `0.25,0.25,0.75,0.75` — `Settings.swift` default, `PreferenceUIView.swift` initial text.
3. **Emit mouse event default ON** — `Settings.swift` default `true`, `settings.def.h` default `true`.
4. **Keyboard navigation** — `@FocusState` + `.focused()` on TextFields, `.onSubmit` for Tab flow, `.keyboardShortcut(.defaultAction)` on Apply.
5. **Fix preferences** — `@State private var localSettings = settings` pattern (from kotkota). `openPreference()` centers window, activates, sets `.floating`. `PreferenceViewController` sets min frame size.
6. **requireCommandKey toggle** — added to Settings, PreferenceUIView, `trackpad_mapper_util.c` (`-c` flag). Default `false`.
7. **Keep jitter/smoothing** from lokxii `trackpad_mapper_util.c` and `settings.def.h`.

### Files

| File | Action |
|---|---|
| `src/main.swift` | Write (modified) |
| `src/Settings.swift` | Write (modified) |
| `src/MainMenu.swift` | Write (modified) |
| `src/PreferenceUIView.swift` | Write (modified) |
| `src/PreferenceViewController.swift` | Write (modified) |
| `src/trackpad_mapper_util.c` | Write (modified) |
| `src/MultitouchSupport.h` | Write (copy) |
| `settings.def.h` | Write (modified) |
| `makefile` | Write (copy) |
| `Info.plist` | Write (copy) |
| `.gitignore` | Write (copy) |
| `LICENSE.txt` | Write (copy) |
| `README.md` | Write (copy) |
| `Resources/` | Note: copy icns from lokxii |
