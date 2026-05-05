import UIKit

class HeroImageCache: @unchecked Sendable {
    static let shared = HeroImageCache()

    private let heroImageURLBase = "https://game.gtimg.cn/images/yxzj/img201606/heroimg/"
    private var cache: [String: UIImage] = [:]
    private var loadingSet: Set<String> = []
    private let maxConcurrentLoads = 5
    private let maxCacheSize = 30
    private let cacheQueue = DispatchQueue(label: "com.dangdangshare.heroimage.cache", attributes: .concurrent)

    private init() {}

    func getImage(_ heroId: String) -> UIImage? {
        return cacheQueue.sync { cache[heroId] }
    }

    func requestImage(_ heroId: String, onLoaded: @escaping @Sendable () -> Void) {
        let shouldLoad = cacheQueue.sync(flags: .barrier) { () -> Bool in
            if cache[heroId] != nil { return false }
            if loadingSet.contains(heroId) { return false }
            if loadingSet.count >= self.maxConcurrentLoads { return false }
            loadingSet.insert(heroId)
            return true
        }
        guard shouldLoad else { return }

        Task { [weak self] in
            guard let self = self else { return }
            defer {
                _ = self.cacheQueue.sync(flags: .barrier) { self.loadingSet.remove(heroId) }
            }

            guard let url = URL(string: "\(self.heroImageURLBase)\(heroId)/\(heroId).jpg") else { return }

            let session = URLSession.shared
            guard let data = try? await session.data(from: url).0,
                  let image = UIImage(data: data) else { return }

            let targetSize = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let scaled = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            self.cacheQueue.sync(flags: .barrier) {
                if self.cache.count >= self.maxCacheSize {
                    if let firstKey = self.cache.keys.first {
                        self.cache.removeValue(forKey: firstKey)
                    }
                }
                self.cache[heroId] = scaled
            }

            onLoaded()
        }
    }

    func preloadImages(heroIds: [String], onLoaded: @escaping @Sendable () -> Void = {}) {
        for id in heroIds {
            requestImage(id, onLoaded: onLoaded)
        }
    }

    func clearCache() {
        cacheQueue.sync(flags: .barrier) {
            cache.removeAll()
            loadingSet.removeAll()
        }
    }
}
