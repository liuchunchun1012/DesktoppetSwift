import Foundation

enum SpriteResourceLocator {
    static func spritesRootPath() -> String? {
        let fileManager = FileManager.default
        var candidates: [String] = []
        
        if UserSettings.shared.useCustomSprites {
            let customPath = UserSettings.shared.customSpritesPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customPath.isEmpty {
                candidates.append(customPath)
            }
        }
        
        if let resourcePath = Bundle.main.resourcePath {
            candidates.append(resourcePath + "/sprites_aligned")
        }
        
        #if SWIFT_PACKAGE
        if let packageResourcePath = Bundle.module.resourcePath {
            candidates.append(packageResourcePath + "/Resources")
            candidates.append(packageResourcePath + "/sprites_aligned")
            candidates.append(packageResourcePath)
        }
        #endif
        
        candidates.append(fileManager.currentDirectoryPath + "/Sources/Meowpal/Resources")
        
        return candidates.first { path in
            fileManager.fileExists(atPath: path + "/idle/grooming 1-12/frame_01.png")
        }
    }
    
    static func catIconPath() -> String? {
        spritesRootPath().map { "\($0)/idle/grooming 1-12/frame_02.png" }
    }
}
