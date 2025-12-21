import Cocoa
import ScreenCaptureKit
import AVFoundation
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var captureEngine: ScreenCaptureEngine?
    var statusItem: NSStatusItem!
    var hudWindow: HUDWindow?
    var pipWindow: PiPWindow?
    var mainView: MainView!
    var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager = HotkeyManager()
        hotkeyManager.delegate = self
        hotkeyManager.registerHotkeys()

        setupStatusBar()
        setupMainWindow()
        setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAllHotkeys()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Cloak")
            button.action = #selector(statusBarClicked)
            button.target = self
        }

        updateStatusBarIcon(isPrivate: false)
    }

    func updateStatusBarIcon(isPrivate: Bool) {
        if let button = statusItem.button {
            let symbolName = isPrivate ? "eye.slash.fill" : "eye.fill"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Cloak") {
                if isPrivate {
                    // Bright green when privacy is ON
                    let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
                    button.image = image.withSymbolConfiguration(config)
                } else {
                    // Default color when privacy is OFF
                    button.image = image
                }
            }
        }
    }

    @objc func statusBarClicked() {
        let menu = NSMenu()

        let isCapturing = captureEngine != nil
        let statusTitle = captureEngine?.isPrivacyEnabled ?? false ? "🔒 Privacy: ON" : "👁️ Privacy: OFF"
        let menuStatusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        menuStatusItem.isEnabled = false
        menu.addItem(menuStatusItem)

        menu.addItem(NSMenuItem.separator())

        if isCapturing {
            menu.addItem(NSMenuItem(title: "Toggle Privacy", action: #selector(togglePrivacy), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Stop Sharing", action: #selector(stopCapture), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Start Sharing", action: #selector(startCapture), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Cloak Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Cloak", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Cloak", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func setupMainWindow() {
        // Match the screen's aspect ratio for best preview quality
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenSize = screen.frame.size
        let aspectRatio = screenSize.width / screenSize.height

        // Use 75% of screen height for good size, maintain aspect ratio
        let windowHeight: CGFloat = min(900, screenSize.height * 0.75)
        let windowWidth = windowHeight * aspectRatio
        let windowRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Cloak"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 640, height: 400)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]
        window.aspectRatio = NSSize(width: aspectRatio, height: 1)  // Lock aspect ratio

        // Hide from external screen capture until sharing starts
        // This prevents Google Meet/Zoom from seeing the settings screen
        window.sharingType = .none

        mainView = MainView(frame: windowRect)
        mainView.delegate = self
        mainView.settingsDelegate = self
        mainView.hotkeyManager = hotkeyManager
        window.contentView = mainView

        // Center the window on screen
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "About Cloak", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Cloak", action: #selector(quit), keyEquivalent: "q"))

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(NSMenuItem(title: "Toggle Privacy", action: #selector(togglePrivacy), keyEquivalent: ""))
        viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(toggleFullScreen), keyEquivalent: "f"))

        NSApp.mainMenu = mainMenu
    }

    @objc func startCapture() {
        mainView.showCapturing()

        // Make window visible to external screen capture (Google Meet, Zoom, etc.)
        window.sharingType = .readOnly

        // Ensure HUD and PiP windows exist so they can be excluded
        if hudWindow == nil {
            hudWindow = HUDWindow()
        }
        if pipWindow == nil {
            pipWindow = PiPWindow()
        }

        // Get settings from start screen
        let excludedApps = mainView.startScreenView.getExcludedApps()
        let blurIntensity = mainView.startScreenView.getBlurIntensity()
        let hideSelfFromPreview = mainView.startScreenView.getHideSelfFromPreview()

        // Collect windows to exclude from capture (only if self-hiding is enabled)
        var windowsToExclude: [NSWindow] = []
        if hideSelfFromPreview {
            windowsToExclude.append(window)
            if let hud = hudWindow {
                windowsToExclude.append(hud)
            }
            if let pip = pipWindow {
                windowsToExclude.append(pip)
            }
        }

        // Set blur intensity on preview view
        mainView.previewView.blurIntensity = blurIntensity

        captureEngine = ScreenCaptureEngine(previewView: mainView.previewView, excludingWindows: windowsToExclude, excludingApps: excludedApps)
        captureEngine?.delegate = self
        captureEngine?.startCapture()
    }

    @objc func stopCapture() {
        captureEngine?.stopCapture()
        captureEngine = nil

        // Hide window from external screen capture again
        window.sharingType = .none

        // Hide PiP window
        pipWindow?.hide()

        mainView.showStartScreen()
        updateStatusBarIcon(isPrivate: false)
    }

    @objc func togglePrivacy() {
        guard captureEngine != nil else { return }
        captureEngine?.togglePrivacy()
        showHUD(isPrivate: captureEngine?.isPrivacyEnabled ?? false)
    }

    @objc func toggleFullScreen() {
        window.toggleFullScreen(nil)
    }

    @objc func togglePiP() {
        guard captureEngine != nil else { return }

        if pipWindow == nil {
            pipWindow = PiPWindow()
        }

        if pipWindow?.isVisible == true {
            pipWindow?.hide()
        } else {
            pipWindow?.show()
            // Update PiP with current frame
            if let frame = mainView.previewView.currentFrame {
                pipWindow?.updateFrame(frame, isPrivacyEnabled: captureEngine?.isPrivacyEnabled ?? false, privacyMode: captureEngine?.currentPrivacyMode ?? .blur)
            }
        }
    }

    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Cloak"
        alert.informativeText = "Hide your screen during video calls.\n\nShare the Cloak window in Zoom/Meet, not your entire screen.\n\nYour screen stays normal while viewers see the privacy overlay."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func showHUD(isPrivate: Bool) {
        if hudWindow == nil {
            hudWindow = HUDWindow()
        }

        // Get current frame and settings for HUD preview
        let frame = mainView.previewView.currentFrame
        let blurIntensity = mainView.previewView.blurIntensity
        let privacyMode = captureEngine?.currentPrivacyMode ?? .blur
        let customImage = mainView.previewView.customImage

        hudWindow?.show(
            isPrivate: isPrivate,
            previewFrame: frame,
            blurIntensity: blurIntensity,
            privacyMode: privacyMode,
            customImage: customImage
        )
    }
}

extension AppDelegate: ScreenCaptureEngineDelegate {
    func privacyStateDidChange(isPrivate: Bool) {
        updateStatusBarIcon(isPrivate: isPrivate)
    }

    func didReceiveFrame(_ frame: CVImageBuffer) {
        // Update PiP window if visible
        guard let pip = pipWindow, pip.isVisible else { return }

        let isPrivacy = captureEngine?.isPrivacyEnabled ?? false
        let mode = captureEngine?.currentPrivacyMode ?? .blur
        let blur = mainView.previewView.blurIntensity
        let customImg = mainView.previewView.customImage

        pip.updateFrame(frame, isPrivacyEnabled: isPrivacy, privacyMode: mode, blurIntensity: blur, customImage: customImg)
    }
}

extension AppDelegate: MainViewDelegate {
    func mainViewDidRequestStart() {
        startCapture()
    }

    func mainViewDidRequestStop() {
        stopCapture()
    }

    func mainViewDidRequestTogglePrivacy() {
        togglePrivacy()
    }

    func mainViewDidRequestFullscreen() {
        toggleFullScreen()
    }
}

extension AppDelegate: HotkeyManagerDelegate {
    func hotkeyDidTrigger(action: HotkeyAction) {
        switch action {
        case .togglePrivacy:
            togglePrivacy()
        case .startStopSharing:
            if captureEngine != nil {
                stopCapture()
            } else {
                startCapture()
            }
        case .toggleFullscreen:
            toggleFullScreen()
        case .togglePiP:
            togglePiP()
        }
    }
}

extension AppDelegate: MainViewSettingsDelegate {
    func mainViewDidChangeSettings() {
        // Apply live settings changes to the capture engine
        guard let engine = captureEngine else { return }

        // Reload settings from UserDefaults
        engine.loadSettings()

        // Update blur intensity from UserDefaults (may come from SettingsPanel or StartScreen)
        if UserDefaults.standard.object(forKey: "blurIntensity") != nil {
            mainView.previewView.blurIntensity = UserDefaults.standard.double(forKey: "blurIntensity")
        }

        // Update custom image if changed
        if let imagePath = UserDefaults.standard.string(forKey: "customImagePath"),
           let image = NSImage(contentsOfFile: imagePath) {
            mainView.previewView.customImage = image
        }

        // Force redraw
        mainView.previewView.needsDisplay = true
    }
}

// MARK: - Hotkey Manager

enum HotkeyAction: Int, CaseIterable {
    case togglePrivacy = 1
    case startStopSharing = 2
    case toggleFullscreen = 3
    case togglePiP = 4

    var displayName: String {
        switch self {
        case .togglePrivacy: return "Toggle Privacy"
        case .startStopSharing: return "Start/Stop Sharing"
        case .toggleFullscreen: return "Toggle Fullscreen"
        case .togglePiP: return "Toggle Preview (PiP)"
        }
    }

    var storageKey: String {
        switch self {
        case .togglePrivacy: return "togglePrivacy"
        case .startStopSharing: return "startStopSharing"
        case .toggleFullscreen: return "toggleFullscreen"
        case .togglePiP: return "togglePiP"
        }
    }
}

struct HotkeyConfig: Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 118: "F4", 119: "F2", 120: "F1",
            122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode]
    }
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyDidTrigger(action: HotkeyAction)
}

