import Foundation
import Combine

@MainActor
class HeroSettings: ObservableObject {
    static let shared = HeroSettings()

    @Published var offsetX: Float = 0
    @Published var offsetY: Float = 0
    @Published var scale: Float = 1.0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadFromUserDefaults()
        bindPersistence()
    }

    private func loadFromUserDefaults() {
        let d = UserDefaults.standard
        offsetX = d.object(forKey: "hero_offset_x_adj") as? Float ?? 0
        offsetY = d.object(forKey: "hero_offset_y_adj") as? Float ?? 0
        scale = d.object(forKey: "hero_scale_adj") as? Float ?? 1.0
    }

    private func bindPersistence() {
        $offsetX.dropFirst().sink { UserDefaults.standard.set($0, forKey: "hero_offset_x_adj") }.store(in: &cancellables)
        $offsetY.dropFirst().sink { UserDefaults.standard.set($0, forKey: "hero_offset_y_adj") }.store(in: &cancellables)
        $scale.dropFirst().sink { UserDefaults.standard.set($0, forKey: "hero_scale_adj") }.store(in: &cancellables)
    }

    func reset() {
        offsetX = 0; offsetY = 0; scale = 1.0
    }
}
