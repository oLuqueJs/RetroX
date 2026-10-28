import AppKit
import RetroXCore
import SwiftUI

/// Abertura do app: um gesto só. A Rayo aparece e o nome se revela a partir dela, na assinatura horizontal
/// do kit (a mesma da barra superior); depois tudo esmaece revelando a tela de perfis. Com Reduzir
/// Movimento, os dois só esmaecem.
struct SplashView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let wordSize: CGFloat = 40

    var body: some View {
        let shown = model.splash == .revealed
        let moves = Motion.allowsMovement(reduceMotion: reduceMotion)
        let metrics = Brand.Metrics(size: Self.wordSize)
        let f = Motion.settings.factor
        ZStack {
            Theme.background
                .ignoresSafeArea()
            HStack(alignment: .center, spacing: 0.75 * metrics.capHeight - metrics.leftBearing) {
                BrandMark(size: 2 * metrics.capHeight)
                    .scaleEffect(shown || !moves ? 1 : 0.9)
                    .opacity(shown ? 1 : 0)
                    .animation(moves ? .smooth(duration: 0.5 * f) : Motion.fade, value: shown)
                BrandWordmark(size: Self.wordSize)
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - metrics.capHeight / 2 }
                    .opacity(shown ? 1 : 0)
                    // O nome se escreve a partir do tile: a máscara abre da esquerda para a direita.
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: shown || !moves ? 1 : 0, anchor: .leading)
                    }
                    .animation((moves ? Animation.smooth(duration: 0.6 * f) : .easeOut(duration: 0.3)).delay(0.25 * f), value: shown)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RetroX")
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
