import Cocoa
import ScreenCaptureKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var settingsWindow: NSWindow?
    var captureEngine: ScreenCaptureEngine?
    var statusItem: NSStatusItem!
    var hudWindow: HUDWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMainWindow()
        captureEngine = ScreenCaptureEngine(previewView: window.contentView as! PreviewView)
        captureEngine?.delegate = self
        captureEngine?.startCapture()
        setupHotKey()
        NSApp.activate(ignoringOtherApps: true)
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
            button.image = NSImage(systemSymbolName: isPrivate ? "eye.slash.fill" : "eye.fill",
                                  accessibilityDescription: "Cloak")
        }
    }
    
    @objc func statusBarClicked() {
        let menu = NSMenu()
        
        let statusTitle = captureEngine?.isPrivacyEnabled ?? false ? "🔒 Privacy: ON" : "👁️ Privacy: OFF"
        let menuStatusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        menuStatusItem.isEnabled = false
        menu.addItem(menuStatusItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Privacy (⌘⌥H)", action: #selector(togglePrivacy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Cloak Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Cloak", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Cloak", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.popUpMenu(menu)
    }
    
    func setupMainWindow() {
        let windowRect = NSRect(x: 100, y: 100, width: 1280, height: 720)
        
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Cloak - Share This Window"
        window.contentView = PreviewView(frame: windowRect)
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 360)
        
        setupMenuBar()
    }
    
    func setupMenuBar() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "About Cloak", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Cloak", action: #selector(quit), keyEquivalent: "q"))
        
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        let privacyItem = NSMenuItem(title: "Toggle Privacy", action: #selector(togglePrivacy), keyEquivalent: "h")
        privacyItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(privacyItem)
        viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(toggleFullScreen), keyEquivalent: "f"))
        
        NSApp.mainMenu = mainMenu
    }
    
    func setupHotKey() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Cmd+Option+H to toggle privacy
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.option) &&
               event.charactersIgnoringModifiers == "h" {
                self.togglePrivacy()
                return nil
            }
            return event
        }
    }
    
    @objc func togglePrivacy() {
        captureEngine?.togglePrivacy()
        showHUD(isPrivate: captureEngine?.isPrivacyEnabled ?? false)
    }
    
    @objc func toggleFullScreen() {
        window.toggleFullScreen(nil)
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsVC = SettingsViewController()
            settingsVC.captureEngine = captureEngine
            
            settingsWindow = NSWindow(contentViewController: settingsVC)
            settingsWindow?.title = "Cloak Settings"
            settingsWindow?.styleMask = [.titled, .closable]
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Cloak"
        alert.informativeText = "Hide your screen during video calls.\n\nPress ⌘H to toggle privacy mode.\nShare the Cloak window in Zoom/Meet, not your entire screen.\n\nYour screen stays normal while viewers see the privacy overlay."
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
        hudWindow?.show(isPrivate: isPrivate)
    }
}

extension AppDelegate: ScreenCaptureEngineDelegate {
    func privacyStateDidChange(isPrivate: Bool) {
        updateStatusBarIcon(isPrivate: isPrivate)
    }
}

protocol ScreenCaptureEngineDelegate: AnyObject {
    func privacyStateDidChange(isPrivate: Bool)
}

enum PrivacyMode: String, CaseIterable {
    case blur = "Blur"
    case image = "Custom Image"
    case black = "Black Screen"
}

class ScreenCaptureEngine: NSObject {
    private var stream: SCStream?
    var previewView: PreviewView
    var isPrivacyEnabled = false
    var currentPrivacyMode: PrivacyMode = .blur
    weak var delegate: ScreenCaptureEngineDelegate?
    
    init(previewView: PreviewView) {
        self.previewView = previewView
        super.init()
        loadSettings()
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
    }
    
    func saveSettings() {
        UserDefaults.standard.set(currentPrivacyMode.rawValue, forKey: "privacyMode")
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
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(display.width)
        streamConfig.height = Int(display.height)
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        streamConfig.queueDepth = 5
        
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await stream?.startCapture()
    }
    
    func togglePrivacy() {
        isPrivacyEnabled.toggle()
        delegate?.privacyStateDidChange(isPrivate: isPrivacyEnabled)
        updatePreview()
    }
    
    func setPrivacyMode(_ mode: PrivacyMode) {
        currentPrivacyMode = mode
        saveSettings()
        updatePreview()
    }
    
    func setCustomImage(_ image: NSImage, path: String) {
        previewView.customImage = image
        UserDefaults.standard.set(path, forKey: "customImagePath")
        updatePreview()
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
        
        DispatchQueue.main.async {
            if !self.isPrivacyEnabled {
                self.previewView.updateFrame(imageBuffer)
            }
        }
    }
}

class PreviewView: NSView {
    var currentFrame: CVImageBuffer?
    var isPrivacyEnabled = false
    var privacyMode: PrivacyMode = .blur
    var customImage: NSImage?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            drawPlaceholder(in: context)
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
            drawCenteredText("🔒 Privacy Mode Active", fontSize: 48, color: .white, in: context)
            
