import SwiftUI

struct SettingsView: View {
    @ObservedObject var eventManager = EventTapManager.shared
    @ObservedObject var layoutManager = KeyboardLayoutManager.shared
    @ObservedObject var launchManager = LaunchAtLoginManager.shared
    
    @State private var hoveredItem: String? = nil
    
    var body: some View {
        ZStack {
            // --- NATIVE SYSTEM VIBRANCY BACKGROUND ---
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            // --- CONTENT LAYER ---
            VStack(spacing: 14) {
                // Header (Minimalist & Clean)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacLngSwitcher")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Keyboard Layout Utility")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                // 1. Accessibility Status Card (Ultra-minimal)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Accessibility Access")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(eventManager.hasAccessibilityAccess ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text(eventManager.hasAccessibilityAccess ? "Active" : "Required")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(eventManager.hasAccessibilityAccess ? .green : .orange)
                        }
                    }
                    
                    Text("Accessibility access is required to intercept modifier keys. If already enabled, please restart the utility.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            openAccessibilityPreferences()
                        }) {
                            Text("Open Settings")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(hoveredItem == "settings_btn" ? 1.01 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: hoveredItem)
                        .onHover { isHovered in
                            hoveredItem = isHovered ? "settings_btn" : nil
                        }
                        
                        Button(action: {
                            restartApplication()
                        }) {
                            Text("Restart Application")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(hoveredItem == "restart_btn" ? 1.01 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: hoveredItem)
                        .onHover { isHovered in
                            hoveredItem = isHovered ? "restart_btn" : nil
                        }
                    }
                }
                .monoGlassCard()
                
                // 2. Key Mappings (Side-by-Side)
                HStack(alignment: .top, spacing: 16) {
                    // Left Control (Switch)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Left Control")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Switch to layout:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        
                        Picker("", selection: $eventManager.leftControlLayoutID) {
                            ForEach(layoutManager.availableLayouts) { layout in
                                Text(layout.name).tag(layout.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(Color.primary.opacity(0.08))
                        .frame(height: 110)
                    
                    // Right Control (Cycle List)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Right Control")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Cycle layout list:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(layoutManager.availableLayouts) { layout in
                                    let isChecked = eventManager.rightControlLayoutIDs.contains(layout.id)
                                    
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(isChecked ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.0001))
                                                .frame(width: 14, height: 14)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .stroke(isChecked ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: 1)
                                                )
                                            if isChecked {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        Text(layout.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(isChecked ? .primary : .secondary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleRightControlLayout(layout.id)
                                    }
                                }
                            }
                        }
                        .frame(height: 75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .monoGlassCard()
                
                // 3. Settings & Behavior (Sensitivity & Login)
                VStack(spacing: 14) {
                    // Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Keypress Sensitivity")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.2f s", eventManager.clickTimeout))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: $eventManager.clickTimeout, in: 0.15...0.60, step: 0.05)
                            .tint(.accentColor)
                    }
                    
                    Divider()
                        .background(Color.primary.opacity(0.08))
                    
                    // Autostart Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Start utility automatically at macOS boot.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchManager.isEnabled)
                            .toggleStyle(.switch)
                            .tint(.accentColor)
                            .labelsHidden()
                    }
                }
                .monoGlassCard()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            layoutManager.refreshAvailableLayouts()
            eventManager.validateAndFilterLayouts()
            eventManager.checkAccessibility(prompt: false)
            launchManager.refreshStatus()
        }
    }
    
    private func toggleRightControlLayout(_ id: String) {
        var current = eventManager.rightControlLayoutIDs
        if current.contains(id) {
            // Only allow removal if at least one valid system layout remains in the selected list
            let availableIDs = layoutManager.availableLayouts.map { $0.id }
            let validCurrentCount = current.filter { availableIDs.contains($0) }.count
            
            if validCurrentCount > 1 {
                current.removeAll(where: { $0 == id })
            }
        } else {
            current.append(id)
        }
        eventManager.rightControlLayoutIDs = current
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func restartApplication() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            NSLog("Failed to restart application: %@", error.localizedDescription)
        }
    }
}

// --- MONOCHROME GLASS EFFECT ---
extension View {
    func monoGlassCard(cornerRadius: CGFloat = 10) -> some View {
        self
            .padding(12)
            .background(
                Color(NSColor.controlBackgroundColor)
                    .opacity(0.45)
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1.0)
            )
    }
}

