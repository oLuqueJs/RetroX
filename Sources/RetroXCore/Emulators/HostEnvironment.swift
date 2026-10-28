import Foundation

/// O que o Mac atual consegue executar. Valor simples para os testes simularem outros hosts.
public struct HostEnvironment: Sendable, Equatable {
    public enum Compatibility: Sendable, Equatable {
        case native
        case rosetta
        /// O executável não é Mach-O reconhecível (por exemplo, um script); não há como checar.
        case unknown
        case incompatible(rosettaMissing: Bool)
    }

    /// Arquitetura do hardware (arm64 mesmo se o RetroX estiver rodando via Rosetta).
    public var architecture: CPUArchitecture
    public var isRosettaInstalled: Bool

    public init(architecture: CPUArchitecture, isRosettaInstalled: Bool) {
        self.architecture = architecture
        self.isRosettaInstalled = isRosettaInstalled
    }

    /// A presença do runtime do Rosetta é uma heurística: não há API pública para isso.
    static let rosettaRuntimeURL = URL(filePath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")

    public static func current(fileSystem: any FileSystemProbing = LocalFileSystem()) -> HostEnvironment {
        var isAppleSilicon: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let hasARM64 = sysctlbyname("hw.optional.arm64", &isAppleSilicon, &size, nil, 0) == 0 && isAppleSilicon == 1
        return HostEnvironment(
            architecture: hasARM64 ? .arm64 : .x86_64,
            isRosettaInstalled: fileSystem.kind(of: rosettaRuntimeURL) == .regularFile
        )
    }

    public func compatibility(with architectures: Set<CPUArchitecture>) -> Compatibility {
        if architectures.isEmpty { return .unknown }
        if architectures.contains(architecture) { return .native }
        if architecture == .arm64, architectures.contains(.x86_64) {
            return isRosettaInstalled ? .rosetta : .incompatible(rosettaMissing: true)
        }
        return .incompatible(rosettaMissing: false)
    }
}
