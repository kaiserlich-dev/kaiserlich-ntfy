import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Server", text: $store.serverURL, prompt: Text("https://ntfy.sh"))
                }

                Section {
                    TextField("Username", text: $store.username, prompt: Text("admin"))
                    SecureField("Password", text: $store.password)
                    SecureField("Access token", text: $store.token, prompt: Text("Optional"))
                } header: {
                    Text("Login")
                } footer: {
                    if !store.authProbe.isEmpty {
                        Label(store.authProbe, systemImage: store.authProbe == "Signed in" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(store.authProbe == "Signed in" ? Palette.live : Palette.danger)
                    }
                }

                Section {
                    TextEditor(text: $store.topicsText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 120)
                } header: {
                    Text("Topics")
                } footer: {
                    HStack {
                        Text("One per line.")
                        Spacer()
                        Button("Kaiserlich preset") { store.applyKaiserlichPreset() }
                            .buttonStyle(.link)
                    }
                }

                Section("Notifications") {
                    Picker("Show banners from", selection: $store.minPriority) {
                        Text("All priorities").tag(1)
                        Text("Low and above").tag(2)
                        Text("Default and above").tag(3)
                        Text("High and above").tag(4)
                        Text("Urgent only").tag(5)
                    }
                    Toggle("Play sound", isOn: $store.soundEnabled)
                    Toggle("Mute banners", isOn: $store.muted)
                }

                Section {
                    Toggle("Launch at login", isOn: $store.launchAtLogin)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    Button("Check for Updates…") { AppDelegate.shared?.checkForUpdates() }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Send Test") {
                    Task { await store.sendTest() }
                }
                Spacer()
                Button("Save & Reconnect") { store.save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 620)
    }
}
