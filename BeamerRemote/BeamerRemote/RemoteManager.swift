import SwiftUI
import MultipeerConnectivity

class RemoteManager: NSObject, ObservableObject {
    @Published var currentSlide = 0
    @Published var totalSlides = 0
    @Published var isConnected = false
    @Published var availablePeers: [MCPeerID] = []
    @Published var hostName = ""
    @Published var isFullscreen = false
    @Published var isBlackout = false
    @Published var transitionName = "Push"

    private var browser: MCNearbyServiceBrowser?
    private var session: MCSession?
    private var peerID: MCPeerID?
    private let serviceType = "beamer-ctrl"

    override init() {
        super.init()
        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID!, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID!, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func connectToPeer(_ peer: MCPeerID) {
        guard let session = session else { return }
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func sendCommand(_ command: String) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        guard let data = command.data(using: .utf8) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func sendHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

extension RemoteManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = state == .connected
            if state == .connected {
                self.hostName = peerID.displayName
            }
            if state == .notConnected {
                self.hostName = ""
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            let components = message.split(separator: ":")
            if components.count >= 3, components[0] == "slide" {
                self.currentSlide = Int(components[1]) ?? 0
                self.totalSlides = Int(components[2]) ?? 0
            }
            if components.count >= 4 {
                self.isFullscreen = components[3] == "1"
            }
            if components.count >= 5 {
                self.isBlackout = components[4] == "1"
            }
            if components.count >= 6 {
                self.transitionName = String(components[5]).capitalized
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension RemoteManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.availablePeers.contains(peerID) {
                self.availablePeers.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availablePeers.removeAll { $0 == peerID }
        }
    }
}
