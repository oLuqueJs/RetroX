import RetroXCore
import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage("accent") private var accent = Palette.Accent.coral

    var body: some View {
        Form {
            Picker("Aparência", selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Cor do tema") {
                HStack(spacing: Spacing.m) {
                    ForEach(Palette.Accent.allCases, id: \.self) { option in
                        Button {
                            accent = option
                        } label: {
                            Circle()
                                .fill(Color(option.fill))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Theme.textPrimary, lineWidth: 2)
                                        .padding(-5)
                                        .opacity(option == accent ? 1 : 0)
                                }
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(option.title)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(option == accent ? .isSelected : [])
                    }
                }
            }

            Section {
                Text("O RetroX segue os ajustes de Reduzir Movimento, Reduzir Transparência e Aumentar Contraste do macOS.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .preferredColorScheme(appearance.colorScheme)
        .tint(Color(accent.fill))
    }
}