class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?
    private var hotkeys: [HotkeyAction: HotkeyConfig] = [:]
    private var hotkeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?

    static let shared = HotkeyManager()

    init() {
        loadHotkeys()
    }

    func loadHotkeys() {
        if let data = UserDefaults.standard.data(forKey: "hotkeys"),
           let decoded = try? JSONDecoder().decode([String: HotkeyConfig].self, from: data) {
            for (key, config) in decoded {
                if let action = HotkeyAction.allCases.first(where: { $0.storageKey == key }) {
                    hotkeys[action] = config
                }
            }
        }
    }

    func saveHotkeys() {
        var toSave: [String: HotkeyConfig] = [:]
        for (action, config) in hotkeys {
            toSave[action.storageKey] = config
        }
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "hotkeys")
        }
    }

    func getHotkey(for action: HotkeyAction) -> HotkeyConfig? {
        return hotkeys[action]
    }

    func setHotkey(for action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) {
        // Unregister old hotkey if exists
        if let ref = hotkeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotkeyRefs.removeValue(forKey: action)
        }

        let config = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        hotkeys[action] = config
        saveHotkeys()

        // Register new hotkey
        registerHotkey(action: action, config: config)
    }

    func removeHotkey(for action: HotkeyAction) {
        if let ref = hotkeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotkeyRefs.removeValue(forKey: action)
        }
        hotkeys.removeValue(forKey: action)
        saveHotkeys()
    }

    func registerHotkeys() {
        // Install event handler once
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            // Use high priority for immediate response
            DispatchQueue.main.async(qos: .userInteractive) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    if let action = HotkeyAction(rawValue: Int(hotKeyID.id)) {
                        appDelegate.hotkeyManager.delegate?.hotkeyDidTrigger(action: action)
                    }
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)

        // Register all configured hotkeys
        for (action, config) in hotkeys {
            registerHotkey(action: action, config: config)
        }
    }

    private func registerHotkey(action: HotkeyAction, config: HotkeyConfig) {
        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4B00) // "CLK\0"
        hotKeyID.id = UInt32(action.rawValue)

        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs[action] = ref
        }
    }

    func unregisterAllHotkeys() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
    }
}

// MARK: - Main View

protocol MainViewDelegate: AnyObject {
    func mainViewDidRequestStart()
    func mainViewDidRequestStop()
    func mainViewDidRequestTogglePrivacy()
    func mainViewDidRequestFullscreen()
}

protocol MainViewSettingsDelegate: AnyObject {
    func mainViewDidChangeSettings()
}

class MainView: NSView {
    weak var delegate: MainViewDelegate?
    weak var settingsDelegate: MainViewSettingsDelegate?
    weak var hotkeyManager: HotkeyManager? {
        didSet {
            startScreenView?.hotkeyManager = hotkeyManager
            settingsPanel?.hotkeyManager = hotkeyManager
        }
    }

    private(set) var startScreenView: StartScreenView!
    var previewView: PreviewView!
    private var stopButton: NSButton!
    private var privacyButton: NSButton!
    private var fullscreenButton: NSButton!
    private var settingsButton: NSButton!
    private var controlsContainer: NSVisualEffectView!
    private var trackingArea: NSTrackingArea?

    // Settings panel for live editing
    private var settingsPanel: SettingsPanel?
    private var settingsPanelVisible = false

    private var isCapturing = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        // Start screen
        startScreenView = StartScreenView(frame: bounds)
        startScreenView.autoresizingMask = [.width, .height]
        startScreenView.onStart = { [weak self] in
            self?.delegate?.mainViewDidRequestStart()
        }
        startScreenView.onSettingsChanged = { [weak self] in
            self?.settingsDelegate?.mainViewDidChangeSettings()
        }
        addSubview(startScreenView)

        // Preview view (hidden initially)
        previewView = PreviewView(frame: bounds)
        previewView.autoresizingMask = [.width, .height]
        previewView.isHidden = true
        addSubview(previewView)

        // Controls container (shown on hover during capture)
        setupControls()

