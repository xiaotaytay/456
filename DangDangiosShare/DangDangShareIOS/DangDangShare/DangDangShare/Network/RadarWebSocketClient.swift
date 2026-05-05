import Foundation

@MainActor
class RadarWebSocketClient: NSObject, URLSessionWebSocketDelegate {
    var onConnected: (() -> Void)?
    var onDisconnected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onHomeData: ((String) -> Void)?
    var onGameData: ((String) -> Void)?
    var onRoomClosed: (() -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var serverHost: String
    private var roomId: String?
    private var intentionalClose = false
    private var isConnected = false
    private var isConnecting = false
    private var roomRefreshTimer: Timer?
    private var gameDataTimer: Timer?
    private var reconnectTimer: Timer?
    private var connectTimeoutTimer: Timer?
    private var reconnectAttempts = 0

    private let wsPort = 8888
    private let gameDataInterval: TimeInterval = 0.1
    private let roomRefreshInterval: TimeInterval = 2.0
    private let maxReconnectAttempts = 5

    init(host: String) {
        self.serverHost = host
        super.init()
    }

    var connected: Bool { isConnected }
    var connecting: Bool { isConnecting }

    func connect() {
        guard !isConnected && !isConnecting else { return }
        isConnecting = true
        intentionalClose = false
        reconnectAttempts = 0

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        guard let url = URL(string: "ws://\(serverHost):\(wsPort)/ws") else {
            handleDisconnect("无效的服务器地址")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if self?.isConnecting == true {
                    self?.handleDisconnect("连接超时，请检查服务器地址和端口")
                }
            }
        }
    }

    func disconnect() {
        intentionalClose = true
        isConnected = false
        isConnecting = false
        stopTimers()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    func setRoomId(_ roomId: String?) {
        self.roomId = roomId
        if let roomId = roomId, !roomId.isEmpty, isConnected {
            startGameDataRequest()
            requestGameData()
        } else {
            stopGameDataRequest()
        }
    }

    private func requestRoomList() {
        send("getHome")
    }

    private func requestGameData() {
        guard let roomId = roomId, !roomId.isEmpty else { return }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        send("web\(timestamp)[==]\(roomId)")
    }

    private func send(_ message: String) {
        guard let task = webSocketTask, isConnected || isConnecting else { return }
        task.send(.string(message)) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.handleDisconnect("发送失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startRoomRefresh() {
        stopRoomRefresh()
        requestRoomList()
        roomRefreshTimer = Timer.scheduledTimer(withTimeInterval: roomRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isConnected { self.requestRoomList() }
            }
        }
    }

    private func stopRoomRefresh() {
        roomRefreshTimer?.invalidate()
        roomRefreshTimer = nil
    }

    private func startGameDataRequest() {
        stopGameDataRequest()
        requestGameData()
        gameDataTimer = Timer.scheduledTimer(withTimeInterval: gameDataInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isConnected { self.requestGameData() }
            }
        }
    }

    private func stopGameDataRequest() {
        gameDataTimer?.invalidate()
        gameDataTimer = nil
    }

    private func stopTimers() {
        stopRoomRefresh()
        stopGameDataRequest()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol `protocol`: String?) {
        Task { @MainActor in
            self.connectTimeoutTimer?.invalidate()
            self.connectTimeoutTimer = nil
            self.isConnected = true
            self.isConnecting = false
            self.reconnectAttempts = 0

            self.startRoomRefresh()
            if let roomId = self.roomId, !roomId.isEmpty {
                self.startGameDataRequest()
            }

            self.receiveMessages()
            self.onConnected?()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            self.handleDisconnect("连接关闭")
        }
    }

    private func receiveMessages() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.processText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.processText(text)
                        }
                    @unknown default:
                        break
                    }
                    if self.isConnected {
                        self.receiveMessages()
                    }
                case .failure(let error):
                    if !self.intentionalClose {
                        self.handleDisconnect("接收失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func processText(_ text: String) {
        if text.hasPrefix("homeData##") {
            let roomListStr = String(text.dropFirst("homeData##".count))
            let cleaned = roomListStr.hasPrefix(",") ? String(roomListStr.dropFirst()) : roomListStr
            onHomeData?(cleaned)

            if let roomId = roomId, !roomId.isEmpty {
                let rooms = cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if !rooms.contains(roomId) {
                    self.roomId = nil
                    stopGameDataRequest()
                    onRoomClosed?()
                }
            }
        } else if text.hasPrefix("gameData##") {
            let gameData = String(text.dropFirst("gameData##".count))
            if !gameData.trimmingCharacters(in: .whitespaces).isEmpty {
                onGameData?(gameData)
            }
        }
    }

    private func handleDisconnect(_ reason: String) {
        guard isConnected || isConnecting else { return }
        stopTimers()
        isConnected = false
        isConnecting = false
        if !intentionalClose {
            onDisconnected?(reason)
            scheduleReconnect()
        } else {
            onDisconnected?("用户断开")
        }
    }

    private func scheduleReconnect() {
        guard !intentionalClose else { return }
        if reconnectAttempts >= maxReconnectAttempts {
            onError?("已达到最大重连次数")
            return
        }
        reconnectAttempts += 1
        let delay = min(2.0 * Double(reconnectAttempts), 15.0)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.connect()
            }
        }
    }

    static func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return true
    }
}
