import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showToken = false
    @State private var showPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                serverCard
                authCard
                topicsCard
                behaviorCard
                HStack {
                    Button("Kaiserlich preset") {
                        store.applyKaiserlichPreset()
                    }
                    Spacer()
                    Button("Send test") {
                        Task { await store.sendTest() }
                    }
                    Button("Save & reconnect") {
                        store.save()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .font(.system(size: 13, weight: .medium))
            }
            .padding(22)
        }
        .frame(width: 480, height: 620)
        .background(Palette.bg)
        .foregroundStyle(Palette.text)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NTFY BAR")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Palette.amber)
            Text("Subscribe to any ntfy server and bounce messages into the menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
        }
    }

    private var serverCard: some View {
        card("Server") {
            labeled("Base URL") {
                TextField("https://ntfy.sh", text: $store.serverURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(Palette.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var authCard: some View {
        card("Login") {
            labeled("Username") {
                TextField("admin", text: $store.username)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(Palette.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            labeled("Password") {
                HStack {
                    Group {
                        if showPassword {
                            TextField("password", text: $store.password)
                        } else {
                            SecureField("password", text: $store.password)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                .padding(8)
                .background(Palette.bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if !store.authProbe.isEmpty {
                Text(store.authProbe)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(store.authProbe == "Signed in" ? Palette.live : Palette.danger)
            }
            DisclosureGroup("Access token (optional)") {
                HStack {
                    Group {
                        if showToken {
                            TextField("tk_…", text: $store.token)
                        } else {
                            SecureField("tk_…", text: $store.token)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    Button(showToken ? "Hide" : "Show") { showToken.toggle() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                .padding(8)
                .background(Palette.bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Leave empty. Username and password are enough.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.muted)
        }
    }

    private var topicsCard: some View {
        card("Topics") {
            Text("One topic per line.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
            TextEditor(text: $store.topicsText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(8)
                .background(Palette.bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Palette.text)
        }
    }

    private var behaviorCard: some View {
        card("Behavior") {
            Stepper("Banner from priority \(store.minPriority)+", value: $store.minPriority, in: 1...5)
            Toggle("Notification sound", isOn: $store.soundEnabled)
            Toggle("Mute banners", isOn: $store.muted)
            Toggle("Launch at login", isOn: $store.launchAtLogin)
        }
        .toggleStyle(.switch)
        .font(.system(size: 13))
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Palette.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Palette.line, lineWidth: 1)
        )
    }

    private func labeled(_ title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
            field()
        }
    }
}