        // Settings panel (for live editing during capture)
        setupSettingsPanel()
    }

    private func setupControls() {
        controlsContainer = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 380, height: 50))
        controlsContainer.material = .hudWindow
        controlsContainer.state = .active
        controlsContainer.blendingMode = .behindWindow
        controlsContainer.wantsLayer = true
        controlsContainer.layer?.cornerRadius = 12
        controlsContainer.layer?.masksToBounds = true
        controlsContainer.isHidden = true
        addSubview(controlsContainer)

        // Stop button
        stopButton = NSButton(frame: NSRect(x: 12, y: 10, width: 70, height: 30))
        stopButton.title = "Stop"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.contentTintColor = .systemRed
        controlsContainer.addSubview(stopButton)

        // Privacy toggle button
        privacyButton = NSButton(frame: NSRect(x: 90, y: 10, width: 80, height: 30))
        privacyButton.title = "Privacy"
        privacyButton.bezelStyle = .rounded
        privacyButton.target = self
        privacyButton.action = #selector(privacyClicked)
        controlsContainer.addSubview(privacyButton)

        // Settings button
        settingsButton = NSButton(frame: NSRect(x: 178, y: 10, width: 90, height: 30))
        settingsButton.title = "Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        controlsContainer.addSubview(settingsButton)

        // Fullscreen button
        fullscreenButton = NSButton(frame: NSRect(x: 276, y: 10, width: 92, height: 30))
        fullscreenButton.title = "Fullscreen"
        fullscreenButton.bezelStyle = .rounded
        fullscreenButton.target = self
        fullscreenButton.action = #selector(fullscreenClicked)
        controlsContainer.addSubview(fullscreenButton)
    }

    private func setupSettingsPanel() {
        settingsPanel = SettingsPanel(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        settingsPanel?.isHidden = true
        settingsPanel?.onSettingsChanged = { [weak self] in
            self?.settingsDelegate?.mainViewDidChangeSettings()
        }
        settingsPanel?.onClose = { [weak self] in
            self?.hideSettingsPanel()
        }
        addSubview(settingsPanel!)
    }

    func showSettingsPanel() {
        guard let panel = settingsPanel else { return }
        panel.syncFromStartScreen(startScreenView)
        panel.frame = NSRect(
            x: (bounds.width - 320) / 2,
            y: (bounds.height - 200) / 2,
            width: 320,
            height: 200
        )
        panel.isHidden = false
        panel.alphaValue = 0
        settingsPanelVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    func hideSettingsPanel() {
        guard let panel = settingsPanel else { return }
        settingsPanelVisible = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.isHidden = true
        })
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if isCapturing {
            showControls()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if isCapturing {
            hideControls()
        }
    }

    private func showControls() {
        controlsContainer.frame = NSRect(
            x: (bounds.width - 380) / 2,
            y: 20,
            width: 380,
            height: 50
        )
        controlsContainer.isHidden = false
        controlsContainer.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            controlsContainer.animator().alphaValue = 1
        }
    }

    private func hideControls() {
        // Don't hide controls if settings panel is visible
        if settingsPanelVisible { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            controlsContainer.animator().alphaValue = 0
        }, completionHandler: {
            if !self.settingsPanelVisible {
                self.controlsContainer.isHidden = true
            }
        })
    }

    func showCapturing() {
        isCapturing = true
        startScreenView.isHidden = true
        previewView.isHidden = false
    }

    func showStartScreen() {
        isCapturing = false
        startScreenView.isHidden = false
        previewView.isHidden = true
        controlsContainer.isHidden = true
        hideSettingsPanel()
        previewView.reset()
    }

    @objc private func stopClicked() {
        delegate?.mainViewDidRequestStop()
    }

    @objc private func privacyClicked() {
        delegate?.mainViewDidRequestTogglePrivacy()
    }

    @objc private func settingsClicked() {
        if settingsPanelVisible {
            hideSettingsPanel()
        } else {
            showSettingsPanel()
        }
    }

    @objc private func fullscreenClicked() {
        delegate?.mainViewDidRequestFullscreen()
    }
}

// MARK: - Start Screen View

class StartScreenView: NSView {
    var onStart: (() -> Void)?
    weak var hotkeyManager: HotkeyManager?
    var onSettingsChanged: (() -> Void)?  // Callback when settings change during sharing

    private let modeSegmented = NSSegmentedControl()
    private let imageWell = NSImageView()
    private var selectedMode: PrivacyMode = .blur
    private var customImage: NSImage?

    private var hotkeyButtons: [HotkeyAction: NSButton] = [:]
    private var recordingAction: HotkeyAction?
    private var globalMonitor: Any?

    // Mode-specific containers
    private var blurSettingsContainer: NSView!
    private var imageSettingsContainer: NSView!

    // Blur intensity
    private var blurIntensity: Double = 50.0
    private var blurSlider: NSSlider!
    private var blurValueLabel: NSTextField!

    // Excluded apps
    private var excludedApps: [String] = []
    private var excludedAppsStack: NSStackView!
    private var appNameField: NSTextField!

    // Self-hiding toggle
    private var hideSelfFromPreview: Bool = true
    private var hideSelfToggle: NSButton!

