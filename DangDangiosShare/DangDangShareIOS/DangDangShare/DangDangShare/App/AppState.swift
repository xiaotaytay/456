import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var toastMessage: String = ""
    @Published var showToast: Bool = false

    enum StatusColor {
        case red, yellow, green
    }

    @Published var statusColor: StatusColor = .red

    private var wsClient: RadarWebSocketClient?
    private var toastTimer: Timer?

    var pingText: String = ""
    @Published var roomList: [String] = []
    @Published var currentRoom: String = ""
    var serverHost: String = ""

    private init() {}

    func connectToServer(_ host: String) {
        if wsClient != nil {
            wsClient?.disconnect()
            wsClient = nil
        }

        isConnected = false
        isConnecting = true
        serverHost = host.trimmingCharacters(in: .whitespaces)

        let client = RadarWebSocketClient(host: serverHost)
        wsClient = client

        client.onConnected = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                self.isConnecting = false
                self.statusColor = .green
                self.showToast("已连接")
            }
        }

        client.onDisconnected = { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = false
                self.isConnecting = false
                self.statusColor = .red
                if !self.currentRoom.isEmpty {
                    self.currentRoom = ""
                    OverlayManager.shared.hideOverlay()
                }
            }
        }

        client.onError = { [weak self] msg in
            guard let self = self else { return }
            Task { @MainActor in
                self.showToast(msg)
            }
        }

        client.onHomeData = { [weak self] data in
            guard let self = self else { return }
            let rooms = data.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            Task { @MainActor in
                self.roomList = rooms
            }
        }

        client.onGameData = { data in
            OverlayManager.shared.updateGameData(data)
        }

        client.onRoomClosed = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentRoom = ""
                OverlayManager.shared.hideOverlay()
                self.showToast("房间已关闭")
            }
        }

        client.connect()
    }

    func disconnectServer() {
        wsClient?.disconnect()
        wsClient = nil
        isConnected = false
        isConnecting = false
        statusColor = .red
        pingText = ""
        roomList = []
        currentRoom = ""
        OverlayManager.shared.hideOverlay()
    }

    func joinRoom(_ room: String) {
        currentRoom = room
        wsClient?.setRoomId(room)
    }

    func leaveRoom() {
        currentRoom = ""
        wsClient?.setRoomId(nil)
    }

    func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.25)) {
            showToast = true
        }
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showToast = false
                }
            }
        }
    }
}
