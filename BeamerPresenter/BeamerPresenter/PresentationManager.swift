import SwiftUI
import PDFKit
import MultipeerConnectivity

enum SlideDirection {
    case forward
    case backward
}

enum SlideTransitionStyle: String, CaseIterable, Identifiable {
    case none
    case fade
    case push
    case scale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .fade: return "Fade"
        case .push: return "Push"
        case .scale: return "Scale"
        }
    }

    func transition(for direction: SlideDirection) -> AnyTransition {
        switch self {
        case .none:
            return .identity
        case .fade:
            return .opacity
        case .push:
            if direction == .forward {
                return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                   removal: .move(edge: .leading).combined(with: .opacity))
            }
            return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        case .scale:
            return .scale(scale: 0.96).combined(with: .opacity)
        }
    }

    var animation: Animation {
        switch self {
        case .none:
            return .linear(duration: 0.01)
        case .fade:
            return .easeInOut(duration: 0.26)
        case .push:
            return .easeInOut(duration: 0.34)
        case .scale:
            return .spring(response: 0.32, dampingFraction: 0.9)
        }
    }
}

class PresentationManager: NSObject, ObservableObject {
    @Published var currentSlide = 0
    @Published var totalSlides = 0
    @Published var pdfDocument: PDFDocument?
    @Published var transitionStyle: SlideTransitionStyle = .push {
        didSet {
            if transitionStyle != oldValue {
                sendSlideUpdate()
            }
        }
    }
    @Published var isBlackout = false {
        didSet {
            if isBlackout != oldValue {
                sendSlideUpdate()
            }
        }
    }
    @Published var connectionStatus = "Not Connected"
    @Published var currentNote = ""
    @Published var notesSourceDisplayName = "Not loaded"
    @Published private(set) var notesLoaded = false
    @Published private(set) var fullscreenOwnerID: UUID? {
        didSet {
            if fullscreenOwnerID != oldValue {
                sendSlideUpdate()
            }
        }
    }

    var isFullscreen: Bool { fullscreenOwnerID != nil }

    private var advertiser: MCNearbyServiceAdvertiser?
    private var session: MCSession?
    private var peerID: MCPeerID?
    private let serviceType = "beamer-ctrl"
    private var notesBySlide: [String] = []
    private var registeredWindowIDs = Set<UUID>()
    private var activeWindowID: UUID?

    override init() {
        super.init()
        setupConnectivity()
    }