    // Scroll view
    private var scrollView: NSScrollView!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "privacyMode"),
           let mode = PrivacyMode(rawValue: modeString) {
            selectedMode = mode
            switch mode {
            case .blur: modeSegmented.selectedSegment = 0
            case .image: modeSegmented.selectedSegment = 1
            case .black: modeSegmented.selectedSegment = 2
            }
        }

        if let imagePath = UserDefaults.standard.string(forKey: "customImagePath"),
           let image = NSImage(contentsOfFile: imagePath) {
            customImage = image
            imageWell.image = image
        }

        // Load blur intensity
        if UserDefaults.standard.object(forKey: "blurIntensity") != nil {
            blurIntensity = UserDefaults.standard.double(forKey: "blurIntensity")
        }

        // Load excluded apps
        if let apps = UserDefaults.standard.stringArray(forKey: "excludedApps") {
            excludedApps = apps
        }

        // Load self-hiding preference (default true)
        if UserDefaults.standard.object(forKey: "hideSelfFromPreview") != nil {
            hideSelfFromPreview = UserDefaults.standard.bool(forKey: "hideSelfFromPreview")
        }

        // Update visibility based on loaded mode
        updateModeSettingsVisibility()
    }

    func getExcludedApps() -> [String] {
        return excludedApps
    }

    func getBlurIntensity() -> Double {
        return blurIntensity
    }

    func getSelectedMode() -> PrivacyMode {
        return selectedMode
    }

    func getCustomImage() -> NSImage? {
        return customImage
    }

    func getHideSelfFromPreview() -> Bool {
        return hideSelfFromPreview
    }

    private func saveExcludedApps() {
        UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        refreshExcludedAppsList()
    }

    func updateHotkeyLabels() {
        for action in HotkeyAction.allCases {
            if let button = hotkeyButtons[action] {
                if let config = hotkeyManager?.getHotkey(for: action) {
                    button.title = config.displayString
                } else {
                    button.title = "Click to set"
                }
            }
        }
    }

    private func updateModeSettingsVisibility() {
        blurSettingsContainer?.isHidden = selectedMode != .blur
        imageSettingsContainer?.isHidden = selectedMode != .image
    }

    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        return label
    }

    private func createCard() -> NSVisualEffectView {
        let card = NSVisualEffectView()
        card.material = .hudWindow
        card.state = .active
        card.blendingMode = .withinWindow
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor

        // Header area (fixed at top)
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)

        // Title
        let titleLabel = NSTextField(labelWithString: "Cloak")
        titleLabel.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Hide your screen during video calls")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 90),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),

            subtitleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])

        // Scroll view for content
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        // Content stack inside scroll view
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .centerX
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // Document view for scroll
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        scrollView.documentView = documentView

        // === Privacy Mode Card ===
        let modeCard = createCard()
        let modeStack = NSStackView()
        modeStack.orientation = .vertical
        modeStack.spacing = 12
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        modeCard.addSubview(modeStack)

        let modeHeader = createSectionHeader("Privacy Mode")
        modeStack.addArrangedSubview(modeHeader)

        modeSegmented.segmentCount = 3
        modeSegmented.setLabel("Blur", forSegment: 0)
        modeSegmented.setLabel("Image", forSegment: 1)
        modeSegmented.setLabel("Black", forSegment: 2)
        modeSegmented.selectedSegment = 0
        modeSegmented.segmentStyle = .automatic
        modeSegmented.target = self
        modeSegmented.action = #selector(modeChanged)
        modeStack.addArrangedSubview(modeSegmented)

        // Blur settings container
        blurSettingsContainer = NSView()
        blurSettingsContainer.translatesAutoresizingMaskIntoConstraints = false

        let blurLabel = NSTextField(labelWithString: "Blur Intensity")
        blurLabel.font = NSFont.systemFont(ofSize: 12)
        blurLabel.textColor = .secondaryLabelColor
        blurLabel.translatesAutoresizingMaskIntoConstraints = false
        blurSettingsContainer.addSubview(blurLabel)

        blurSlider = NSSlider(value: blurIntensity, minValue: 5, maxValue: 100, target: self, action: #selector(blurSliderChanged))
        blurSlider.translatesAutoresizingMaskIntoConstraints = false
        blurSettingsContainer.addSubview(blurSlider)

        blurValueLabel = NSTextField(labelWithString: "\(Int(blurIntensity))")
        blurValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        blurValueLabel.textColor = .white
        blurValueLabel.alignment = .right
        blurValueLabel.translatesAutoresizingMaskIntoConstraints = false
        blurSettingsContainer.addSubview(blurValueLabel)

        NSLayoutConstraint.activate([
            blurSettingsContainer.heightAnchor.constraint(equalToConstant: 28),
            blurLabel.leadingAnchor.constraint(equalTo: blurSettingsContainer.leadingAnchor),
            blurLabel.centerYAnchor.constraint(equalTo: blurSettingsContainer.centerYAnchor),
            blurSlider.leadingAnchor.constraint(equalTo: blurLabel.trailingAnchor, constant: 12),
            blurSlider.centerYAnchor.constraint(equalTo: blurSettingsContainer.centerYAnchor),
            blurSlider.widthAnchor.constraint(equalToConstant: 160),
            blurValueLabel.leadingAnchor.constraint(equalTo: blurSlider.trailingAnchor, constant: 8),
            blurValueLabel.trailingAnchor.constraint(equalTo: blurSettingsContainer.trailingAnchor),
            blurValueLabel.centerYAnchor.constraint(equalTo: blurSettingsContainer.centerYAnchor),
            blurValueLabel.widthAnchor.constraint(equalToConstant: 30)
        ])
        modeStack.addArrangedSubview(blurSettingsContainer)

        // Image settings container
        imageSettingsContainer = NSView()
        imageSettingsContainer.translatesAutoresizingMaskIntoConstraints = false
        imageSettingsContainer.isHidden = true

        let imageStack = NSStackView()
        imageStack.orientation = .vertical
        imageStack.spacing = 8
        imageStack.translatesAutoresizingMaskIntoConstraints = false
        imageSettingsContainer.addSubview(imageStack)

        imageWell.wantsLayer = true
        imageWell.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        imageWell.layer?.cornerRadius = 8
        imageWell.layer?.borderWidth = 1
        imageWell.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        imageWell.imageScaling = .scaleProportionallyUpOrDown
        imageWell.translatesAutoresizingMaskIntoConstraints = false
        imageStack.addArrangedSubview(imageWell)

        let chooseButton = NSButton(title: "Choose Image", target: self, action: #selector(chooseImage))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .small
        imageStack.addArrangedSubview(chooseButton)

        NSLayoutConstraint.activate([
            imageStack.topAnchor.constraint(equalTo: imageSettingsContainer.topAnchor),
            imageStack.leadingAnchor.constraint(equalTo: imageSettingsContainer.leadingAnchor),
            imageStack.trailingAnchor.constraint(equalTo: imageSettingsContainer.trailingAnchor),
            imageStack.bottomAnchor.constraint(equalTo: imageSettingsContainer.bottomAnchor),
            imageWell.heightAnchor.constraint(equalToConstant: 60),
            imageWell.widthAnchor.constraint(equalToConstant: 280)
        ])
        modeStack.addArrangedSubview(imageSettingsContainer)

        NSLayoutConstraint.activate([
            modeStack.topAnchor.constraint(equalTo: modeCard.topAnchor, constant: 16),
            modeStack.leadingAnchor.constraint(equalTo: modeCard.leadingAnchor, constant: 16),
            modeStack.trailingAnchor.constraint(equalTo: modeCard.trailingAnchor, constant: -16),
            modeStack.bottomAnchor.constraint(equalTo: modeCard.bottomAnchor, constant: -16)
        ])
        contentStack.addArrangedSubview(modeCard)

        // === Hotkeys Card ===
        let hotkeyCard = createCard()
        let hotkeyStack = NSStackView()
        hotkeyStack.orientation = .vertical
        hotkeyStack.spacing = 8
        hotkeyStack.translatesAutoresizingMaskIntoConstraints = false
        hotkeyCard.addSubview(hotkeyStack)

        let hotkeyHeader = createSectionHeader("Keyboard Shortcuts")
        hotkeyStack.addArrangedSubview(hotkeyHeader)

        for action in HotkeyAction.allCases {
            let row = createHotkeyRow(for: action)
            hotkeyStack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            hotkeyStack.topAnchor.constraint(equalTo: hotkeyCard.topAnchor, constant: 16),
            hotkeyStack.leadingAnchor.constraint(equalTo: hotkeyCard.leadingAnchor, constant: 16),
            hotkeyStack.trailingAnchor.constraint(equalTo: hotkeyCard.trailingAnchor, constant: -16),
            hotkeyStack.bottomAnchor.constraint(equalTo: hotkeyCard.bottomAnchor, constant: -16)
        ])
        contentStack.addArrangedSubview(hotkeyCard)

        // === Excluded Apps Card ===
        let excludeCard = createCard()
        let excludeStack = NSStackView()
        excludeStack.orientation = .vertical
        excludeStack.spacing = 8
        excludeStack.translatesAutoresizingMaskIntoConstraints = false
        excludeCard.addSubview(excludeStack)

        let excludeHeader = createSectionHeader("Hide from Preview")
        excludeStack.addArrangedSubview(excludeHeader)

        // Self-hiding toggle row
        let selfHideRow = NSView()
        selfHideRow.translatesAutoresizingMaskIntoConstraints = false

        hideSelfToggle = NSButton(checkboxWithTitle: "Hide Cloak window from its own preview", target: self, action: #selector(hideSelfToggleChanged))
        hideSelfToggle.state = hideSelfFromPreview ? .on : .off
        hideSelfToggle.font = NSFont.systemFont(ofSize: 12)
        hideSelfToggle.translatesAutoresizingMaskIntoConstraints = false
        selfHideRow.addSubview(hideSelfToggle)

        NSLayoutConstraint.activate([
            selfHideRow.heightAnchor.constraint(equalToConstant: 20),
            hideSelfToggle.leadingAnchor.constraint(equalTo: selfHideRow.leadingAnchor),
            hideSelfToggle.centerYAnchor.constraint(equalTo: selfHideRow.centerYAnchor)
        ])
        excludeStack.addArrangedSubview(selfHideRow)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        excludeStack.addArrangedSubview(separator)

        let excludeAppsLabel = NSTextField(labelWithString: "Hide other apps:")
        excludeAppsLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        excludeAppsLabel.textColor = .secondaryLabelColor
        excludeStack.addArrangedSubview(excludeAppsLabel)

        // Add app row
        let addAppRow = NSView()
        addAppRow.translatesAutoresizingMaskIntoConstraints = false

        appNameField = NSTextField(frame: .zero)
        appNameField.placeholderString = "App name (e.g., Slack)"
        appNameField.translatesAutoresizingMaskIntoConstraints = false
        appNameField.controlSize = .small
        appNameField.font = NSFont.systemFont(ofSize: 12)
        addAppRow.addSubview(appNameField)

        let addButton = NSButton(title: "Add", target: self, action: #selector(addExcludedApp))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addAppRow.addSubview(addButton)

        NSLayoutConstraint.activate([
            addAppRow.heightAnchor.constraint(equalToConstant: 24),
            appNameField.leadingAnchor.constraint(equalTo: addAppRow.leadingAnchor),
            appNameField.centerYAnchor.constraint(equalTo: addAppRow.centerYAnchor),
            appNameField.widthAnchor.constraint(equalToConstant: 200),
            addButton.leadingAnchor.constraint(equalTo: appNameField.trailingAnchor, constant: 8),
            addButton.centerYAnchor.constraint(equalTo: addAppRow.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: addAppRow.trailingAnchor)
        ])
        excludeStack.addArrangedSubview(addAppRow)

        excludedAppsStack = NSStackView()
        excludedAppsStack.orientation = .vertical
        excludedAppsStack.spacing = 4
        excludedAppsStack.alignment = .leading
        excludeStack.addArrangedSubview(excludedAppsStack)

        NSLayoutConstraint.activate([
            excludeStack.topAnchor.constraint(equalTo: excludeCard.topAnchor, constant: 16),
            excludeStack.leadingAnchor.constraint(equalTo: excludeCard.leadingAnchor, constant: 16),
            excludeStack.trailingAnchor.constraint(equalTo: excludeCard.trailingAnchor, constant: -16),
            excludeStack.bottomAnchor.constraint(equalTo: excludeCard.bottomAnchor, constant: -16)
        ])
        contentStack.addArrangedSubview(excludeCard)

        // === Start Button ===
        let startButton = NSButton(title: "Start Sharing", target: self, action: #selector(startClicked))
        startButton.bezelStyle = .rounded
        startButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        startButton.contentTintColor = .systemGreen
        startButton.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(startButton)

        // Instructions
        let instructionsLabel = NSTextField(labelWithString: "Share the 'Cloak' window in Zoom/Meet, then use hotkeys to toggle privacy")
        instructionsLabel.font = NSFont.systemFont(ofSize: 11)
        instructionsLabel.textColor = .tertiaryLabelColor
        instructionsLabel.alignment = .center
        instructionsLabel.maximumNumberOfLines = 2
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(instructionsLabel)

        // Card width constraints
        NSLayoutConstraint.activate([
            modeCard.widthAnchor.constraint(equalToConstant: 320),
            hotkeyCard.widthAnchor.constraint(equalToConstant: 320),
            excludeCard.widthAnchor.constraint(equalToConstant: 320),
            startButton.widthAnchor.constraint(equalToConstant: 180),
            startButton.heightAnchor.constraint(equalToConstant: 40),
            instructionsLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])

        // Scroll view and content constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            contentStack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
        ])
    }

    private func createHotkeyRow(for action: HotkeyAction) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: action.displayName)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        let button = NSButton(title: "Click to set", target: self, action: #selector(hotkeyButtonClicked(_:)))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        button.tag = action.rawValue
        button.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(button)
        hotkeyButtons[action] = button

        let clearButton = NSButton(title: "✕", target: self, action: #selector(clearHotkeyClicked(_:)))
        clearButton.bezelStyle = .inline
        clearButton.tag = action.rawValue
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(clearButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 30),

            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 130),

            button.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 150),

            clearButton.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 5),
            clearButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: row.trailingAnchor)
        ])

        return row
    }

    @objc private func modeChanged() {
        switch modeSegmented.selectedSegment {
        case 0: selectedMode = .blur
        case 1: selectedMode = .image
        case 2: selectedMode = .black
        default: selectedMode = .blur
        }
        UserDefaults.standard.set(selectedMode.rawValue, forKey: "privacyMode")
        updateModeSettingsVisibility()
        onSettingsChanged?()
    }

    @objc private func blurSliderChanged() {
        blurIntensity = blurSlider.doubleValue
        blurValueLabel.stringValue = "\(Int(blurIntensity))"
        UserDefaults.standard.set(blurIntensity, forKey: "blurIntensity")
        onSettingsChanged?()
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                self?.customImage = image
                self?.imageWell.image = image
                UserDefaults.standard.set(url.path, forKey: "customImagePath")
                self?.onSettingsChanged?()
            }
        }
    }

    @objc private func hotkeyButtonClicked(_ sender: NSButton) {
        guard let action = HotkeyAction(rawValue: sender.tag) else { return }

        // Cancel any existing recording
        stopRecording()

        recordingAction = action
        sender.title = "Press keys..."

        // Start listening for key events
        globalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, let action = self.recordingAction else { return event }

            if event.type == .keyDown {
                let keyCode = UInt32(event.keyCode)
                var modifiers: UInt32 = 0

                if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
                if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
                if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
                if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }

                // Require at least one modifier
                if modifiers != 0 {
                    self.hotkeyManager?.setHotkey(for: action, keyCode: keyCode, modifiers: modifiers)
                    self.stopRecording()
                    self.updateHotkeyLabels()
                }

                return nil
            }

            return event
        }
    }

    @objc private func clearHotkeyClicked(_ sender: NSButton) {
        guard let action = HotkeyAction(rawValue: sender.tag) else { return }
        hotkeyManager?.removeHotkey(for: action)
        updateHotkeyLabels()
    }

    private func stopRecording() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        recordingAction = nil
        updateHotkeyLabels()
    }

    @objc private func hideSelfToggleChanged() {
        hideSelfFromPreview = hideSelfToggle.state == .on
        UserDefaults.standard.set(hideSelfFromPreview, forKey: "hideSelfFromPreview")
        onSettingsChanged?()
    }

    @objc private func addExcludedApp() {
        let appName = appNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appName.isEmpty else { return }
        guard !excludedApps.contains(where: { $0.lowercased() == appName.lowercased() }) else { return }

        excludedApps.append(appName)
        appNameField.stringValue = ""
        saveExcludedApps()
    }

    @objc private func removeExcludedApp(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < excludedApps.count else { return }

        excludedApps.remove(at: index)
        saveExcludedApps()
    }

    private func refreshExcludedAppsList() {
        // Remove all existing rows
        for view in excludedAppsStack.arrangedSubviews {
            excludedAppsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Add rows for each excluded app
        for (index, appName) in excludedApps.enumerated() {
            let row = NSView()
            row.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: appName)
            label.font = NSFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)

            let removeButton = NSButton(title: "✕", target: self, action: #selector(removeExcludedApp(_:)))
            removeButton.bezelStyle = .inline
            removeButton.tag = index
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(removeButton)

            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 24),
                row.widthAnchor.constraint(equalToConstant: 300),
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                removeButton.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                removeButton.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])

            excludedAppsStack.addArrangedSubview(row)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateHotkeyLabels()
        refreshExcludedAppsList()
        // Update blur slider from loaded settings
        blurSlider?.doubleValue = blurIntensity
        blurValueLabel?.stringValue = "\(Int(blurIntensity))"
        // Update self-hide toggle
        hideSelfToggle?.state = hideSelfFromPreview ? .on : .off
    }

    @objc private func startClicked() {
        onStart?()
    }
}

