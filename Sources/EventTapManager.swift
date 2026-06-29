import Foundation
import Cocoa
import ApplicationServices
import IOKit
import IOKit.ps

public class EventTapManager: ObservableObject {
    public static let shared = EventTapManager()
    
    @Published public var hasAccessibilityAccess: Bool = false
    @Published public var isEnabled: Bool = true
    
    // User preferences (auto-saved in UserDefaults)
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
    
    @Published public var leftModifier: String {
        didSet {
            UserDefaults.standard.set(leftModifier, forKey: "leftModifier")
        }
    }
    
    @Published public var rightModifier: String {
        didSet {
            UserDefaults.standard.set(rightModifier, forKey: "rightModifier")
        }
    }
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Key press state
    private struct ModifierState {
        var isPressed: Bool = false
        var pressTime: Date = Date()
        var hasOtherKeys: Bool = false
    }
    
    private var leftModifierState = ModifierState()
    private var rightModifierState = ModifierState()
    
    private init() {
        // Ensure keyboard layouts are scanned
        KeyboardLayoutManager.shared.refreshAvailableLayouts()
        let layouts = KeyboardLayoutManager.shared.availableLayouts
        
        // 1. Determine local values without referencing 'self'
        let chosenLeftID: String
        if let savedLeft = UserDefaults.standard.string(forKey: "leftControlLayoutID") {
            chosenLeftID = savedLeft
        } else {
            // Look for a suitable default English layout (ABC, US, English)
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
            // Look for Russian layout
            if let ru = layouts.first(where: { $0.id.lowercased().contains("russian") || $0.name.lowercased().contains("рус") }) {
                selected.append(ru.id)
            }
            // Look for Ukrainian layout
            if let ua = layouts.first(where: { $0.id.lowercased().contains("ukrainian") || $0.name.lowercased().contains("укр") }) {
                selected.append(ua.id)
            }
            
            // If none found, take all layouts different from the left one
            if selected.isEmpty {
                selected = layouts.filter({ $0.id != chosenLeftID }).map({ $0.id })
            }
            // Fallback placeholder if still empty
            if selected.isEmpty {
                selected = ["com.apple.keylayout.Russian"]
            }
            chosenRightIDs = selected
            UserDefaults.standard.set(selected, forKey: "rightControlLayoutIDs")
        }
        
        let savedTimeout = UserDefaults.standard.double(forKey: "clickTimeout")
        let chosenTimeout = savedTimeout > 0 ? savedTimeout : 0.35
        
        let chosenLeftMod: String
        if let savedLeftMod = UserDefaults.standard.string(forKey: "leftModifier") {
            chosenLeftMod = savedLeftMod
        } else {
            chosenLeftMod = "control"
            UserDefaults.standard.set(chosenLeftMod, forKey: "leftModifier")
        }
        
        let chosenRightMod: String
        if let savedRightMod = UserDefaults.standard.string(forKey: "rightModifier") {
            chosenRightMod = savedRightMod
        } else {
            // Check if portable device (MacBook)
            var isPortable = false
            if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
                isPortable = !list.isEmpty
            }
            chosenRightMod = isPortable ? "option" : "control"
            UserDefaults.standard.set(chosenRightMod, forKey: "rightModifier")
            DebugLogger.log("[EventTap] First launch modifier auto-detection: isPortable=\(isPortable) -> choosing default Right Modifier: \(chosenRightMod)")
        }
        
        // 2. Initialize properties
        self.leftControlLayoutID = chosenLeftID
        self.rightControlLayoutIDs = chosenRightIDs
        self.clickTimeout = chosenTimeout
        self.leftModifier = chosenLeftMod
        self.rightModifier = chosenRightMod
        
        // Validate and filter layouts right after loading
        validateAndFilterLayouts()
        
