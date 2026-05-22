import SwiftUI
import PDFKit
import AppKit

struct ContentView: View {
    private struct ScreenOption: Identifiable {
        let id: Int
        let title: String
    }

    @EnvironmentObject var presentationManager: PresentationManager
    @State private var showingFilePicker = false
    @State private var fullscreenWindow: NSWindow?
    @State private var fullscreenEventMonitor: Any?
    @State private var selectedScreenID: Int?
    private let presenterBackground = Color(red: 0.42, green: 0.42, blue: 0.42)

    var body: some View {
        NavigationSplitView {
            List {
                Section("Controls") {
                    Button(action: { showingFilePicker = true }) {
                        Label("Open PDF", systemImage: "doc")
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    if presentationManager.pdfDocument != nil {
                        Button(action: toggleFullscreen) {
                            Label(
                                presentationManager.isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen",
                                systemImage: presentationManager.isFullscreen ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                            )
                        }
                        .keyboardShortcut("f", modifiers: [.command, .shift])

                        Button(action: { presentationManager.toggleBlackout() }) {
                            Label(
                                presentationManager.isBlackout ? "Disable Blackout" : "Blackout Slide",
                                systemImage: presentationManager.isBlackout ? "lightbulb" : "lightbulb.slash"
                            )
                        }
                        .keyboardShortcut("b", modifiers: [.command, .shift])
                    }
                }

                Section("Transition") {
                    Picker("Style", selection: $presentationManager.transitionStyle) {
                        ForEach(SlideTransitionStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Display") {
                    Picker("Fullscreen Screen", selection: $selectedScreenID) {
                        Text("Auto (External Preferred)").tag(nil as Int?)
                        ForEach(screenOptions) { option in
                            Text(option.title).tag(Optional(option.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if screenOptions.count > 1 {
                        HStack(spacing: 10) {
                            Button("Primary") {
                                selectedScreenID = primaryScreenID()
                            }
                            Button("External") {
                                selectedScreenID = firstExternalScreenID()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Navigation") {
                    HStack(spacing: 10) {
                        Button(action: { presentationManager.firstSlide() }) {
                            Image(systemName: "backward.end.fill")
                        }
                        .help("First Slide")

                        Button(action: { presentationManager.previousSlide() }) {
                            Image(systemName: "chevron.left")
                        }
                        .keyboardShortcut(.leftArrow, modifiers: [])

                        Button(action: { presentationManager.nextSlide() }) {
                            Image(systemName: "chevron.right")
                        }
                        .keyboardShortcut(.rightArrow, modifiers: [])

                        Button(action: { presentationManager.lastSlide() }) {
                            Image(systemName: "forward.end.fill")
                        }
                        .help("Last Slide")
                    }
                    .font(.title3)

                    Text("Slide \(presentationManager.currentSlide + 1) of \(max(1, presentationManager.totalSlides))")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if presentationManager.totalSlides > 0 {
                        ProgressView(
                            value: Double(presentationManager.currentSlide + 1),
                            total: Double(presentationManager.totalSlides)
                        )
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                    }
                }

                if let pdfDocument = presentationManager.pdfDocument {
                    Section("Next Slide") {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                    }

                                Text("Upcoming: Slide \(presentationManager.currentSlide + 2)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Last slide reached")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Connection") {
                    Label(presentationManager.connectionStatus, systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundColor(presentationManager.connectionStatus.contains("Connected") ? .green : .secondary)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 280, idealWidth: 300)
        } detail: {
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
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        Text("Open a PDF to begin presenting")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Use ⌘O to load your deck")
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
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access the file")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                presentationManager.loadPDF(url: url)
            case .failure(let error):
                print("Error loading PDF: \(error)")
            }
        }
        .onChange(of: presentationManager.isFullscreen) { _, isEnabled in
            if isEnabled {
                openFullscreenWindow()
            } else {
                closeFullscreenWindow()
            }
        }
        .onDisappear {
            closeFullscreenWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            if let selectedScreenID, screen(withID: selectedScreenID) == nil {
                self.selectedScreenID = nil
            }
        }
    }

    private func toggleFullscreen() {
        presentationManager.isFullscreen.toggle()
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
            if event.keyCode == 53, self.presentationManager.isFullscreen {
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
        presentationManager.isFullscreen = false
        closeFullscreenWindow()
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
        return NSScreen.screens.first { screenID(for: $0) != primaryID }.flatMap { screenID(for: $0) }
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
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.85), in: Circle())
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button(action: { presentationManager.previousSlide() }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.85), in: Circle())
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button(action: { presentationManager.nextSlide() }) {
                                Image(systemName: "chevron.right")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.85), in: Circle())
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button(action: { presentationManager.toggleBlackout() }) {
                                Image(systemName: presentationManager.isBlackout ? "lightbulb.fill" : "lightbulb.slash")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.85), in: Circle())
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
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
}
