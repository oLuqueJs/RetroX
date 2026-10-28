import AppKit
import RetroXCore
import SwiftUI

/// Abertura do app, em três tempos: a Rayo sobe do desfoque sobre um halo na cor de tema e um brilho
/// atravessa o tile; "Retro" assenta logo abaixo e o "X" gira até o lugar; o conjunto se dissolve
/// (com um leve zoom) revelando a tela de perfis. Com Reduzir Movimento, só esmaece.
/// Composição empilhada do kit: tile = 3 × altura das maiúsculas, vão até as maiúsculas = 1 × a altura.
struct SplashView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let wordSize: CGFloat = 44

    var body: some View {
        let shown = model.splash == .revealed
        let moves = Motion.allowsMovement(reduceMotion: reduceMotion)
        let metrics = Brand.Metrics(size: Self.wordSize)
        let tile = 3 * metrics.capHeight
        let f = Motion.settings.factor
        ZStack {
            Theme.background
                .ignoresSafeArea()
            VStack(spacing: metrics.capHeight - metrics.aboveCaps) {
                BrandMark(size: tile)
                    .overlay { shine(tile: tile, shown: shown && moves, factor: f) }
                    .scaleEffect(shown || !moves ? 1 : 0.84)
                    .offset(y: shown || !moves ? 0 : 16)
                    .blur(radius: shown || !moves ? 0 : 12)
                    .opacity(shown ? 1 : 0)
                    .animation(moves ? .spring(response: 0.7 * f, dampingFraction: 0.8) : Motion.fade, value: shown)
                    // No fundo, e não numa ZStack: o halo é maior que o tile e não pode afastar o nome.
                    .background { halo(tile: tile, shown: shown, moves: moves, factor: f) }
                HStack(spacing: 0) {
                    Text("Retro")
                        .foregroundStyle(Theme.textPrimary)
                        .offset(y: shown || !moves ? 0 : 10)
                        .blur(radius: shown || !moves ? 0 : 6)
                        .opacity(shown ? 1 : 0)
                        .animation((moves ? Animation.smooth(duration: 0.6 * f) : .easeOut(duration: 0.3)).delay(0.28 * f), value: shown)
                    Text("X")
                        .foregroundStyle(Theme.accent)
                        .padding(.leading, Brand.oxKern * Self.wordSize)
                        .scaleEffect(shown || !moves ? 1 : 0.3)
                        .rotationEffect(.degrees(shown || !moves ? 0 : -135))
                        .opacity(shown ? 1 : 0)
                        .animation((moves ? Animation.spring(response: 0.55 * f, dampingFraction: 0.62) : .easeOut(duration: 0.3)).delay(0.5 * f), value: shown)
                }
                .font(Brand.font(Self.wordSize))
                .kerning(-0.015 * Self.wordSize)
                Text("Seus jogos, num lugar só.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Spacing.xs)
                    .offset(y: shown || !moves ? 0 : 6)
                    .opacity(shown ? 1 : 0)
                    .animation(.easeOut(duration: 0.5 * f).delay(0.8 * f), value: shown)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RetroX")
    }

    /// Brilho difuso na cor de tema, que abre atrás do tile.
    private func halo(tile: CGFloat, shown: Bool, moves: Bool, factor: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0)], center: .center,
                                 startRadius: tile * 0.3, endRadius: tile * 1.5))
            .frame(width: tile * 3, height: tile * 3)
            .scaleEffect(shown || !moves ? 1 : 0.35)
            .opacity(shown ? 1 : 0)
            .animation(.smooth(duration: 1.1 * factor).delay(0.05 * factor), value: shown)
            .allowsHitTesting(false)
    }

    /// Faixa de luz que atravessa o tile na diagonal, uma vez.
    private func shine(tile: CGFloat, shown: Bool, factor: Double) -> some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(width: tile * 0.35, height: tile * 1.8)
            .rotationEffect(.degrees(22))
            .offset(x: shown ? tile * 1.1 : -tile * 1.1)
            .animation(shown ? .easeInOut(duration: 0.85 * factor).delay(0.5 * factor) : nil, value: shown)
            .blendMode(.plusLighter)
            .frame(width: tile, height: tile)
            .clipShape(RoundedRectangle(cornerRadius: tile * Brand.tileRadius, style: .continuous))
            .allowsHitTesting(false)
    }
}

/// Saída da abertura: esmaece com um leve zoom e desfoque (só esmaece com Reduzir Movimento).
private struct SplashExit: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let moves = Motion.allowsMovement(reduceMotion: reduceMotion)
        content
            .scaleEffect(active && moves ? 1.06 : 1)
            .blur(radius: active && moves ? 14 : 0)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    static var splashExit: AnyTransition {
        .asymmetric(insertion: .identity, removal: .modifier(active: SplashExit(active: true), identity: SplashExit(active: false)))
    }
}

/// Fundo ambiente: a capa do jogo em foco, bem desfocada, atrás da tela. Troca devagar.
/// Ocupa exatamente o tamanho da janela (a imagem fica num overlay de um `Color.clear`, para não esticar o
/// layout). Some com Reduzir Transparência ou se o perfil desligar.
struct AmbientBackdrop: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .overlay {
                if !reduceTransparency, model.preferences.ambientBackground, let game = model.ambientGame {
                    Group {
                        if let image = model.covers.ambientImage(for: game.coverURL) {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.medium)
                                .scaledToFill()
                                .blur(radius: 24)
                        } else {
                            Theme.coverTone(game.systemID)
                        }
                    }
                    .opacity(colorScheme == .dark ? 0.45 : 0.32)
                    .id(game.coverURL?.absoluteString ?? game.id)
                    .transition(.opacity)
                    .task(id: game.coverURL) {
                        if let url = game.coverURL { await model.covers.loadAmbient(url) }
                    }
                }
            }
            .overlay {
                // Mantém o texto legível sobre qualquer capa.
                LinearGradient(
                    colors: [Theme.background.opacity(0.5), Theme.background.opacity(0.82), Theme.background],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .clipped()
            .ignoresSafeArea()
            .animation(Motion.ambient, value: model.ambientGame?.id)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Fundo escurecido atrás de um cartão (detalhes, edição de perfil); clicar fora fecha.
struct ModalDim: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.black.opacity(0.42)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Aparência de cartão flutuante.
    func modalCard() -> some View {
        clipShape(RoundedRectangle.rx(Radius.xl))
            .overlay(RoundedRectangle.rx(Radius.xl).strokeBorder(Theme.divider, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
    }
}

extension AnyTransition {
    /// O cartão cresce de leve e sobe enquanto aparece.
    static var modalCard: AnyTransition {
        .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 16))
    }

    /// Troca entre abas: o conteúdo novo entra pelo lado da aba escolhida.
    static func screen(direction: Int) -> AnyTransition {
        .asymmetric(
            insertion: .offset(x: CGFloat(direction) * 48).combined(with: .opacity),
            removal: .offset(x: CGFloat(-direction) * 48).combined(with: .opacity)
        )
    }

    /// Entrar no perfil: a tela inicial aproxima.
    static var zoom: AnyTransition {
        .asymmetric(insertion: .scale(scale: 1.04).combined(with: .opacity), removal: .scale(scale: 0.96).combined(with: .opacity))
    }
}
