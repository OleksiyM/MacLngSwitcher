import Foundation
import Cocoa
import ApplicationServices

public class EventTapManager: ObservableObject {
    public static let shared = EventTapManager()
    
    @Published public var hasAccessibilityAccess: Bool = false
    @Published public var isEnabled: Bool = true
    
    // Настройки пользователя (с автосохранением в UserDefaults)
    @Published public var leftControlLayoutID: String {
        didSet {
            UserDefaults.standard.set(leftControlLayoutID, forKey: "leftControlLayoutID")
        }
    }
    
    @Published public var rightControlLayoutIDs: [String] {
        didSet {
            UserDefaults.standard.set(rightControlLayoutIDs, forKey: "rightControlLayoutIDs")
        }
    }
    
    @Published public var clickTimeout: Double {
        didSet {
            UserDefaults.standard.set(clickTimeout, forKey: "clickTimeout")
        }
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Состояние нажатия клавиш
    private struct ModifierState {
        var isPressed: Bool = false
        var pressTime: Date = Date()
        var hasOtherKeys: Bool = false
    }
    
    private var leftControlState = ModifierState()
    private var rightControlState = ModifierState()
    
    private init() {
        // Убедимся, что раскладки отсканированы
        KeyboardLayoutManager.shared.refreshAvailableLayouts()
        let layouts = KeyboardLayoutManager.shared.availableLayouts
        
        // 1. Сначала определяем значения локально, не используя self
        let chosenLeftID: String
        if let savedLeft = UserDefaults.standard.string(forKey: "leftControlLayoutID") {
            chosenLeftID = savedLeft
        } else {
            // Ищем подходящий английский (ABC, US, English)
            let defaultLeft = layouts.first(where: { $0.id.contains("ABC") })?.id ??
                              layouts.first(where: { $0.id.contains("US") })?.id ??
                              layouts.first(where: { $0.name.lowercased().contains("english") || $0.name.lowercased().contains("u.s.") })?.id ??
                              "com.apple.keylayout.US"
            chosenLeftID = defaultLeft
            UserDefaults.standard.set(defaultLeft, forKey: "leftControlLayoutID")
        }
        
        let chosenRightIDs: [String]
        if let savedRight = UserDefaults.standard.stringArray(forKey: "rightControlLayoutIDs") {
            chosenRightIDs = savedRight
        } else {
            var selected: [String] = []
            // Ищем русский
            if let ru = layouts.first(where: { $0.id.lowercased().contains("russian") || $0.name.lowercased().contains("рус") }) {
                selected.append(ru.id)
            }
            // Ищем украинский
            if let ua = layouts.first(where: { $0.id.lowercased().contains("ukrainian") || $0.name.lowercased().contains("укр") }) {
                selected.append(ua.id)
            }
            
            // Если ничего не нашли, берем все раскладки, отличные от левой
            if selected.isEmpty {
                selected = layouts.filter({ $0.id != chosenLeftID }).map({ $0.id })
            }
            // Если все равно пусто, ставим заглушку
            if selected.isEmpty {
                selected = ["com.apple.keylayout.Russian"]
            }
            chosenRightIDs = selected
            UserDefaults.standard.set(selected, forKey: "rightControlLayoutIDs")
        }
        
        let savedTimeout = UserDefaults.standard.double(forKey: "clickTimeout")
        let chosenTimeout = savedTimeout > 0 ? savedTimeout : 0.35
        
        // 2. Инициализируем свойства класса
        self.leftControlLayoutID = chosenLeftID
        self.rightControlLayoutIDs = chosenRightIDs
        self.clickTimeout = chosenTimeout
        
        // 3. Вызываем методы экземпляра класса
        checkAccessibility(prompt: false)
        if hasAccessibilityAccess {
            startEventTap()
        }
    }
    
    /// Проверка прав Accessibility
    public func checkAccessibility(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let access = AXIsProcessTrustedWithOptions(options)
        self.hasAccessibilityAccess = access
        
        if access && eventTap == nil {
            startEventTap()
        }
    }
    
    /// Запуск перехвата событий
    public func startEventTap() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)
        
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(type: type, event: event)
            },
            userInfo: selfPointer
        )
        
        guard let tap = eventTap else {
            DebugLogger.log("[EventTap] Не удалось создать CGEventTap. Возможно, нет прав доступности.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            DebugLogger.log("[EventTap] Успешно запущен.")
        }
    }
    
    /// Остановка перехвата
    public func stopEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        DebugLogger.log("[EventTap] Остановлен.")
    }
    
    /// Перезапуск перехвата
    public func restartEventTap() {
        stopEventTap()
        startEventTap()
    }
    
    /// Основной обработчик событий
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else { return Unmanaged.passUnretained(event) }
        
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        DebugLogger.log("[EventTap] handleEvent: type=\(type.rawValue), keycode=\(keycode)")
        
        // Если это обычное нажатие/отпускание клавиши, ставим флаг "другие клавиши" для зажатых модификаторов
        if type == .keyDown || type == .keyUp {
            if leftControlState.isPressed {
                leftControlState.hasOtherKeys = true
            }
            if rightControlState.isPressed {
                rightControlState.hasOtherKeys = true
            }
            return Unmanaged.passUnretained(event)
        }
        
        if type == .flagsChanged {
            // Преобразуем CGEvent в NSEvent для надежного считывания device-dependent флагов
            guard let nsEvent = NSEvent(cgEvent: event) else {
                return Unmanaged.passUnretained(event)
            }
            
            let rawFlags = nsEvent.modifierFlags.rawValue
            
            // Маски для левого и правого Control (device-dependent)
            let leftCtrlFlag: UInt = 0x00000001
            let rightCtrlFlag: UInt = 0x00002000
            
            let isLeftNowPressed = (rawFlags & leftCtrlFlag) != 0
            let isRightNowPressed = (rawFlags & rightCtrlFlag) != 0
            
            DebugLogger.log("[EventTap] flagsChanged: keycode=\(keycode), leftPressed=\(isLeftNowPressed), rightPressed=\(isRightNowPressed), rawFlags=\(rawFlags)")
            
            // Если нажат левый Control, но изменился другой модификатор (например, Shift)
            if leftControlState.isPressed && keycode != 59 {
                leftControlState.hasOtherKeys = true
            }
            // Если нажат правый Control, но изменился другой модификатор
            if rightControlState.isPressed && keycode != 62 {
                rightControlState.hasOtherKeys = true
            }
            
            // 1. Обработка Левого Control (keycode 59)
            if keycode == 59 {
                if isLeftNowPressed && !leftControlState.isPressed {
                    // Клавиша зажата
                    leftControlState.isPressed = true
                    leftControlState.pressTime = Date()
                    leftControlState.hasOtherKeys = false
                    DebugLogger.log("[EventTap] Нажат левый Control")
                } else if !isLeftNowPressed && leftControlState.isPressed {
                    // Клавиша отпущена
                    let duration = Date().timeIntervalSince(leftControlState.pressTime)
                    DebugLogger.log("[EventTap] Отпущен левый Control, удержание: \(duration) сек, другие клавиши: \(leftControlState.hasOtherKeys)")
                    if !leftControlState.hasOtherKeys && duration < clickTimeout {
                        triggerLeftControlAction()
                    }
                    leftControlState.isPressed = false
                }
            }
            
            // 2. Обработка Правого Control (keycode 62)
            if keycode == 62 {
                if isRightNowPressed && !rightControlState.isPressed {
                    // Клавиша зажата
                    rightControlState.isPressed = true
                    rightControlState.pressTime = Date()
                    rightControlState.hasOtherKeys = false
                    DebugLogger.log("[EventTap] Нажат правый Control")
                } else if !isRightNowPressed && rightControlState.isPressed {
                    // Клавиша отпущена
                    let duration = Date().timeIntervalSince(rightControlState.pressTime)
                    DebugLogger.log("[EventTap] Отпущен правый Control, удержание: \(duration) сек, другие клавиши: \(rightControlState.hasOtherKeys)")
                    if !rightControlState.hasOtherKeys && duration < clickTimeout {
                        triggerRightControlAction()
                    }
                    rightControlState.isPressed = false
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Действие по нажатию левого Control
    private func triggerLeftControlAction() {
        DebugLogger.log("[EventTap] Клик левого Control -> переключение на \(leftControlLayoutID)")
        DispatchQueue.main.async {
            let success = KeyboardLayoutManager.shared.selectLayout(id: self.leftControlLayoutID)
            DebugLogger.log("[EventTap] Переключение на левый Control результат: \(success)")
        }
    }
    
    /// Действие по нажатию правого Control
    private func triggerRightControlAction() {
        DebugLogger.log("[EventTap] Клик правого Control -> цикл раскладок \(rightControlLayoutIDs)")
        DispatchQueue.main.async {
            let currentBefore = KeyboardLayoutManager.shared.getCurrentLayoutID() ?? "unknown"
            KeyboardLayoutManager.shared.cycleLayouts(ids: self.rightControlLayoutIDs)
            let currentAfter = KeyboardLayoutManager.shared.getCurrentLayoutID() ?? "unknown"
            DebugLogger.log("[EventTap] Переключение правого Control: \(currentBefore) -> \(currentAfter)")
        }
    }
}
