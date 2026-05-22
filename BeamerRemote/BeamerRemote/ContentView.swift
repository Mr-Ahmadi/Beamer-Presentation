import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var remoteManager = RemoteManager()
    @State private var showingPeerList = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    connectionCard

                    if remoteManager.isConnected {
                        presentationStatusCard
                        navigationControls
                        jumpControls
                        modeControls
                    } else {
                        disconnectedCard
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGray6), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Beamer Remote")
            .sheet(isPresented: $showingPeerList) {
                PeerListView(availablePeers: remoteManager.availablePeers) { peer in
                    remoteManager.connectToPeer(peer)
                    showingPeerList = false
                }
            }
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: remoteManager.isConnected ? "dot.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(remoteManager.isConnected ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(remoteManager.isConnected ? "Connected" : "Not Connected")
                        .font(.headline)
                    Text(remoteManager.isConnected ? "Host: \(remoteManager.hostName)" : "Select a Mac to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !remoteManager.isConnected {
                    Button("Connect") {
                        showingPeerList = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var presentationStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Slide \(remoteManager.currentSlide + 1) of \(max(1, remoteManager.totalSlides))")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(remoteManager.transitionName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }

            ProgressView(
                value: Double(remoteManager.currentSlide + 1),
                total: Double(max(1, remoteManager.totalSlides))
            )

            HStack(spacing: 10) {
                statusChip(title: "Fullscreen", isActive: remoteManager.isFullscreen, activeColor: .blue)
                statusChip(title: "Blackout", isActive: remoteManager.isBlackout, activeColor: .purple)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var navigationControls: some View {
        VStack(spacing: 12) {
            Text("Navigation")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                controlButton(title: "-5", symbol: "gobackward.5") {
                    remoteManager.sendCommand("prev-5")
                }
                controlButton(title: "Prev", symbol: "chevron.left") {
                    remoteManager.sendCommand("previous")
                }
                controlButton(title: "Next", symbol: "chevron.right") {
                    remoteManager.sendCommand("next")
                }
                controlButton(title: "+5", symbol: "goforward.5") {
                    remoteManager.sendCommand("next-5")
                }
            }

            HStack(spacing: 10) {
                wideButton(title: "First", symbol: "backward.end.fill") {
                    remoteManager.sendCommand("first")
                }
                wideButton(title: "Last", symbol: "forward.end.fill") {
                    remoteManager.sendCommand("last")
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var jumpControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jump To Slide")
                .font(.headline)

            if remoteManager.totalSlides > 0 {
                Stepper(
                    "Slide \(remoteManager.currentSlide + 1)",
                    value: Binding(
                        get: { remoteManager.currentSlide + 1 },
                        set: { newValue in
                            let bounded = min(max(1, newValue), remoteManager.totalSlides)
                            remoteManager.sendCommand("goto:\(bounded - 1)")
                        }
                    ),
                    in: 1...max(1, remoteManager.totalSlides)
                )
                .labelsHidden()

                Slider(
                    value: Binding(
                        get: { Double(remoteManager.currentSlide + 1) },
                        set: { newValue in
                            remoteManager.sendCommand("goto:\(Int(newValue.rounded()) - 1)")
                        }
                    ),
                    in: 1...Double(max(1, remoteManager.totalSlides)),
                    step: 1
                )
            } else {
                Text("No slides loaded on presenter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var modeControls: some View {
        VStack(spacing: 10) {
            Text("Mode")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                wideButton(
                    title: remoteManager.isFullscreen ? "Exit Fullscreen" : "Fullscreen",
                    symbol: remoteManager.isFullscreen ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                ) {
                    remoteManager.sendCommand("toggle-fullscreen")
                }

                wideButton(
                    title: remoteManager.isBlackout ? "Unblackout" : "Blackout",
                    symbol: remoteManager.isBlackout ? "lightbulb" : "lightbulb.slash"
                ) {
                    remoteManager.sendCommand("toggle-blackout")
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var disconnectedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Connect to a presenter to unlock controls")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func controlButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            remoteManager.sendHaptic()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private func wideButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            remoteManager.sendHaptic()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func statusChip(title: String, isActive: Bool, activeColor: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? activeColor : .secondary)
            .background((isActive ? activeColor.opacity(0.15) : Color.gray.opacity(0.12)), in: Capsule())
    }
}

struct PeerListView: View {
    let availablePeers: [MCPeerID]
    let onSelect: (MCPeerID) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if availablePeers.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Searching for Mac...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(availablePeers, id: \.self) { peer in
                        Button(action: { onSelect(peer) }) {
                            HStack {
                                Image(systemName: "desktopcomputer")
                                Text(peer.displayName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Available Macs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