        case .blur:
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
            
            context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
            for y in stride(from: 0, to: bounds.height, by: 40) {
                context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 20))
            }
            
            drawCenteredText("🔒 Screen Hidden", fontSize: 48, color: NSColor.gray.withAlphaComponent(0.5), in: context)
            
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
                drawCenteredText("No Custom Image\nChoose one in Settings", fontSize: 36, color: .white, in: context)
            }
        }
    }
    
    private func drawPlaceholder(in context: CGContext) {
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        drawCenteredText("Initializing Screen Capture...\n\nIf this persists, grant Screen Recording\npermission in System Settings", fontSize: 24, color: .white, in: context)
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

class SettingsViewController: NSViewController {
    weak var captureEngine: ScreenCaptureEngine?
    
    private let modeSegmented = NSSegmentedControl()
    private let imageWell = NSImageView()
    private let chooseButton = NSButton()
    private let previewLabel = NSTextField()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let titleLabel = NSTextField(labelWithString: "Privacy Mode Settings")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: 340, width: 460, height: 30)
        view.addSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: "Choose what viewers see when privacy mode is active")
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: 310, width: 460, height: 20)
        view.addSubview(descLabel)
        
        let modeLabel = NSTextField(labelWithString: "Privacy Mode:")
        modeLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        modeLabel.frame = NSRect(x: 20, y: 270, width: 460, height: 20)
        view.addSubview(modeLabel)
        
        modeSegmented.segmentCount = 3
        modeSegmented.setLabel("Blur", forSegment: 0)
        modeSegmented.setLabel("Custom Image", forSegment: 1)
        modeSegmented.setLabel("Black Screen", forSegment: 2)
        modeSegmented.frame = NSRect(x: 20, y: 230, width: 460, height: 32)
        modeSegmented.target = self
        modeSegmented.action = #selector(modeChanged)
        
        if let mode = captureEngine?.currentPrivacyMode {
            switch mode {
            case .blur: modeSegmented.selectedSegment = 0
            case .image: modeSegmented.selectedSegment = 1
            case .black: modeSegmented.selectedSegment = 2
            }
        }
        
        view.addSubview(modeSegmented)
        
        let imageLabel = NSTextField(labelWithString: "Custom Image:")
        imageLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        imageLabel.frame = NSRect(x: 20, y: 190, width: 460, height: 20)
        view.addSubview(imageLabel)
        
        imageWell.wantsLayer = true
        imageWell.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        imageWell.layer?.cornerRadius = 8
        imageWell.layer?.borderWidth = 1
        imageWell.layer?.borderColor = NSColor.separatorColor.cgColor
        imageWell.imageScaling = .scaleProportionallyUpOrDown
        imageWell.frame = NSRect(x: 20, y: 60, width: 460, height: 120)
        
        if let image = captureEngine?.previewView.customImage {
            imageWell.image = image
        }
        
        view.addSubview(imageWell)
        
        chooseButton.title = "Choose Image..."
        chooseButton.bezelStyle = .rounded
        chooseButton.frame = NSRect(x: 20, y: 20, width: 150, height: 32)
        chooseButton.target = self
        chooseButton.action = #selector(chooseImage)
        view.addSubview(chooseButton)
        
        previewLabel.stringValue = "Image will be centered and scaled to fit"
        previewLabel.font = NSFont.systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.frame = NSRect(x: 180, y: 26, width: 300, height: 20)
        view.addSubview(previewLabel)
    }
    
    @objc func modeChanged() {
        let mode: PrivacyMode
        switch modeSegmented.selectedSegment {
        case 0: mode = .blur
        case 1: mode = .image
        case 2: mode = .black
        default: mode = .blur
        }
        
        captureEngine?.setPrivacyMode(mode)
    }
    
    @objc func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                self.imageWell.image = image
                self.captureEngine?.setCustomImage(image, path: url.path)
            }
        }
    }
}

class HUDWindow: NSWindow {
    private let label = NSTextField()
    private let iconView = NSImageView()
    private var hideTimer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI()
    }
    
    func setupUI() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        containerView.layer?.cornerRadius = 16
        
        iconView.frame = NSRect(x: 60, y: 45, width: 80, height: 40)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(iconView)
        
        label.frame = NSRect(x: 10, y: 15, width: 180, height: 25)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .white
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        containerView.addSubview(label)
        
        contentView = containerView
    }
    
    func show(isPrivate: Bool) {
        hideTimer?.invalidate()
        
        if isPrivate {
            iconView.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: nil)
            label.stringValue = "Privacy ON"
        } else {
            iconView.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)
            label.stringValue = "Privacy OFF"
        }
        
        iconView.contentTintColor = isPrivate ? .systemRed : .systemGreen
        
        if let screen = NSScreen.main {
            let x = (screen.frame.width - frame.width) / 2
            let y = screen.frame.height - frame.height - 100
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        alphaValue = 0
        orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 1.0
        })
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.hide()
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