        // 3. Call instance methods
        checkAccessibility(prompt: false)
        if hasAccessibilityAccess {
            startEventTap()
        }
    }
    
    /// Checks for accessibility permissions
    public func checkAccessibility(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let access = AXIsProcessTrustedWithOptions(options)
        self.hasAccessibilityAccess = access
        
        if access && eventTap == nil {
            startEventTap()
        }
    }
    
    /// Validates and filters selected layouts to match active system layouts.
    /// This prevents "phantom" layouts if system keyboard settings change.
    public func validateAndFilterLayouts() {
        // Get fresh list of active layouts
        KeyboardLayoutManager.shared.refreshAvailableLayouts()
        let availableIDs = KeyboardLayoutManager.shared.availableLayouts.map { $0.id }
        
        guard !availableIDs.isEmpty else { return }
        
        // 1. Validate and adjust Left Control
        if !availableIDs.contains(leftControlLayoutID) {
            // If saved layout is unavailable, fallback to US layout or first available
            let fallbackLeft = availableIDs.first(where: { $0.contains("ABC") }) ??
                               availableIDs.first(where: { $0.contains("US") }) ??
                               availableIDs.first ??
                               ""
            if !fallbackLeft.isEmpty {
                leftControlLayoutID = fallbackLeft
                DebugLogger.log("[EventTap] Left Control adjusted to: \(fallbackLeft)")
            }
        }
        
        // 2. Filter Right Control, keeping only active system layouts
        var filteredRight = rightControlLayoutIDs.filter { availableIDs.contains($0) }
        
        // 3. If filtered list is empty, automatically populate with defaults
        if filteredRight.isEmpty {
            // Get all active layouts except the one assigned to Left Control
            filteredRight = availableIDs.filter { $0 != leftControlLayoutID }
            
            // If still empty (e.g. only one layout exists), fallback to it
            if filteredRight.isEmpty, let first = availableIDs.first {
                filteredRight = [first]
            }
            
            DebugLogger.log("[EventTap] Right list was empty or invalid, auto-populating: \(filteredRight)")
        }
        
        if filteredRight != rightControlLayoutIDs {
            rightControlLayoutIDs = filteredRight
            DebugLogger.log("[EventTap] Right list adjusted to: \(filteredRight)")
        }
    }
    
    /// Starts the event tap
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
            DebugLogger.log("[EventTap] Failed to create CGEventTap. Missing accessibility permissions?")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            DebugLogger.log("[EventTap] Successfully started.")
        }
    }
    
    /// Stops the event tap
    public func stopEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        DebugLogger.log("[EventTap] Stopped.")
    }
    
    /// Restarts the event tap
    public func restartEventTap() {
        stopEventTap()
        startEventTap()
    }
    
    /// Main event handler
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else { return Unmanaged.passUnretained(event) }
        
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        DebugLogger.log("[EventTap] handleEvent: type=\(type.rawValue), keycode=\(keycode)")
        
        // If a normal key is pressed/released, mark "hasOtherKeys" on active modifiers
        if type == .keyDown || type == .keyUp {
            if leftModifierState.isPressed {
                leftModifierState.hasOtherKeys = true
            }
            if rightModifierState.isPressed {
                rightModifierState.hasOtherKeys = true
            }
            return Unmanaged.passUnretained(event)
        }
        
        if type == .flagsChanged {
            // Convert CGEvent to NSEvent to reliably read device-dependent flags
            guard let nsEvent = NSEvent(cgEvent: event) else {
                return Unmanaged.passUnretained(event)
            }
            
            let rawFlags = nsEvent.modifierFlags.rawValue
            
            // Resolve active dynamic targets based on user configuration
            let leftTargetKeycode: Int64 = (leftModifier == "option") ? 58 : 59
            let leftTargetMask: UInt = (leftModifier == "option") ? 0x00000020 : 0x00000001
            
            let rightTargetKeycode: Int64 = (rightModifier == "option") ? 61 : 62
            let rightTargetMask: UInt = (rightModifier == "option") ? 0x00000040 : 0x00002000
            
            let isLeftNowPressed = (rawFlags & leftTargetMask) != 0
            let isRightNowPressed = (rawFlags & rightTargetMask) != 0
            
            DebugLogger.log("[EventTap] flagsChanged: keycode=\(keycode), leftPressed=\(isLeftNowPressed), rightPressed=\(isRightNowPressed), rawFlags=\(rawFlags)")
            
            // If left modifier is pressed, but another modifier triggers
            if leftModifierState.isPressed && keycode != leftTargetKeycode {
                leftModifierState.hasOtherKeys = true
            }
            // If right modifier is pressed, but another modifier triggers
            if rightModifierState.isPressed && keycode != rightTargetKeycode {
                rightModifierState.hasOtherKeys = true
            }
            
            // 1. Left Modifier Handling
            if keycode == leftTargetKeycode {
                if isLeftNowPressed && !leftModifierState.isPressed {
                    // Key pressed
                    leftModifierState.isPressed = true
                    leftModifierState.pressTime = Date()
                    leftModifierState.hasOtherKeys = false
                    DebugLogger.log("[EventTap] Left Modifier (\(leftModifier)) pressed")
                } else if !isLeftNowPressed && leftModifierState.isPressed {
                    // Key released
                    let duration = Date().timeIntervalSince(leftModifierState.pressTime)
                    DebugLogger.log("[EventTap] Left Modifier (\(leftModifier)) released, duration: \(duration) sec, hasOtherKeys: \(leftModifierState.hasOtherKeys)")
                    if !leftModifierState.hasOtherKeys && duration < clickTimeout {
                        triggerLeftControlAction()
                    }
                    leftModifierState.isPressed = false
                }
            }
            
            // 2. Right Modifier Handling
            if keycode == rightTargetKeycode {
                if isRightNowPressed && !rightModifierState.isPressed {
                    // Key pressed
                    rightModifierState.isPressed = true
                    rightModifierState.pressTime = Date()
                    rightModifierState.hasOtherKeys = false
                    DebugLogger.log("[EventTap] Right Modifier (\(rightModifier)) pressed")
                } else if !isRightNowPressed && rightModifierState.isPressed {
                    // Key released
                    let duration = Date().timeIntervalSince(rightModifierState.pressTime)
                    DebugLogger.log("[EventTap] Right Modifier (\(rightModifier)) released, duration: \(duration) sec, hasOtherKeys: \(rightModifierState.hasOtherKeys)")
                    if !rightModifierState.hasOtherKeys && duration < clickTimeout {
                        triggerRightControlAction()
                    }
                    rightModifierState.isPressed = false
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Trigger action on Left Control click
    private func triggerLeftControlAction() {
        DebugLogger.log("[EventTap] Left Modifier (\(leftModifier)) click -> switching to \(leftControlLayoutID)")
        DispatchQueue.main.async {
            let success = KeyboardLayoutManager.shared.selectLayout(id: self.leftControlLayoutID)
            DebugLogger.log("[EventTap] Switch Left Modifier (\(self.leftModifier)) layout result: \(success)")
        }
    }
    
    /// Trigger action on Right Control click
    private func triggerRightControlAction() {
        DebugLogger.log("[EventTap] Right Modifier (\(rightModifier)) click -> cycling layouts \(rightControlLayoutIDs)")
        DispatchQueue.main.async {
            let currentBefore = KeyboardLayoutManager.shared.getCurrentLayoutID() ?? "unknown"
            KeyboardLayoutManager.shared.cycleLayouts(ids: self.rightControlLayoutIDs)
            let currentAfter = KeyboardLayoutManager.shared.getCurrentLayoutID() ?? "unknown"
            DebugLogger.log("[EventTap] Switch Right Modifier (\(self.rightModifier)) layout: \(currentBefore) -> \(currentAfter)")
        }
    }
}
