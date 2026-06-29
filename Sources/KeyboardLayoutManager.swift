import Foundation
import Carbon

public struct KeyboardLayout: Identifiable, Hashable, Codable {
    public var id: String // InputSource ID
    public var name: String // Localized name
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public class KeyboardLayoutManager: ObservableObject {
    public static let shared = KeyboardLayoutManager()
    
    @Published public var availableLayouts: [KeyboardLayout] = []
    
    private init() {
        refreshAvailableLayouts()
    }
    
    /// Retrieves a list of all enabled keyboard layouts in the system
    public func refreshAvailableLayouts() {
        var layouts: [KeyboardLayout] = []
        
        let filter = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource
        ] as CFDictionary
        
        guard let sourcesRef = TISCreateInputSourceList(filter, false) else { return }
        let sources = sourcesRef.takeRetainedValue() as! [TISInputSource]
        
        for source in sources {
            // Check if the layout can be selected (isSelectable)
            let isSelectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
            let isSelectable = isSelectablePtr.map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue } ?? false
            
            if !isSelectable { continue }
            
            // Get layout ID
            let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            guard let idRaw = idPtr else { continue }
            let id = Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String
            
            // Get localized name
            let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            let name: String
            if let nameRaw = namePtr {
                name = Unmanaged<CFString>.fromOpaque(nameRaw).takeUnretainedValue() as String
            } else {
                name = id
            }
            
            // Exclude input methods (like Japanese/Chinese Kotoeri) unless they are regular layouts.
            // Usually they are filtered by category. Keep only direct user-selectable layouts.
            if !layouts.contains(where: { $0.id == id }) {
                layouts.append(KeyboardLayout(id: id, name: name))
            }
        }
        
        // Sort by name for convenience
        self.availableLayouts = layouts.sorted(by: { $0.name < $1.name })
    }
    
    /// Returns the ID of the currently active keyboard layout
    public func getCurrentLayoutID() -> String? {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID)
        guard let idRaw = idPtr else { return nil }
        return Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String
    }
    
    /// Switches to the keyboard layout with the specified ID
    @discardableResult
    public func selectLayout(id: String) -> Bool {
        let filter = [
            kTISPropertyInputSourceID: id as CFString
        ] as CFDictionary
        
        guard let sourcesRef = TISCreateInputSourceList(filter, false) else { return false }
        let sources = sourcesRef.takeRetainedValue() as! [TISInputSource]
        
        guard let targetSource = sources.first else {
            return false
        }
        
        let result = TISSelectInputSource(targetSource)
        return result == noErr
    }
    
    /// Cycles through the specified array of layouts, automatically skipping unavailable ones
    public func cycleLayouts(ids: [String]) {
        guard !ids.isEmpty else { return }
        
        guard let currentID = getCurrentLayoutID() else {
            // Try to enable at least one layout from the list
            for id in ids {
                if selectLayout(id: id) { return }
            }
            return
        }
        
        if let currentIndex = ids.firstIndex(of: currentID) {
            // Start cycling from the next layout in the list
            for i in 1...ids.count {
                let nextIndex = (currentIndex + i) % ids.count
                // If we cycled back to the current layout, exit
                if nextIndex == currentIndex { break }
                
                if selectLayout(id: ids[nextIndex]) {
                    return // Successfully switched!
                }
            }
        } else {
            // Current layout not in list, try to enable the first available layout
            for id in ids {
                if selectLayout(id: id) { return }
            }
        }
    }
}
