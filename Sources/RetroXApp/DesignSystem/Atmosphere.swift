import AppKit
import RetroXCore
import SwiftUI

/// Abertura do app: a Rayo surge com um anel se desenhando em volta, o nome entra letra a letra,
/// e tudo se dissolve revelando a tela de perfis.
struct SplashView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let word = Array("RetroX")

    var body: some View {
        let revealed = model.splash == .revealed
        let moves = Motion.allowsMovement(reduceMotion: reduceMotion)
        ZStack {
            Theme.background
                .ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: revealed ? 1 : 0.001)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 132, height: 132)
                        .animation(moves ? .easeInOut(duration: 0.9 * Motion.settings.factor) : nil, value: revealed)
                    BrandMark(size: 96)
                        .scaleEffect(revealed || !moves ? 1 : 0.6)
                        .rotationEffect(.degrees(revealed || !moves ? 0 : -12))
                        .opacity(revealed ? 1 : 0)
                        .animation(moves ? .spring(response: 0.6, dampingFraction: 0.68) : Motion.fade, value: revealed)
                }
                HStack(spacing: 0) {
                    ForEach(Array(Self.word.enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed || !moves ? 0 : 18)
                            .animation(
                                (moves ? Animation.smooth(duration: 0.5) : .easeOut(duration: 0.3)).delay(0.25 + Double(index) * 0.06),
                                value: revealed
                            )
                    }
                }
                Text("Seus jogos, num lugar só.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.7), value: revealed)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RetroX")
    }
}

/// O tile da Rayo; sem o recurso (build sem o bundle de recursos), cai no "R" provisório.
struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        if let mark = Brand.mark {
            Image(nsImage: mark)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: size * 0.08, y: size * 0.04)
        } else {
            RoundedRectangle.rx(size * 0.29)
                .fill(Theme.accent)
                .frame(width: size, height: size)
                .overlay {
                    Text("R")
                        .font(.system(size: size * 0.58, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                }
        }
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