// MARK: - Protocols and Enums

protocol ScreenCaptureEngineDelegate: AnyObject {
    func privacyStateDidChange(isPrivate: Bool)
    func didReceiveFrame(_ frame: CVImageBuffer)
}

enum PrivacyMode: String, CaseIterable {
    case blur = "Blur"
    case image = "Custom Image"
    case black = "Black Screen"
}

// MARK: - Screen Capture Engine

class ScreenCaptureEngine: NSObject {
    private var stream: SCStream?
    var previewView: PreviewView
    var isPrivacyEnabled = false
    var currentPrivacyMode: PrivacyMode = .blur
    weak var delegate: ScreenCaptureEngineDelegate?
    private var windowsToExclude: [NSWindow]
    private var appNamesToExclude: [String]
    private var currentDisplay: SCDisplay?
    private var workspaceObservers: [NSObjectProtocol] = []

    init(previewView: PreviewView, excludingWindows: [NSWindow] = [], excludingApps: [String] = []) {
        self.previewView = previewView
        self.windowsToExclude = excludingWindows
        self.appNamesToExclude = excludingApps
        super.init()
        loadSettings()
        setupWorkspaceObservers()
    }

    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        // Observe app launches - refresh filter when any app launches
        let launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Small delay to let the window appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.refreshExcludedApps()
            }
        }
        workspaceObservers.append(launchObserver)

        // Also observe when apps become active (window might appear)
        let activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshExcludedApps()
        }
        workspaceObservers.append(activateObserver)

        // Observe when windows might have changed
        let unhideObserver = center.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshExcludedApps()
        }
        workspaceObservers.append(unhideObserver)
    }

    private func removeWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "privacyMode"),
           let mode = PrivacyMode(rawValue: modeString) {
            currentPrivacyMode = mode
        }

        if let imagePath = UserDefaults.standard.string(forKey: "customImagePath"),
           let image = NSImage(contentsOfFile: imagePath) {
            previewView.customImage = image
        }

        // Load blur intensity
        if UserDefaults.standard.object(forKey: "blurIntensity") != nil {
            previewView.blurIntensity = UserDefaults.standard.double(forKey: "blurIntensity")
        }

        previewView.privacyMode = currentPrivacyMode
    }

    func startCapture() {
        Task {
            do {
                try await requestPermission()
                try await setupStream()
            } catch {
                print("Failed to start capture: \(error)")
                DispatchQueue.main.async {
                    self.showPermissionAlert()
                }
            }
        }
    }

    func stopCapture() {
        removeWorkspaceObservers()
        Task {
            try? await stream?.stopCapture()
            stream = nil
        }
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Cloak needs Screen Recording permission to capture your screen.\n\n1. Open System Settings\n2. Go to Privacy & Security → Screen Recording\n3. Enable Cloak\n4. Restart the app"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    func requestPermission() async throws {
        guard try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true).displays.isEmpty == false else {
            throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No displays available"])
        }
    }

    func setupStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        currentDisplay = display

        let filter = try await buildContentFilter(display: display)

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(display.width)
        streamConfig.height = Int(display.height)
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        streamConfig.queueDepth = 5

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)

        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await stream?.startCapture()
    }

    private func buildContentFilter(display: SCDisplay) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find SCWindows matching the NSWindows we want to exclude
        let windowIDsToExclude = windowsToExclude.compactMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil }
        var scWindowsToExclude = content.windows.filter { windowIDsToExclude.contains($0.windowID) }

        // Also exclude windows from apps by name (case-insensitive partial match)
        let lowercasedAppNames = appNamesToExclude.map { $0.lowercased() }
        for window in content.windows {
            if let appName = window.owningApplication?.applicationName.lowercased() {
                for excludeName in lowercasedAppNames {
                    if appName.contains(excludeName) && !scWindowsToExclude.contains(where: { $0.windowID == window.windowID }) {
                        scWindowsToExclude.append(window)
                        break
                    }
                }
            }
        }

        return SCContentFilter(display: display, excludingWindows: scWindowsToExclude)
    }

    private func refreshExcludedApps() {
        guard let display = currentDisplay, let stream = stream else { return }

        Task {
            do {
                let newFilter = try await buildContentFilter(display: display)
                try await stream.updateContentFilter(newFilter)
            } catch {
                // Silently ignore refresh errors
            }
        }
    }

    func togglePrivacy() {
        isPrivacyEnabled.toggle()
        // Update preview immediately (no async delay)
        previewView.isPrivacyEnabled = isPrivacyEnabled
        previewView.privacyMode = currentPrivacyMode
        previewView.needsDisplay = true
        // Notify delegate
        delegate?.privacyStateDidChange(isPrivate: isPrivacyEnabled)
    }

    private func updatePreview() {
        DispatchQueue.main.async {
            self.previewView.isPrivacyEnabled = self.isPrivacyEnabled
            self.previewView.privacyMode = self.currentPrivacyMode
            self.previewView.needsDisplay = true
        }
    }
}

