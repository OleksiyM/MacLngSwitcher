import Foundation
import ServiceManagement

public class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    private let service = SMAppService.mainApp
    
    @Published public var isEnabled: Bool = false {
        didSet {
            // Избегаем бесконечной рекурсии, меняя только если статус действительно отличается
            let currentStatus = service.status == .enabled
            if isEnabled != currentStatus {
                updateLaunchAtLogin(enabled: isEnabled)
            }
        }
    }
    
    private init() {
        self.isEnabled = service.status == .enabled
    }
    
    public func refreshStatus() {
        let enabled = service.status == .enabled
        if self.isEnabled != enabled {
            self.isEnabled = enabled
        }
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        if enabled {
            do {
                try service.register()
                NSLog("[LaunchAtLogin] Успешно зарегистрирован автозапуск.")
            } catch {
                NSLog("[LaunchAtLogin] Ошибка регистрации автозапуска: %@", error.localizedDescription)
                // Возвращаем переключатель назад в UI
                DispatchQueue.main.async {
                    self.isEnabled = false
                }
            }
        } else {
            do {
                try service.unregister()
                NSLog("[LaunchAtLogin] Успешно отменен автозапуск.")
            } catch {
                NSLog("[LaunchAtLogin] Ошибка отмены автозапуска: %@", error.localizedDescription)
                // Возвращаем переключатель назад в UI
                DispatchQueue.main.async {
                    self.isEnabled = true
                }
            }
        }
    }
}
