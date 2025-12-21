import Cocoa
import ScreenCaptureKit
import AVFoundation
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var settingsWindow: NSWindow?
    var captureEngine: ScreenCaptureEngine?
    var statusItem: NSStatusItem!
    var hudWindow: HUDWindow?
    var mainView: MainView!
    var globalHotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMainWindow()
        setupGlobalHotKey()
        setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef = globalHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
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

        let isCapturing = captureEngine != nil
        let statusTitle = captureEngine?.isPrivacyEnabled ?? false ? "🔒 Privacy: ON" : "👁️ Privacy: OFF"
        let menuStatusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        menuStatusItem.isEnabled = false
        menu.addItem(menuStatusItem)

        menu.addItem(NSMenuItem.separator())

        if isCapturing {
            menu.addItem(NSMenuItem(title: "Toggle Privacy (⌘⌥H)", action: #selector(togglePrivacy), keyEquivalent: ""))
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
        let windowRect = NSRect(x: 100, y: 100, width: 1280, height: 720)

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
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]

        mainView = MainView(frame: windowRect)
        mainView.delegate = self
        window.contentView = mainView

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
        let privacyItem = NSMenuItem(title: "Toggle Privacy", action: #selector(togglePrivacy), keyEquivalent: "h")
        privacyItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(privacyItem)
        viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(toggleFullScreen), keyEquivalent: "f"))

        NSApp.mainMenu = mainMenu
    }

    func setupGlobalHotKey() {
        // Register global hotkey: Cmd+Option+H
        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4B00) // "CLK\0"
        hotKeyID.id = 1

        // h = 4 in virtual key codes
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            globalHotKeyRef = hotKeyRef
        }

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.togglePrivacy()
                    }
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    @objc func startCapture() {
        mainView.showCapturing()
        captureEngine = ScreenCaptureEngine(previewView: mainView.previewView)
        captureEngine?.delegate = self
        captureEngine?.startCapture()
    }

    @objc func stopCapture() {
        captureEngine?.stopCapture()
        captureEngine = nil
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

    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Cloak"
        alert.informativeText = "Hide your screen during video calls.\n\nPress ⌘⌥H to toggle privacy mode.\nShare the Cloak window in Zoom/Meet, not your entire screen.\n\nYour screen stays normal while viewers see the privacy overlay."
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

    func mainViewDidRequestSettings() {
        // Settings are now inline in the start screen
    }
}

// MARK: - Main View

protocol MainViewDelegate: AnyObject {
    func mainViewDidRequestStart()
    func mainViewDidRequestStop()
    func mainViewDidRequestTogglePrivacy()
    func mainViewDidRequestSettings()
}

class MainView: NSView {
    weak var delegate: MainViewDelegate?

    private var startScreenView: StartScreenView!
    var previewView: PreviewView!
    private var stopButton: NSButton!
    private var privacyButton: NSButton!
    private var controlsContainer: NSView!
    private var trackingArea: NSTrackingArea?

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
        addSubview(startScreenView)

        // Preview view (hidden initially)
        previewView = PreviewView(frame: bounds)
        previewView.autoresizingMask = [.width, .height]
        previewView.isHidden = true
        addSubview(previewView)

        // Controls container (shown on hover during capture)
        setupControls()
    }

    private func setupControls() {
        controlsContainer = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        controlsContainer.wantsLayer = true
        controlsContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        controlsContainer.layer?.cornerRadius = 12
        controlsContainer.isHidden = true
        addSubview(controlsContainer)

        // Stop button
        stopButton = NSButton(frame: NSRect(x: 10, y: 10, width: 80, height: 30))
        stopButton.title = "Stop"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.contentTintColor = .systemRed
        controlsContainer.addSubview(stopButton)

        // Privacy toggle button
        privacyButton = NSButton(frame: NSRect(x: 100, y: 10, width: 90, height: 30))
        privacyButton.title = "Privacy"
        privacyButton.bezelStyle = .rounded
        privacyButton.target = self
        privacyButton.action = #selector(privacyClicked)
        controlsContainer.addSubview(privacyButton)
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
            x: (bounds.width - 200) / 2,
            y: 20,
            width: 200,
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
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            controlsContainer.animator().alphaValue = 0
        }, completionHandler: {
            self.controlsContainer.isHidden = true
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
        previewView.reset()
    }

    @objc private func stopClicked() {
        delegate?.mainViewDidRequestStop()
    }

    @objc private func privacyClicked() {
        delegate?.mainViewDidRequestTogglePrivacy()
    }
}

