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
    @Published var isFullscreen = false {
        didSet {
            if isFullscreen != oldValue {
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

    private var advertiser: MCNearbyServiceAdvertiser?
    private var session: MCSession?
    private var peerID: MCPeerID?
    private let serviceType = "beamer-ctrl"

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

        print("Started advertising as: \(peerID?.displayName ?? "Unknown")")
    }

    func loadPDF(url: URL) {
        print("Loading PDF from: \(url.path)")

        guard let pdf = PDFDocument(url: url) else {
            print("Failed to create PDF document from URL")
            return
        }

        pdfDocument = pdf
        totalSlides = pdf.pageCount
        currentSlide = 0
        isBlackout = false

        print("PDF loaded successfully. Total pages: \(totalSlides)")
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
        sendSlideUpdate()
        print("Shift slide to: \(currentSlide + 1)")
    }

    func goToSlide(_ index: Int) {
        guard index >= 0 && index < totalSlides else { return }
        guard currentSlide != index else { return }
        currentSlide = index
        isBlackout = false
        sendSlideUpdate()
        print("Go to slide: \(index + 1)")
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

    func sendSlideUpdate() {
        guard let session = session, session.connectedPeers.count > 0 else { return }
        let message = "slide:\(currentSlide):\(totalSlides):\(isFullscreen ? 1 : 0):\(isBlackout ? 1 : 0):\(transitionStyle.rawValue)"
        if let data = message.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }
}

extension PresentationManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectionStatus = "Connected to \(peerID.displayName)"
                print("Connected to: \(peerID.displayName)")
                self.sendSlideUpdate()
            case .notConnected:
                self.connectionStatus = "Disconnected"
                print("Disconnected from: \(peerID.displayName)")
            case .connecting:
                self.connectionStatus = "Connecting..."
                print("Connecting to: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            print("Received command: \(message)")
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
                self.isFullscreen.toggle()
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
        print("Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }
}
