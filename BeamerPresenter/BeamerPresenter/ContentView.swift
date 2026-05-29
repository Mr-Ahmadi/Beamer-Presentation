import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    private enum ImportKind {
        case pdf
        case notes
    }

    private struct ScreenOption: Identifiable {
        let id: Int
        let title: String
    }

    @EnvironmentObject var presentationManager: PresentationManager
    @Environment(\.openWindow) private var openWindow

    @State private var showingFileImporter = false
    @State private var activeImportKind: ImportKind = .pdf
    @State private var fullscreenWindow: NSWindow?
    @State private var fullscreenEventMonitor: Any?
    @State private var selectedScreenID: Int?
    @State private var windowID = UUID()
    @State private var isWindowRegistered = false

    private let presenterBackground = Color(red: 0.42, green: 0.42, blue: 0.42)
    private let phoneAccent = Color(red: 0.16, green: 0.58, blue: 0.93)

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(spacing: 24) {
                    controlsSection
                    transitionSection
                    displaySection
                    navigationSection
                    notesSection
                    nextSlideSection
                    connectionSection
                }
                .padding(.vertical, 8)
            }
            .frame(minWidth: 310, idealWidth: 340)
        } detail: {
            detailPane
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: importerTypes,
            allowsMultipleSelection: false
        ) { result in
            switch activeImportKind {
            case .pdf:
                handleFileImport(result, handler: presentationManager.loadPDF(url:))
            case .notes:
                handleFileImport(result, handler: presentationManager.loadTeXNotes(url:))
            }
        }
        .onChange(of: presentationManager.fullscreenOwnerID) { _, ownerID in
            if ownerID == windowID {
                openFullscreenWindow()
            } else {
                closeFullscreenWindow()
            }
        }
        .onAppear {
            registerWindowIfNeeded()
            presentationManager.markWindowActive(windowID)
        }
        .onDisappear {
            closeFullscreenWindow()
            presentationManager.unregisterWindow(windowID)
            isWindowRegistered = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            if let selectedScreenID, screen(withID: selectedScreenID) == nil {
                self.selectedScreenID = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let keyWindow = notification.object as? NSWindow else { return }
            if fullscreenWindow === keyWindow {
                return
            }
            presentationManager.markWindowActive(windowID)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            HStack(spacing: 10) {
                controlButton("Open PDF", icon: "doc.richtext", tint: .gray) {
                    activeImportKind = .pdf
                    showingFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)

                controlButton("Load Notes", icon: "note.text", tint: .gray) {
                    activeImportKind = .notes
                    showingFileImporter = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            .padding(.horizontal)

            if presentationManager.notesLoaded {
                HStack(spacing: 10) {
                    Label(presentationManager.notesSourceDisplayName, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Clear") {
                        presentationManager.clearNotes()
                    }
                    .buttonStyle(.borderless)
                    .tint(.gray)
                    .font(.caption)
                }
                .padding(.horizontal)
            }

            if presentationManager.pdfDocument != nil {
                HStack(spacing: 10) {
                    controlButton(
                        presentationManager.fullscreenOwnerID == windowID ? "Exit Fullscreen" : "Fullscreen",
                        icon: presentationManager.fullscreenOwnerID == windowID ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                        tint: .gray
                    ) {
                        toggleFullscreen()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(!presentationManager.canEnterFullscreen(from: windowID))

                    controlButton(
                        presentationManager.isBlackout ? "Disable Blackout" : "Blackout Slide",
                        icon: presentationManager.isBlackout ? "lightbulb.fill" : "lightbulb.slash",
                        tint: .gray
                    ) {
                        presentationManager.toggleBlackout()
                    }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                }
                .padding(.horizontal)
            }

            if presentationManager.isFullscreen, presentationManager.fullscreenOwnerID != windowID {
                Text("Another window is currently in fullscreen presentation mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transition")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Picker("Style", selection: $presentationManager.transitionStyle) {
                ForEach(SlideTransitionStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Picker("Fullscreen Screen", selection: $selectedScreenID) {
                Text("Auto (External Preferred)").tag(nil as Int?)
                ForEach(screenOptions) { option in
                    Text(option.title).tag(Optional(option.id))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            if screenOptions.count > 1 {
                HStack(spacing: 10) {
                    Button("Primary") {
                        selectedScreenID = primaryScreenID()
                    }
                    .tint(.gray)
                    
                    Button("External") {
                        selectedScreenID = firstExternalScreenID()
                    }
                    .tint(.gray)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            HStack(spacing: 10) {
                iconControlButton("backward.end.fill", "First Slide", tint: .gray) { presentationManager.firstSlide() }
                iconControlButton("chevron.left", "Previous Slide", tint: .gray) { presentationManager.previousSlide() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                iconControlButton("chevron.right", "Next Slide", tint: .gray) { presentationManager.nextSlide() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                iconControlButton("forward.end.fill", "Last Slide", tint: .gray) { presentationManager.lastSlide() }
            }
            .padding(.horizontal)

            Text("Slide \(presentationManager.currentSlide + 1) of \(max(1, presentationManager.totalSlides))")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            if presentationManager.totalSlides > 0 {
                ProgressView(
                    value: Double(presentationManager.currentSlide + 1),
                    total: Double(presentationManager.totalSlides)
                )
                .progressViewStyle(.linear)
                .frame(height: 4)
                .padding(.horizontal)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Notes")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            if presentationManager.notesLoaded {
                ScrollView {
                    Text(formattedCurrentNote)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .frame(minHeight: 130, maxHeight: .infinity)
                .scrollBounceBehavior(.basedOnSize)
            } else {
                Text("Load a `.tex` file to show speaker notes per slide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var nextSlideSection: some View {
        if let pdfDocument = presentationManager.pdfDocument {
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Slide")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                if let nextPreview = PDFSlideRenderer.image(
                    for: pdfDocument,
                    index: min(presentationManager.currentSlide + 1, presentationManager.totalSlides - 1),
                    targetSize: CGSize(width: 240, height: 150)
                ), presentationManager.currentSlide < presentationManager.totalSlides - 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(nsImage: nextPreview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            }

                        Text("Upcoming: Slide \(presentationManager.currentSlide + 2)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    Text("Last slide reached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Label(presentationManager.connectionStatus, systemImage: "antenna.radiowaves.left.and.right")
                .foregroundColor(presentationManager.connectionStatus.contains("Connected") ? .green : .secondary)
                .padding(.horizontal)
        }
    }

    private var detailPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if let pdfDocument = presentationManager.pdfDocument {
                PresenterSlideCanvas(
                    pdfDocument: pdfDocument,
                    slideIndex: presentationManager.currentSlide,
                    transitionStyle: presentationManager.transitionStyle,
                    isBlackout: presentationManager.isBlackout
                )
                .edgesIgnoringSafeArea(.all)
                .background(presenterBackground)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "iphone.gen3.badge.play")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(phoneAccent)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(phoneAccent.opacity(0.14))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(phoneAccent.opacity(0.35), lineWidth: 1)
                        }
                    Text("Open a PDF to begin presenting")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Use ⌘O for slides and ⇧⌘N for notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(presenterBackground)
            }

            if presentationManager.pdfDocument != nil {
                HStack(spacing: 8) {
                    Text(presentationManager.transitionStyle.title)
                        .font(.caption2)
                    Text("\(presentationManager.currentSlide + 1) / \(max(1, presentationManager.totalSlides))")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(14)
            }
        }
    }

    private func openNewPresenterWindow() {
        // Close any existing presenter windows first
        NSApplication.shared.windows.forEach { window in
            if window.title == "Beamer Presenter" && window != NSApplication.shared.keyWindow {
                window.close()
            }
        }
        
        // Open a new window
        openWindow(id: "presenter-window")
    }

    private func registerWindowIfNeeded() {
        guard !isWindowRegistered else { return }
        presentationManager.registerWindow(windowID)
        isWindowRegistered = true
    }

    private func toggleFullscreen() {
        presentationManager.toggleFullscreen(for: windowID)
    }

    private func openFullscreenWindow() {
        closeFullscreenWindow()

        guard let screen = preferredFullscreenScreen() ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = .gray
        window.isOpaque = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.title = "Beamer Presenter - Fullscreen"

        let fullscreenView = FullscreenPDFView {
            closeFullscreenFromAnyAction()
        }
        .environmentObject(presentationManager)

        let hostingView = NSHostingView(rootView: fullscreenView)
        hostingView.frame = screen.frame
        window.contentView = hostingView

        fullscreenEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, self.presentationManager.fullscreenOwnerID == self.windowID {
                self.closeFullscreenFromAnyAction()
                return nil
            }
            return event
        }

        window.makeKeyAndOrderFront(nil)
        window.setFrame(screen.frame, display: true)
        window.makeFirstResponder(hostingView)
        fullscreenWindow = window
    }

    private func closeFullscreenWindow() {
        if let monitor = fullscreenEventMonitor {
            NSEvent.removeMonitor(monitor)
            fullscreenEventMonitor = nil
        }

        if let window = fullscreenWindow {
            window.orderOut(nil)
            window.close()
            fullscreenWindow = nil
        }

        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
    }

    private func closeFullscreenFromAnyAction() {
        presentationManager.exitFullscreen(for: windowID)
        closeFullscreenWindow()
    }

    private func handleFileImport(_ result: Result<[URL], Error>, handler: (URL) -> Void) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            handler(url)
        case .failure(let error):
            print("Error loading file: \(error)")
        }
    }

    private var importerTypes: [UTType] {
        switch activeImportKind {
        case .pdf:
            return [.pdf]
        case .notes:
            return [texType, .plainText]
        }
    }

    private var texType: UTType {
        UTType(filenameExtension: "tex") ?? .plainText
    }

    private var screenOptions: [ScreenOption] {
        NSScreen.screens.compactMap { screen in
            guard let id = screenID(for: screen) else { return nil }
            return ScreenOption(id: id, title: screenLabel(for: screen))
        }
    }

    private func screenID(for screen: NSScreen) -> Int? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
    }

    private func screen(withID id: Int) -> NSScreen? {
        NSScreen.screens.first { screenID(for: $0) == id }
    }

    private func primaryScreenID() -> Int? {
        guard let primary = NSScreen.screens.first else { return nil }
        return screenID(for: primary)
    }

    private func firstExternalScreenID() -> Int? {
        guard let primaryID = primaryScreenID() else { return nil }
        return NSScreen.screens.first { screenID(for: $0) != primaryID }.flatMap(screenID(for:))
    }

    private func preferredFullscreenScreen() -> NSScreen? {
        if let selectedScreenID, let selected = screen(withID: selectedScreenID) {
            return selected
        }

        if let externalID = firstExternalScreenID(), let external = screen(withID: externalID) {
            return external
        }

        return NSScreen.screens.first
    }

    private func screenLabel(for screen: NSScreen) -> String {
        let size = screen.frame.size
        let sizeLabel = "\(Int(size.width))×\(Int(size.height))"
        let isPrimary = screen == NSScreen.screens.first
        return isPrimary ? "\(screen.localizedName) (Primary • \(sizeLabel))" : "\(screen.localizedName) (\(sizeLabel))"
    }

    private func controlButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var formattedCurrentNote: String {
        let raw = presentationManager.currentNote
        guard !raw.isEmpty else { return "" }

        return raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\n")
            .replacingOccurrences(of: "\\newline", with: "\n")
            .replacingOccurrences(of: "\\par", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func iconControlButton(_ symbol: String, _ helpText: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .help(helpText)
    }
}

private enum PDFSlideRenderer {
    static func image(for document: PDFDocument, index: Int, targetSize: CGSize) -> NSImage? {
        guard index >= 0, index < document.pageCount, let page = document.page(at: index) else { return nil }
        let renderSize = CGSize(
            width: max(1, targetSize.width * (NSScreen.main?.backingScaleFactor ?? 2)),
            height: max(1, targetSize.height * (NSScreen.main?.backingScaleFactor ?? 2))
        )
        return page.thumbnail(of: renderSize, for: .mediaBox)
    }
}

struct PresenterSlideCanvas: View {
    let pdfDocument: PDFDocument
    let slideIndex: Int
    let transitionStyle: SlideTransitionStyle
    let isBlackout: Bool

    @State private var displayedSlideIndex: Int = 0
    @State private var transitionDirection: SlideDirection = .forward
    private let presenterBackground = Color(red: 0.42, green: 0.42, blue: 0.42)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                presenterBackground

                if isBlackout {
                    presenterBackground
                } else {
                    if let image = PDFSlideRenderer.image(for: pdfDocument, index: displayedSlideIndex, targetSize: proxy.size) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id("\(displayedSlideIndex)-\(transitionDirection == .forward ? "f" : "b")")
                            .transition(transitionStyle.transition(for: transitionDirection))
                    }
                }
            }
            .clipped()
            .onAppear {
                displayedSlideIndex = slideIndex
            }
            .onChange(of: slideIndex) { oldValue, newValue in
                transitionDirection = newValue >= oldValue ? .forward : .backward
                withAnimation(transitionStyle.animation) {
                    displayedSlideIndex = newValue
                }
            }
            .onChange(of: transitionStyle) { _, _ in
                withAnimation(transitionStyle.animation) {
                    displayedSlideIndex = slideIndex
                }
            }
        }
    }
}

struct FullscreenPDFView: View {
    @EnvironmentObject var presentationManager: PresentationManager
    let onDismiss: () -> Void

    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            if let pdfDocument = presentationManager.pdfDocument {
                PresenterSlideCanvas(
                    pdfDocument: pdfDocument,
                    slideIndex: presentationManager.currentSlide,
                    transitionStyle: presentationManager.transitionStyle,
                    isBlackout: presentationManager.isBlackout
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                Color(red: 0.42, green: 0.42, blue: 0.42).edgesIgnoringSafeArea(.all)
            }

            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { presentationManager.previousSlide() }
                    .frame(maxWidth: .infinity)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible.toggle()
                        }
                    }
                    .frame(maxWidth: .infinity)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { presentationManager.nextSlide() }
                    .frame(maxWidth: .infinity)
            }

            if controlsVisible {
                VStack {
                    HStack {
                        HStack(spacing: 12) {
                            fullscreenOverlayButton("xmark.circle.fill", tint: .gray, action: onDismiss)
                            fullscreenOverlayButton("chevron.left", tint: .gray) { presentationManager.previousSlide() }
                            fullscreenOverlayButton("chevron.right", tint: .gray) { presentationManager.nextSlide() }
                            fullscreenOverlayButton(
                                presentationManager.isBlackout ? "lightbulb.fill" : "lightbulb.slash",
                                tint: .gray
                            ) {
                                presentationManager.toggleBlackout()
                            }
                        }
                        Spacer()
                    }
                    .padding(20)

                    Spacer()

                    HStack {
                        Label(presentationManager.connectionStatus, systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            }

                        Spacer()

                        Text("\(presentationManager.currentSlide + 1) / \(max(1, presentationManager.totalSlides))")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.85), in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            }

                        Spacer()

                        Text(presentationManager.transitionStyle.title)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            presentationManager.previousSlide()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            presentationManager.nextSlide()
            return .handled
        }
        .onKeyPress("b") {
            presentationManager.toggleBlackout()
            return .handled
        }
    }

    private func fullscreenOverlayButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