    func setupConnectivity() {
        peerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
        session = MCSession(peer: peerID!, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID!, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

    }

    func loadPDF(url: URL) {
        guard let pdf = PDFDocument(url: url) else { return }

        pdfDocument = pdf
        totalSlides = pdf.pageCount
        currentSlide = 0
        isBlackout = false
        refreshCurrentNote()

        sendSlideUpdate()
    }

    func loadTeXNotes(url: URL) {

        let notesText: String?

        if let utf8Text = try? String(contentsOf: url, encoding: .utf8) {
            notesText = utf8Text
        } else if let unicodeText = try? String(contentsOf: url, encoding: .unicode) {
            notesText = unicodeText
        } else if let asciiText = try? String(contentsOf: url, encoding: .ascii) {
            notesText = asciiText
        } else {
            notesText = nil
        }

        guard let notesText else { return }

        notesBySlide = BeamerNotesParser.parseNotes(from: notesText)
        notesSourceDisplayName = url.lastPathComponent
        notesLoaded = true
        refreshCurrentNote()
        sendSlideUpdate()
    }

    func clearNotes() {
        notesBySlide.removeAll()
        notesSourceDisplayName = "Not loaded"
        notesLoaded = false
        refreshCurrentNote()
        sendSlideUpdate()
    }

    func nextSlide() {
        shiftSlide(by: 1)
    }

    func previousSlide() {
        shiftSlide(by: -1)
    }

    func shiftSlide(by delta: Int) {
        guard totalSlides > 0 else { return }
        let target = max(0, min(currentSlide + delta, totalSlides - 1))
        guard target != currentSlide else { return }
        currentSlide = target
        isBlackout = false
        refreshCurrentNote()
        sendSlideUpdate()
    }

    func goToSlide(_ index: Int) {
        guard index >= 0 && index < totalSlides else { return }
        guard currentSlide != index else { return }
        currentSlide = index
        isBlackout = false
        refreshCurrentNote()
        sendSlideUpdate()
    }

    func firstSlide() {
        goToSlide(0)
    }

    func lastSlide() {
        goToSlide(max(0, totalSlides - 1))
    }

    func toggleBlackout() {
        isBlackout.toggle()
    }

    func registerWindow(_ id: UUID) {
        registeredWindowIDs.insert(id)
        activeWindowID = id
    }

    func unregisterWindow(_ id: UUID) {
        registeredWindowIDs.remove(id)
        if activeWindowID == id {
            activeWindowID = registeredWindowIDs.first
        }
        if fullscreenOwnerID == id {
            fullscreenOwnerID = nil
        }
    }

    func markWindowActive(_ id: UUID) {
        guard registeredWindowIDs.contains(id) else { return }
        activeWindowID = id
    }

    func canEnterFullscreen(from windowID: UUID) -> Bool {
        fullscreenOwnerID == nil || fullscreenOwnerID == windowID
    }

    func toggleFullscreen(for windowID: UUID) {
        markWindowActive(windowID)

        if fullscreenOwnerID == windowID {
            fullscreenOwnerID = nil
            return
        }

        guard fullscreenOwnerID == nil else { return }
        fullscreenOwnerID = windowID
    }

    func exitFullscreen(for windowID: UUID) {
        if fullscreenOwnerID == windowID {
            fullscreenOwnerID = nil
        }
    }

    func exitFullscreen() {
        fullscreenOwnerID = nil
    }

    func sendSlideUpdate() {
        guard let session = session, session.connectedPeers.count > 0 else { return }
        let notePayload = Data(currentNote.utf8).base64EncodedString()
        let sourcePayload = Data(notesSourceDisplayName.utf8).base64EncodedString()
        let message = "slide:\(currentSlide):\(totalSlides):\(isFullscreen ? 1 : 0):\(isBlackout ? 1 : 0):\(transitionStyle.rawValue):\(notePayload):\(sourcePayload)"
        if let data = message.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    private func refreshCurrentNote() {
        guard currentSlide >= 0 else {
            currentNote = ""
            return
        }

        if currentSlide < notesBySlide.count {
            currentNote = notesBySlide[currentSlide]
        } else {
            currentNote = ""
        }
    }
}

extension PresentationManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectionStatus = "Connected to \(peerID.displayName)"
                self.sendSlideUpdate()
            case .notConnected:
                self.connectionStatus = "Disconnected"
            case .connecting:
                self.connectionStatus = "Connecting..."
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            switch message {
            case "next":
                self.nextSlide()
            case "previous":
                self.previousSlide()
            case "next-5":
                self.shiftSlide(by: 5)
            case "prev-5":
                self.shiftSlide(by: -5)
            case "first":
                self.firstSlide()
            case "last":
                self.lastSlide()
            case "toggle-fullscreen":
                if self.isFullscreen {
                    self.exitFullscreen()
                } else if let targetWindow = self.activeWindowID ?? self.registeredWindowIDs.first {
                    self.toggleFullscreen(for: targetWindow)
                }
            case "toggle-blackout":
                self.toggleBlackout()
            default:
                if message.hasPrefix("goto:"),
                   let indexStr = message.split(separator: ":").last,
                   let index = Int(indexStr) {
                    self.goToSlide(index)
                }
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PresentationManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

private enum BeamerNotesParser {
    static func parseNotes(from text: String) -> [String] {
        let frameStartRanges = allFrameStartRanges(in: text)
        guard !frameStartRanges.isEmpty else { return [] }

        var notes: [String] = []
        for index in frameStartRanges.indices {
            let frameStart = frameStartRanges[index].lowerBound
            let frameEnd: String.Index = {
                let nextIndex = frameStartRanges.index(after: index)
                if nextIndex < frameStartRanges.endIndex {
                    return frameStartRanges[nextIndex].lowerBound
                }
                return text.endIndex
            }()

            let frameSliceRange = frameStart..<frameEnd
            let extracted = firstNote(in: text, within: frameSliceRange)
            notes.append(extracted ?? "")
        }

        return notes
    }

    private static func allFrameStartRanges(in text: String) -> [Range<String.Index>] {
        let frameToken = "\\begin{frame"
        var ranges: [Range<String.Index>] = []
        var searchIndex = text.startIndex

        while searchIndex < text.endIndex,
              let range = text.range(of: frameToken, range: searchIndex..<text.endIndex) {
            ranges.append(range)
            searchIndex = range.upperBound
        }

        return ranges
    }

    private static func firstNote(in text: String, within range: Range<String.Index>) -> String? {
        var searchIndex = range.lowerBound

        while searchIndex < range.upperBound,
              let noteTokenRange = text.range(of: "\\note", range: searchIndex..<range.upperBound) {
            var cursor = noteTokenRange.upperBound

            skipWhitespace(in: text, cursor: &cursor, limit: range.upperBound)
            if cursor < range.upperBound, text[cursor] == "<" {
                skipBalanced(in: text, cursor: &cursor, limit: range.upperBound, open: "<", close: ">")
                skipWhitespace(in: text, cursor: &cursor, limit: range.upperBound)
            }

            guard cursor < range.upperBound, text[cursor] == "{" else {
                searchIndex = noteTokenRange.upperBound
                continue
            }

            if let note = extractBalancedBraces(in: text, fromOpeningBrace: cursor, limit: range.upperBound) {
                return normalize(note)
            }

            return nil
        }

        return nil
    }

    private static func extractBalancedBraces(
        in text: String,
        fromOpeningBrace openingIndex: String.Index,
        limit: String.Index
    ) -> String? {
        var cursor = text.index(after: openingIndex)
        var depth = 1

        while cursor < limit {
            let character = text[cursor]

            if character == "\\" {
                let nextIndex = text.index(after: cursor)
                cursor = nextIndex < limit ? text.index(after: nextIndex) : limit
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let content = text[text.index(after: openingIndex)..<cursor]
                    return String(content)
                }
            }

            cursor = text.index(after: cursor)
        }

        return nil
    }

    private static func skipBalanced(
        in text: String,
        cursor: inout String.Index,
        limit: String.Index,
        open: Character,
        close: Character
    ) {
        guard cursor < limit, text[cursor] == open else { return }
        var depth = 1
        cursor = text.index(after: cursor)

        while cursor < limit, depth > 0 {
            let character = text[cursor]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
            }
            cursor = text.index(after: cursor)
        }
    }

    private static func skipWhitespace(in text: String, cursor: inout String.Index, limit: String.Index) {
        while cursor < limit, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
    }

    private static func normalize(_ note: String) -> String {
        let lines = note
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
