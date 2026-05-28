import AppKit

final class IconCatalog {
    static let shared = IconCatalog()
    
    private let cacheLock = NSLock()
    private var cache: [String: NSImage] = [:]
    private let bundle = Bundle.main
    
    private init() {}
    
    func image(named name: String, resizedTo size: NSSize? = nil, template: Bool = false) -> NSImage? {
        let key = cacheKey(name: name, size: size, template: template)
        
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached.copy() as? NSImage
        }
        cacheLock.unlock()
        
        guard let resourcePath = bundle.resourcePath else { return nil }
        let iconPath = (resourcePath as NSString).appendingPathComponent(name)
        guard let baseImage = NSImage(contentsOfFile: iconPath) else { return nil }
        
        let image = baseImage.copy() as? NSImage ?? baseImage
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