// MARK: - Start Screen View

class StartScreenView: NSView {
    var onStart: (() -> Void)?

    private let modeSegmented = NSSegmentedControl()
    private let imageWell = NSImageView()
    private var selectedMode: PrivacyMode = .blur
    private var customImage: NSImage?

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
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        // Title
        let titleLabel = NSTextField(labelWithString: "Cloak")
        titleLabel.font = NSFont.systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Hide your screen during video calls")
        subtitleLabel.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // Privacy mode label
        let modeLabel = NSTextField(labelWithString: "Privacy Mode")
        modeLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        modeLabel.textColor = .white
        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeLabel)

        // Mode selector
        modeSegmented.segmentCount = 3
        modeSegmented.setLabel("Blur", forSegment: 0)
        modeSegmented.setLabel("Image", forSegment: 1)
        modeSegmented.setLabel("Black", forSegment: 2)
        modeSegmented.selectedSegment = 0
        modeSegmented.target = self
        modeSegmented.action = #selector(modeChanged)
        modeSegmented.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeSegmented)

        // Image well
        imageWell.wantsLayer = true
        imageWell.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.3).cgColor
        imageWell.layer?.cornerRadius = 8
        imageWell.layer?.borderWidth = 2
        imageWell.layer?.borderColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        imageWell.imageScaling = .scaleProportionallyUpOrDown
        imageWell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageWell)

        // Choose image button
        let chooseButton = NSButton(title: "Choose Image", target: self, action: #selector(chooseImage))
        chooseButton.bezelStyle = .rounded
        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chooseButton)

        // Start button
        let startButton = NSButton(title: "Start Sharing", target: self, action: #selector(startClicked))
        startButton.bezelStyle = .rounded
        startButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        startButton.contentTintColor = .systemGreen
        startButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(startButton)

        // Instructions
        let instructionsLabel = NSTextField(labelWithString: "1. Click 'Start Sharing'\n2. In Zoom/Meet, share the 'Cloak' window\n3. Press ⌘⌥H to toggle privacy mode")
        instructionsLabel.font = NSFont.systemFont(ofSize: 13)
        instructionsLabel.textColor = .secondaryLabelColor
        instructionsLabel.alignment = .center
        instructionsLabel.maximumNumberOfLines = 0
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionsLabel)

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 60),

            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),

            modeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            modeLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),

            modeSegmented.centerXAnchor.constraint(equalTo: centerXAnchor),
            modeSegmented.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 10),
            modeSegmented.widthAnchor.constraint(equalToConstant: 300),

            imageWell.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageWell.topAnchor.constraint(equalTo: modeSegmented.bottomAnchor, constant: 20),
            imageWell.widthAnchor.constraint(equalToConstant: 300),
            imageWell.heightAnchor.constraint(equalToConstant: 120),

            chooseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            chooseButton.topAnchor.constraint(equalTo: imageWell.bottomAnchor, constant: 10),

            startButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            startButton.topAnchor.constraint(equalTo: chooseButton.bottomAnchor, constant: 30),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 44),

            instructionsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            instructionsLabel.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 30),
            instructionsLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400)
        ])
    }

    @objc private func modeChanged() {
        switch modeSegmented.selectedSegment {
        case 0: selectedMode = .blur
        case 1: selectedMode = .image
        case 2: selectedMode = .black
        default: selectedMode = .blur
        }
        UserDefaults.standard.set(selectedMode.rawValue, forKey: "privacyMode")
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
            }
        }
    }

    @objc private func startClicked() {
        onStart?()
    }
}

// MARK: - Protocols and Enums

protocol ScreenCaptureEngineDelegate: AnyObject {
    func privacyStateDidChange(isPrivate: Bool)
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

// MARK: - Preview View

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
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)

            context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
            for y in stride(from: 0, to: bounds.height, by: 40) {
                context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 20))
            }

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
