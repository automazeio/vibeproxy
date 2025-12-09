import AppKit

final class IconCatalog {
    static let shared = IconCatalog()
    
    private let cacheLock = NSLock()
    private var cache: [String: NSImage] = [:]
    private let bundles: [Bundle] = [Bundle.main, Bundle.module]
    
    private init() {}
    
    func image(named name: String, resizedTo size: NSSize? = nil, template: Bool = false) -> NSImage? {
        let key = cacheKey(name: name, size: size, template: template)
        
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached.copy() as? NSImage
        }
        cacheLock.unlock()
        
        let baseImage: NSImage? = {
            for bundle in bundles {
                if let resourcePath = bundle.resourcePath {
                    let iconPath = (resourcePath as NSString).appendingPathComponent(name)
                    if let image = NSImage(contentsOfFile: iconPath) {
                        return image
                    }
                }
            }
            return nil
        }()
        guard let resolvedImage = baseImage else { return nil }
        
        let image = resolvedImage.copy() as? NSImage ?? resolvedImage
        if let size = size {
            image.size = size
        }
        image.isTemplate = template
        
        cacheLock.lock()
        cache[key] = image
        cacheLock.unlock()
        
        return image.copy() as? NSImage ?? image
    }
    
    private func cacheKey(name: String, size: NSSize?, template: Bool) -> String {
        if let size = size {
            return "\(name)-\(Int(size.width))x\(Int(size.height))-\(template)"
        }
        return "\(name)-original-\(template)"
    }
}