extension ScreenCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}

extension ScreenCaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Always send frames - PreviewView handles blur overlay when privacy is enabled
        DispatchQueue.main.async {
            self.previewView.updateFrame(imageBuffer)
            // Notify delegate for PiP updates
            self.delegate?.didReceiveFrame(imageBuffer)
        }
    }
}

// MARK: - Preview View

class PreviewView: NSView {
    var currentFrame: CVImageBuffer?
    var isPrivacyEnabled = false
    var privacyMode: PrivacyMode = .blur
    var customImage: NSImage?
    var blurIntensity: Double = 50.0  // 0-100 scale
    private let ciContext = CIContext()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        currentFrame = nil
        isPrivacyEnabled = false
        needsDisplay = true
    }

    func updateFrame(_ imageBuffer: CVImageBuffer) {
        currentFrame = imageBuffer
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if isPrivacyEnabled {
            drawPrivacyScreen(in: context)
        } else if let imageBuffer = currentFrame {
            drawScreenCapture(imageBuffer, in: context)
        } else {
            drawWaiting(in: context)
        }
    }

    private func drawScreenCapture(_ imageBuffer: CVImageBuffer, in context: CGContext) {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let ciContext = CIContext()

        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            context.draw(cgImage, in: bounds)
        }
    }

    private func drawPrivacyScreen(in context: CGContext) {
        switch privacyMode {
        case .black:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)

        case .blur:
            // Apply real-time Gaussian blur to the live frame
            if let frameToBlur = currentFrame {
                let ciImage = CIImage(cvImageBuffer: frameToBlur)

                if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                    blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    blurFilter.setValue(blurIntensity, forKey: kCIInputRadiusKey)

                    if let outputImage = blurFilter.outputImage {
                        // Crop to original size (blur expands the image)
                        let croppedImage = outputImage.cropped(to: ciImage.extent)
                        if let blurredCGImage = ciContext.createCGImage(croppedImage, from: ciImage.extent) {
                            context.draw(blurredCGImage, in: bounds)
                            return
                        }
                    }
                }
            }
            // Fallback: gray screen if no frame
            context.setFillColor(NSColor.darkGray.cgColor)
            context.fill(bounds)

        case .image:
            if let image = customImage {
                context.setFillColor(NSColor.black.cgColor)
                context.fill(bounds)

                let imageSize = image.size
                let aspectRatio = imageSize.width / imageSize.height
                let viewAspectRatio = bounds.width / bounds.height

                var drawRect: CGRect
                if aspectRatio > viewAspectRatio {
                    let height = bounds.width / aspectRatio
                    drawRect = CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
                } else {
                    let width = bounds.height * aspectRatio
                    drawRect = CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: bounds.height)
                }

                image.draw(in: drawRect)
            } else {
                context.setFillColor(NSColor.darkGray.cgColor)
                context.fill(bounds)
            }
        }
    }

    private func drawWaiting(in context: CGContext) {
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        drawCenteredText("Starting screen capture...", fontSize: 24, color: .white, in: context)
    }

    private func drawCenteredText(_ text: String, fontSize: CGFloat, color: NSColor, in context: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .light),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }
}

