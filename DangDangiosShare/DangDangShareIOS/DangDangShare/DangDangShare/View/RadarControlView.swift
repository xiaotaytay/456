import SwiftUI

struct RadarControlView: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var monsterSettings = MonsterSettings.shared
    @ObservedObject private var heroSettings = HeroSettings.shared

    @State private var serverURL: String = ""
    @State private var roomID: String = ""
    @State private var serverStatus: String = "未连接"
    @State private var statusColor: Color = .red

    @AppStorage("saved_server_url") private var savedServerURL: String = ""
    @AppStorage("saved_room_id") private var savedRoom: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Image("111")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    Text("游戏雷达")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务器地址")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        TextField("例如: 192.168.1.1 或 example.com", text: $serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .font(.system(size: 15))
                    }

                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        if appState.isConnected {
                            Text("已连接 \(appState.serverHost)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                        } else if appState.isConnecting {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("连接中...")
                                .font(.system(size: 13))
                                .foregroundColor(.yellow)
                        } else {
                            Text("未连接")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)

                    if !appState.isConnected {
                        Button(action: {
                            let host = serverURL.trimmingCharacters(in: .whitespaces)
                            guard !host.isEmpty else {
                                appState.showToast("请输入服务器地址")
                                return
                            }
                            savedServerURL = host
                            appState.connectToServer(host)
                        }) {
                            Text("连接服务器")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            if !appState.currentRoom.isEmpty {
                                leaveCurrentRoom()
                            }
                            appState.disconnectServer()
                        }) {
                            Text("断开连接")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 16)

                if appState.isConnected {
                    VStack(spacing: 12) {
                        HStack {
                            Text("房间操作")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            TextField("输入房间号", text: $roomID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 14))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            if appState.currentRoom.isEmpty {
                                Button("加入") {
                                    let room = roomID.trimmingCharacters(in: .whitespaces)
                                    guard !room.isEmpty else { return }
                                    savedRoom = room
                                    appState.joinRoom(room)
                                    OverlayManager.shared.showOverlay()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(8)
                            } else {
                                Button("离开") {
                                    leaveCurrentRoom()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.orange)
                                .cornerRadius(8)
                            }
                        }

                        if !appState.currentRoom.isEmpty {
                            HStack {
                                Text("当前房间: \(appState.currentRoom)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                Spacer()
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        HStack {
                            Text("房间列表")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            if appState.roomList.isEmpty {
                                Text("暂无房间")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            } else {
                                Text("\(appState.roomList.count) 个房间")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }

                        if appState.roomList.isEmpty {
                            Text("等待房间数据...")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(appState.roomList, id: \.self) { room in
                                    HStack {
                                        Circle()
                                            .fill(room == appState.currentRoom ? Color.green : Color.blue.opacity(0.6))
                                            .frame(width: 8, height: 8)
                                        Text(room)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if room == appState.currentRoom {
                                            Text("当前")
                                                .font(.system(size: 11))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.green.opacity(0.15))
                                                .cornerRadius(4)
                                        } else {
                                            Button("加入") {
                                                if !appState.currentRoom.isEmpty {
                                                    leaveCurrentRoom()
                                                }
                                                roomID = room
                                                savedRoom = room
                                                appState.joinRoom(room)
                                                OverlayManager.shared.showOverlay()
                                            }
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.15))
                                            .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        HStack {
                            Text("英雄头像偏移调整")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("重置") {
                                heroSettings.reset()
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text("X偏移")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $heroSettings.offsetX, in: -50...50, step: 1)
                                Text("\(Int(heroSettings.offsetX))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            HStack {
                                Text("Y偏移")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $heroSettings.offsetY, in: -50...50, step: 1)
                                Text("\(Int(heroSettings.offsetY))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            HStack {
                                Text("缩放")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $heroSettings.scale, in: 0.5...2.0, step: 0.1)
                                Text(String(format: "%.1f", heroSettings.scale))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        HStack {
                            Text("野怪偏移调整")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("重置") {
                                monsterSettings.reset()
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text("X偏移")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $monsterSettings.offsetX, in: -50...50, step: 1)
                                Text("\(Int(monsterSettings.offsetX))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            HStack {
                                Text("Y偏移")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $monsterSettings.offsetY, in: -50...50, step: 1)
                                Text("\(Int(monsterSettings.offsetY))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            HStack {
                                Text("缩放")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(width: 50, alignment: .leading)
                                Slider(value: $monsterSettings.scale, in: 0.5...2.0, step: 0.1)
                                Text(String(format: "%.1f", monsterSettings.scale))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 4) {
                    Text("作者: 当当")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("QQ: 1978781085")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.bottom, 30)
            }
        }
        .background(Color.black)
        .onChange(of: appState.isConnected) { _ in
            if !appState.isConnected {
                statusColor = .red
            } else {
                statusColor = .green
            }
        }
        .onChange(of: heroSettings.offsetX) { _ in propagateAllSettings() }
        .onChange(of: heroSettings.offsetY) { _ in propagateAllSettings() }
        .onChange(of: heroSettings.scale) { _ in propagateAllSettings() }
        .onChange(of: monsterSettings.offsetX) { _ in propagateAllSettings() }
        .onChange(of: monsterSettings.offsetY) { _ in propagateAllSettings() }
        .onChange(of: monsterSettings.scale) { _ in propagateAllSettings() }
        .onAppear {
            if !savedServerURL.isEmpty {
                serverURL = savedServerURL
            }
            if !savedRoom.isEmpty {
                roomID = savedRoom
            }
            if appState.isConnected {
                statusColor = .green
            }
            propagateAllSettings()
        }
    }

    private func propagateAllSettings() {
        OverlayManager.shared.updateSettings(
            globalX: 0, globalY: 0,
            heroOffsetX: heroSettings.offsetX,
            heroOffsetY: heroSettings.offsetY,
            heroScale: heroSettings.scale,
            monsterOffsetX: monsterSettings.offsetX,
            monsterOffsetY: monsterSettings.offsetY,
            monsterScale: monsterSettings.scale,
            monsterZoom: 1.0
        )
    }

    private func leaveCurrentRoom() {
        appState.leaveRoom()
        OverlayManager.shared.hideOverlay()
    }
}
