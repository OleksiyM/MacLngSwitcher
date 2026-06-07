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
    
    /// Получает список всех включенных в системе раскладок клавиатуры
    public func refreshAvailableLayouts() {
        var layouts: [KeyboardLayout] = []
        
        let filter = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource
        ] as CFDictionary
        
        guard let sourcesRef = TISCreateInputSourceList(filter, false) else { return }
        let sources = sourcesRef.takeRetainedValue() as! [TISInputSource]
        
        for source in sources {
            // Проверяем, можно ли выбрать эту раскладку (isSelectable)
            let isSelectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
            let isSelectable = isSelectablePtr.map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue } ?? false
            
            if !isSelectable { continue }
            
            // Получаем ID раскладки
            let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            guard let idRaw = idPtr else { continue }
            let id = Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String
            
            // Получаем локализованное имя
            let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            let name: String
            if let nameRaw = namePtr {
                name = Unmanaged<CFString>.fromOpaque(nameRaw).takeUnretainedValue() as String
            } else {
                name = id
            }
            
            // Исключаем методы ввода (например, японский/китайский Kotoeri, если они не являются обычными раскладками,
            // но обычно они тоже фильтруются по категории. Оставляем те, которые пользователь может выбрать напрямую)
            if !layouts.contains(where: { $0.id == id }) {
                layouts.append(KeyboardLayout(id: id, name: name))
            }
        }
        
        // Сортируем по имени для удобства
        self.availableLayouts = layouts.sorted(by: { $0.name < $1.name })
    }
    
    /// Возвращает ID текущей активной раскладки
    public func getCurrentLayoutID() -> String? {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID)
        guard let idRaw = idPtr else { return nil }
        return Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String
    }
    
    /// Переключает на раскладку с указанным ID
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
    
    /// Циклическое переключение между заданным массивом раскладок с автоматическим пропуском недоступных
    public func cycleLayouts(ids: [String]) {
        guard !ids.isEmpty else { return }
        
        guard let currentID = getCurrentLayoutID() else {
            // Пытаемся включить хотя бы одну раскладку из списка
            for id in ids {
                if selectLayout(id: id) { return }
            }
            return
        }
        
        if let currentIndex = ids.firstIndex(of: currentID) {
            // Начинаем перебор со следующего элемента по кругу
            for i in 1...ids.count {
                let nextIndex = (currentIndex + i) % ids.count
                // Если круг замкнулся и мы вернулись к текущему языку, выходим
                if nextIndex == currentIndex { break }
                
                if selectLayout(id: ids[nextIndex]) {
                    return // Успешно переключили!
                }
            }
        } else {
            // Текущий язык не в списке, пытаемся включить первую доступную раскладку
            for id in ids {
                if selectLayout(id: id) { return }
            }
        }
    }
}