// MARK: - HUD Window

class HUDWindow: NSWindow {
    private let label = NSTextField()
    private let iconView = NSImageView()
    private let previewImageView = NSImageView()
    private var hideTimer: Timer?
    private let ciContext = CIContext()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver  // Show above fullscreen apps
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.sharingType = .none  // Hide from all screen capture

        setupUI()
    }

    func setupUI() {
        // Liquid glass effect using NSVisualEffectView
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 220, height: 100))
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.layer?.masksToBounds = true

        // Preview thumbnail (16:10 aspect ratio, centered vertically on left)
        let previewHeight: CGFloat = 56
        let previewWidth: CGFloat = 90  // ~16:10 ratio
        let previewY = (100 - previewHeight) / 2
        previewImageView.frame = NSRect(x: 14, y: previewY, width: previewWidth, height: previewHeight)
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 8
        previewImageView.layer?.masksToBounds = true
        previewImageView.layer?.borderWidth = 1
        previewImageView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffectView.addSubview(previewImageView)

        // Right side container for icon + label (centered vertically)
        let rightX: CGFloat = 114
        let groupHeight: CGFloat = 50
        let groupY = (100 - groupHeight) / 2

        // Icon (centered in group)
        iconView.frame = NSRect(x: rightX + 20, y: groupY + 24, width: 24, height: 24)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        visualEffectView.addSubview(iconView)

        // Label (below icon, centered)
        label.frame = NSRect(x: rightX, y: groupY, width: 92, height: 22)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .labelColor
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        visualEffectView.addSubview(label)

        contentView = visualEffectView
    }

    func show(isPrivate: Bool, previewFrame: CVImageBuffer? = nil, blurIntensity: Double = 50.0, privacyMode: PrivacyMode = .blur, customImage: NSImage? = nil) {
        hideTimer?.invalidate()

        if isPrivate {
            iconView.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: nil)
            label.stringValue = "Privacy ON"
        } else {
            iconView.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)
            label.stringValue = "Privacy OFF"
        }

        iconView.contentTintColor = isPrivate ? .systemRed : .systemGreen

        // Update preview thumbnail
        updatePreviewThumbnail(frame: previewFrame, isPrivate: isPrivate, blurIntensity: blurIntensity, privacyMode: privacyMode, customImage: customImage)

        // Position at bottom center
        if let screen = NSScreen.main {
            let x = (screen.frame.width - frame.width) / 2
            let y: CGFloat = 120  // 120 points from bottom
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 1.0
        })

        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func updatePreviewThumbnail(frame: CVImageBuffer?, isPrivate: Bool, blurIntensity: Double, privacyMode: PrivacyMode, customImage: NSImage?) {
        guard let frame = frame else {
            previewImageView.image = nil
            return
        }

        var ciImage = CIImage(cvImageBuffer: frame)

        if isPrivate {
            switch privacyMode {
            case .blur:
                if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                    blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    blurFilter.setValue(blurIntensity, forKey: kCIInputRadiusKey)
                    if let output = blurFilter.outputImage {
                        ciImage = output.cropped(to: CIImage(cvImageBuffer: frame).extent)
                    }
                }
            case .black:
                previewImageView.image = NSImage(size: NSSize(width: 80, height: 50), flipped: false) { rect in
                    NSColor.black.setFill()
                    rect.fill()
                    return true
                }
                return
            case .image:
                if let img = customImage {
                    previewImageView.image = img
                    return
                }
            }
        }

        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            previewImageView.image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

// MARK: - PiP Window

class PiPWindow: NSWindow {
    private let previewImageView = NSImageView()
    private let ciContext = CIContext()
    private var blurIntensity: Double = 50.0

    init() {
        // Default size with 16:10 aspect ratio
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 320, height: 200),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = "Preview"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .screenSaver  // Show above fullscreen apps
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.sharingType = .none  // Hide from all screen capture
        self.minSize = NSSize(width: 160, height: 100)
        self.aspectRatio = NSSize(width: 16, height: 10)  // Lock aspect ratio

