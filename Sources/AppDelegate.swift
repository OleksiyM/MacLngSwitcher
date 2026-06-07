import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Инициализируем элемент строки меню (StatusBar)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Используем стандартную системную иконку клавиатуры
            if let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacLngSwitcher") {
                // Делаем иконку адаптивной для темной/светлой темы строки меню
                image.isTemplate = true
                button.image = image
            }
            
            // Настраиваем обработку кликов (левый и правый)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Автоматически запрашиваем права при первом запуске (не блокируя интерфейс)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            EventTapManager.shared.checkAccessibility(prompt: true)
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Правый клик -> Показываем контекстное меню
            statusItem.menu = makeContextMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // Очищаем ссылку, чтобы не ломать левый клик
        } else {
            // Левый клик -> Открываем окно настроек
            showSettings()
        }
    }
    
    // Создание меню по правому клику
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let activeItem = NSMenuItem(title: "Active", action: #selector(toggleActive(_:)), keyEquivalent: "")
        activeItem.target = self
        activeItem.state = EventTapManager.shared.isEnabled ? .on : .off
        menu.addItem(activeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MacLngSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc func toggleActive(_ sender: NSMenuItem) {
        EventTapManager.shared.isEnabled.toggle()
        sender.state = EventTapManager.shared.isEnabled ? .on : .off
        
        // Перезапускаем EventTap при включении/выключении
        if EventTapManager.shared.isEnabled {
            EventTapManager.shared.startEventTap()
        } else {
            EventTapManager.shared.stopEventTap()
        }
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView()
            
            // Создаем безрамочное окно настроек
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.title = "MacLngSwitcher"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.hasShadow = true
            
            // Делаем углы окна круглыми и красивыми
            window.contentView = NSHostingView(rootView: contentView)
            
            self.settingsWindow = window
        }
        
        // Показываем окно по центру экрана
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        
        // Делаем наше приложение активным, чтобы окно было поверх других
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Останавливаем EventTap перед выходом
        EventTapManager.shared.stopEventTap()
    }
}
