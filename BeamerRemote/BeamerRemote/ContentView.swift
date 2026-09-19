import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var remoteManager = RemoteManager()
    @State private var showingPeerList = false
    @State private var jumpSliderValue: Double = 1
    @State private var isJumpEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    connectionCard

                    if remoteManager.isConnected {
                        presentationStatusCard
                        navigationControls
                        jumpControls
                        notesCard
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
            .toolbar {
                if remoteManager.isConnected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect", role: .destructive) {
                            remoteManager.sendHaptic(.soft)
                            remoteManager.disconnect()
                        }
                        .tint(.red)
                    }
                }
            }
            .sheet(isPresented: $showingPeerList) {
                PeerListView(availablePeers: remoteManager.availablePeers) { peer in
                    remoteManager.sendHaptic(.light)
                    remoteManager.connectToPeer(peer)
                    showingPeerList = false
                }
            }
            .onChange(of: remoteManager.isConnected) { _, isConnected in
                if isConnected {
                    showingPeerList = false
                    jumpSliderValue = Double(remoteManager.currentSlide + 1)
                }
            }
            .onChange(of: remoteManager.currentSlide) { _, newSlide in
                if !isJumpEditing {
                    jumpSliderValue = Double(newSlide + 1)
                }
            }
            .onChange(of: remoteManager.totalSlides) { _, _ in
                if !isJumpEditing {
                    jumpSliderValue = Double(remoteManager.currentSlide + 1)
                }
            }
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                phoneLogo

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
                    .tint(.gray)
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
                    .contentTransition(.numericText())
                Spacer()
                Text(remoteManager.transitionName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12), in: Capsule())
            }

            ProgressView(
                value: Double(remoteManager.currentSlide + 1),
                total: Double(max(1, remoteManager.totalSlides))
            )

            if remoteManager.totalSlides > 0 {
                Text("\(Int((Double(remoteManager.currentSlide + 1) / Double(remoteManager.totalSlides) * 100).rounded()))% through deck")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                statusChip(title: "Fullscreen", isActive: remoteManager.isFullscreen, activeColor: .gray)
                statusChip(title: "Blackout", isActive: remoteManager.isBlackout, activeColor: .gray)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -24 {
                        send("next")
                    } else if value.translation.width > 24 {
                        send("previous")
                    }
                }
        )
        .accessibilityHint("Swipe left for next slide, right for previous.")
    }

    private var navigationControls: some View {
        VStack(spacing: 12) {
            Text("Navigation")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                controlButton(title: "-5", symbol: "gobackward.5") {
                    send("prev-5")
                }
                controlButton(title: "Prev", symbol: "chevron.left") {
                    send("previous")
                }
                .accessibilityHint("Previous slide")
                controlButton(title: "Next", symbol: "chevron.right") {
                    send("next")
                }
                .accessibilityHint("Next slide")
                controlButton(title: "+5", symbol: "goforward.5") {
                    send("next-5")
                }
            }

            HStack(spacing: 10) {
                wideButton(title: "First", symbol: "backward.end.fill") {
                    send("first")
                }
                wideButton(title: "Last", symbol: "forward.end.fill") {
                    send("last")
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func send(_ command: String) {
        remoteManager.sendHaptic()
        remoteManager.sendCommand(command)
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
                            send("goto:\(bounded - 1)")
                        }
                    ),
                    in: 1...max(1, remoteManager.totalSlides)
                )

                Slider(
                    value: $jumpSliderValue,
                    in: 1...Double(max(1, remoteManager.totalSlides)),
                    step: 1
                ) { editing in
                    isJumpEditing = editing
                    if !editing {
                        let target = Int(jumpSliderValue.rounded())
                        send("goto:\(target - 1)")
                    }
                }
                .tint(.gray)
                .accessibilityLabel("Jump to slide \(Int(jumpSliderValue))")
            } else {
                Text("No slides loaded on presenter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Speaker Notes")
                    .font(.headline)
                Spacer()
                if remoteManager.notesSourceName != "Not loaded" {
                    Text(remoteManager.notesSourceName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if formattedNote.isEmpty {
                Text("No note for this slide.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Text(formattedNote)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var formattedNote: String {
        RemoteTextFormatting.plainText(from: remoteManager.currentNote)
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
                    send("toggle-fullscreen")
                }

                wideButton(
                    title: remoteManager.isBlackout ? "Unblackout" : "Blackout",
                    symbol: remoteManager.isBlackout ? "lightbulb" : "lightbulb.slash"
                ) {
                    send("toggle-blackout")
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var disconnectedCard: some View {
        VStack(spacing: 8) {
            phoneLogo
            Text("Connect to a presenter to unlock controls")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func controlButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.95), Color.gray.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.gray.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func wideButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.gray)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.gray.opacity(0.12))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func statusChip(title: String, isActive: Bool, activeColor: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? activeColor : .secondary)
            .background((isActive ? activeColor.opacity(0.15) : Color.gray.opacity(0.12)), in: Capsule())
    }

    private var phoneLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: remoteManager.isConnected
                            ? [Color(red: 0.95, green: 0.98, blue: 0.96), Color(red: 0.92, green: 0.96, blue: 0.93)]
                            : [Color(red: 0.96, green: 0.96, blue: 0.97), Color(red: 0.93, green: 0.93, blue: 0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: remoteManager.isConnected
                                    ? [Color.green.opacity(0.4), Color.green.opacity(0.2)]
                                    : [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)

            Circle()
                .fill(
                    remoteManager.isConnected
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.85, blue: 0.4),
                                Color(red: 0.15, green: 0.7, blue: 0.35),
                                Color(red: 0.1, green: 0.6, blue: 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color(red: 0.5, green: 0.5, blue: 0.52),
                                Color(red: 0.4, green: 0.4, blue: 0.42),
                                Color(red: 0.35, green: 0.35, blue: 0.37)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 36, height: 36)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                }
                .shadow(color: remoteManager.isConnected ? Color.green.opacity(0.6) : Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .shadow(color: remoteManager.isConnected ? Color.green.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            
            Image(systemName: remoteManager.isConnected
                  ? "iphone.gen3.radiowaves.left.and.right"
                  : "iphone.gen3.slash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .animation(.easeInOut(duration: 0.3), value: remoteManager.isConnected)
    }
}

struct PeerListView: View {
    let availablePeers: [MCPeerID]
    let onSelect: (MCPeerID) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if availablePeers.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Searching for Mac...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(availablePeers, id: \.displayName) { peer in
                        Button(action: { onSelect(peer) }) {
                            HStack {
                                Image(systemName: "desktopcomputer")
                                Text(peer.displayName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Available Macs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.gray)
                }
            }
        }
    }
}

private enum RemoteTextFormatting {
    static func plainText(from raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(of: "\\\\", with: "\n")
        text = text.replacingOccurrences(of: "\\newline", with: "\n")
        text = text.replacingOccurrences(of: "\\par", with: "\n\n")
        text = text.replacingOccurrences(of: "\\item", with: "\n• ")
        text = replaceCommandContents(in: text)
        text = stripRemainingCommands(in: text)
        text = text.replacingOccurrences(of: "~", with: " ")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        text = lines.joined(separator: "\n")
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceCommandContents(in text: String) -> String {
        var result = text
        let pattern = #"\\[a-zA-Z]+\*?\{([^{}]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        for _ in 0..<5 {
            let range = NSRange(result.startIndex..., in: result)
            let replaced = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
            if replaced == result { break }
            result = replaced
        }
        return result
    }

    private static func stripRemainingCommands(in text: String) -> String {
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\\" {
                var j = text.index(after: i)
                while j < text.endIndex, text[j].isLetter {
                    j = text.index(after: j)
                }
                if j < text.endIndex, text[j] == "[" {
                    var depth = 1
                    j = text.index(after: j)
                    while j < text.endIndex, depth > 0 {
                        if text[j] == "[" { depth += 1 } else if text[j] == "]" { depth -= 1 }
                        j = text.index(after: j)
                    }
                }
                if j < text.endIndex, text[j] == "{" {
                    var depth = 1
                    j = text.index(after: j)
                    while j < text.endIndex, depth > 0 {
                        if text[j] == "{" { depth += 1 } else if text[j] == "}" { depth -= 1 }
                        j = text.index(after: j)
                    }
                }
                i = j
            } else if text[i] == "{" || text[i] == "}" || text[i] == "$" {
                i = text.index(after: i)
            } else {
                result.append(text[i])
                i = text.index(after: i)
            }
        }
        return result
    }
}