        setupUI()
        positionWindow()
    }

    private func setupUI() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor

        previewImageView.frame = containerView.bounds
        previewImageView.autoresizingMask = [.width, .height]
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(previewImageView)

        contentView = containerView
    }

    private func positionWindow() {
        // Position at bottom right corner
        if let screen = NSScreen.main {
            let x = screen.frame.width - frame.width - 20
            let y: CGFloat = 80
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show() {
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    func updateFrame(_ frame: CVImageBuffer, isPrivacyEnabled: Bool, privacyMode: PrivacyMode, blurIntensity: Double = 50.0, customImage: NSImage? = nil) {
        self.blurIntensity = blurIntensity

        var ciImage = CIImage(cvImageBuffer: frame)

        if isPrivacyEnabled {
            switch privacyMode {
            case .blur:
                if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                    blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    blurFilter.setValue(blurIntensity, forKey: kCIInputRadiusKey)
                    if let output = blurFilter.outputImage {
                        ciImage = output.cropped(to: CIImage(cvImageBuffer: frame).extent)
                    }
                }
            case .black:
                previewImageView.image = NSImage(size: previewImageView.bounds.size, flipped: false) { rect in
                    NSColor.black.setFill()
                    rect.fill()
                    return true
                }
                return
            case .image:
                if let img = customImage {
                    previewImageView.image = img
                    return
                }
            }
        }

        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            previewImageView.image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
}

// MARK: - Settings Panel (for live settings during capture)

class SettingsPanel: NSVisualEffectView {
    var onSettingsChanged: (() -> Void)?
    var onClose: (() -> Void)?
    weak var hotkeyManager: HotkeyManager?

    private let modeSegmented = NSSegmentedControl()
    private var selectedMode: PrivacyMode = .blur

    // Mode-specific containers
    private var blurSettingsContainer: NSView!
    private var imageSettingsContainer: NSView!

    // Blur settings
    private var blurIntensity: Double = 50.0
    private var blurSlider: NSSlider!
    private var blurValueLabel: NSTextField!

    // Image settings
    private let imageWell = NSImageView()
    private var customImage: NSImage?

    // Self-hiding (display only, requires restart to take effect)
    private var hideSelfFromPreview: Bool = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupPanel()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "privacyMode"),
           let mode = PrivacyMode(rawValue: modeString) {
            selectedMode = mode
            switch mode {
            case .blur: modeSegmented.selectedSegment = 0
            case .image: modeSegmented.selectedSegment = 1
            case .black: modeSegmented.selectedSegment = 2
            }
        }

        if UserDefaults.standard.object(forKey: "blurIntensity") != nil {
            blurIntensity = UserDefaults.standard.double(forKey: "blurIntensity")
        }

        if let imagePath = UserDefaults.standard.string(forKey: "customImagePath"),
           let image = NSImage(contentsOfFile: imagePath) {
            customImage = image
            imageWell.image = image
        }

        updateModeSettingsVisibility()
    }

    func syncFromStartScreen(_ startScreen: StartScreenView) {
        selectedMode = startScreen.getSelectedMode()
        blurIntensity = startScreen.getBlurIntensity()
        customImage = startScreen.getCustomImage()
        hideSelfFromPreview = startScreen.getHideSelfFromPreview()

        switch selectedMode {
        case .blur: modeSegmented.selectedSegment = 0
        case .image: modeSegmented.selectedSegment = 1
        case .black: modeSegmented.selectedSegment = 2
        }

        blurSlider?.doubleValue = blurIntensity
        blurValueLabel?.stringValue = "\(Int(blurIntensity))"
        imageWell.image = customImage

        updateModeSettingsVisibility()
    }

    private func updateModeSettingsVisibility() {
        blurSettingsContainer?.isHidden = selectedMode != .blur
        imageSettingsContainer?.isHidden = selectedMode != .image
    }

    private func setupPanel() {
        material = .hudWindow
        state = .active
        blendingMode = .behindWindow
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

        // Close button
        let closeButton = NSButton(frame: NSRect(x: 280, y: 164, width: 28, height: 28))
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.contentTintColor = .secondaryLabelColor
        addSubview(closeButton)

        // Title
        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 16, y: 164, width: 200, height: 20)
        addSubview(titleLabel)

        // Privacy Mode section
        let modeLabel = NSTextField(labelWithString: "Privacy Mode")
        modeLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        modeLabel.textColor = .secondaryLabelColor
        modeLabel.frame = NSRect(x: 16, y: 130, width: 100, height: 16)
        addSubview(modeLabel)

        modeSegmented.segmentCount = 3
        modeSegmented.setLabel("Blur", forSegment: 0)
        modeSegmented.setLabel("Image", forSegment: 1)
        modeSegmented.setLabel("Black", forSegment: 2)
        modeSegmented.selectedSegment = 0
        modeSegmented.segmentStyle = .automatic
        modeSegmented.target = self
        modeSegmented.action = #selector(modeChanged)
        modeSegmented.frame = NSRect(x: 16, y: 100, width: 288, height: 24)
        addSubview(modeSegmented)

        // Blur settings container
        blurSettingsContainer = NSView(frame: NSRect(x: 16, y: 16, width: 288, height: 70))
        addSubview(blurSettingsContainer)

        let blurLabel = NSTextField(labelWithString: "Blur Intensity")
        blurLabel.font = NSFont.systemFont(ofSize: 12)
        blurLabel.textColor = .secondaryLabelColor
        blurLabel.frame = NSRect(x: 0, y: 40, width: 90, height: 16)
        blurSettingsContainer.addSubview(blurLabel)

        blurSlider = NSSlider(value: blurIntensity, minValue: 5, maxValue: 100, target: self, action: #selector(blurSliderChanged))
        blurSlider.frame = NSRect(x: 0, y: 10, width: 240, height: 20)
        blurSettingsContainer.addSubview(blurSlider)

        blurValueLabel = NSTextField(labelWithString: "\(Int(blurIntensity))")
        blurValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        blurValueLabel.textColor = .white
        blurValueLabel.alignment = .right
        blurValueLabel.frame = NSRect(x: 250, y: 10, width: 38, height: 20)
        blurSettingsContainer.addSubview(blurValueLabel)

        // Image settings container
        imageSettingsContainer = NSView(frame: NSRect(x: 16, y: 16, width: 288, height: 70))
        imageSettingsContainer.isHidden = true
        addSubview(imageSettingsContainer)

        imageWell.wantsLayer = true
        imageWell.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        imageWell.layer?.cornerRadius = 6
        imageWell.layer?.borderWidth = 1
        imageWell.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        imageWell.imageScaling = .scaleProportionallyUpOrDown
        imageWell.frame = NSRect(x: 0, y: 26, width: 200, height: 44)
        imageSettingsContainer.addSubview(imageWell)

        let chooseButton = NSButton(title: "Choose", target: self, action: #selector(chooseImage))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .small
        chooseButton.frame = NSRect(x: 210, y: 32, width: 78, height: 24)
        imageSettingsContainer.addSubview(chooseButton)
    }

    @objc private func closeClicked() {
        onClose?()
    }

    @objc private func modeChanged() {
        switch modeSegmented.selectedSegment {
        case 0: selectedMode = .blur
        case 1: selectedMode = .image
        case 2: selectedMode = .black
        default: selectedMode = .blur
        }
        UserDefaults.standard.set(selectedMode.rawValue, forKey: "privacyMode")
        updateModeSettingsVisibility()
        onSettingsChanged?()
    }

    @objc private func blurSliderChanged() {
        blurIntensity = blurSlider.doubleValue
        blurValueLabel.stringValue = "\(Int(blurIntensity))"
        UserDefaults.standard.set(blurIntensity, forKey: "blurIntensity")
        onSettingsChanged?()
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                self?.customImage = image
                self?.imageWell.image = image
                UserDefaults.standard.set(url.path, forKey: "customImagePath")
                self?.onSettingsChanged?()
            }
        }
    }
}
