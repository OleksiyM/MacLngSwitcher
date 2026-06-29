import Foundation
import ServiceManagement

public class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    private let service = SMAppService.mainApp
    
    @Published public var isEnabled: Bool = false {
        didSet {
            // Avoid infinite recursion by updating only if the status actually differs
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
                NSLog("[LaunchAtLogin] Successfully registered launch at login.")
            } catch {
                NSLog("[LaunchAtLogin] Error registering launch at login: %@", error.localizedDescription)
                // Revert the toggle in the UI
                DispatchQueue.main.async {
                    self.isEnabled = false
                }
            }
        } else {
            do {
                try service.unregister()
                NSLog("[LaunchAtLogin] Successfully unregistered launch at login.")
            } catch {
                NSLog("[LaunchAtLogin] Error unregistering launch at login: %@", error.localizedDescription)
                // Revert the toggle in the UI
                DispatchQueue.main.async {
                    self.isEnabled = true
                }
            }
        }
    }
}
