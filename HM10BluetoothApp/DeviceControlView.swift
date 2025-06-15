import SwiftUI
import CoreBluetooth

struct DeviceControlView: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @StateObject private var commandHistory = CommandHistoryManager()
    var peripheral: CBPeripheral
    
    @State private var commandToSend: String = ""
    @State private var showingCommandPicker = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Device Info Section
            DeviceInfoSection(peripheral: peripheral, bluetoothViewModel: bluetoothViewModel)
            
            // Quick Commands Section (HM-10 specific)
            QuickCommandsSection(bluetoothViewModel: bluetoothViewModel)
            
            // Custom Command Input
            CustomCommandSection(
                commandToSend: $commandToSend,
                bluetoothViewModel: bluetoothViewModel,
                commandHistory: commandHistory,
                showingCommandPicker: $showingCommandPicker
            )
            
            // Enhanced Message Console
            EnhancedMessageConsole(bluetoothViewModel: bluetoothViewModel)
            
            Spacer()
            
            // Action Buttons
            ActionButtonsSection(
                commandToSend: $commandToSend,
                bluetoothViewModel: bluetoothViewModel,
                commandHistory: commandHistory
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(peripheral.name ?? "BLE Device")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            connectIfNeeded()
        }
        .onChange(of: bluetoothViewModel.connectedPeripheral) { oldValue, newValue in
            if newValue == nil && oldValue?.identifier == peripheral.identifier {
                dismiss()
            }
        }
    }
    
    private func connectIfNeeded() {
        if bluetoothViewModel.connectedPeripheral != peripheral {
            bluetoothViewModel.connect(to: peripheral)
        }
        commandToSend = ""
    }
}

// MARK: - Device Info Section
struct DeviceInfoSection: View {
    let peripheral: CBPeripheral
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            InfoCard {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Name", value: peripheral.name ?? "Unknown Device")
                    InfoRow(label: "UUID", value: peripheral.identifier.uuidString)
                    InfoRow(label: "Status", value: bluetoothViewModel.statusMessage)
                    
                    if bluetoothViewModel.isConnectedToHM10 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("HM-10 Compatible")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

// MARK: - Quick Commands Section
struct QuickCommandsSection: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    
    private let quickCommands = [
        ("Test", "AT"),
        ("Role", "AT+ROLE?"),
        ("Name", "AT+NAME?"),
        ("Version", "AT+VERS?"),
        ("Reset", "AT+RESET")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Commands")
                .font(.title3.bold())
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickCommands, id: \.0) { command in
                        QuickCommandButton(
                            title: command.0,
                            command: command.1,
                            bluetoothViewModel: bluetoothViewModel
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

struct QuickCommandButton: View {
    let title: String
    let command: String
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    
    var body: some View {
        Button(action: {
            bluetoothViewModel.sendATCommand(command)
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                Text(command)
                    .font(.caption2)
                    .opacity(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(bluetoothViewModel.connectedPeripheral == nil || bluetoothViewModel.writeCharacteristic == nil)
    }
}

// MARK: - Custom Command Section
struct CustomCommandSection: View {
    @Binding var commandToSend: String
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @ObservedObject var commandHistory: CommandHistoryManager
    @Binding var showingCommandPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Command")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("History") {
                    showingCommandPicker = true
                }
                .font(.caption)
                .disabled(commandHistory.commandHistory.isEmpty)
            }
            .padding(.horizontal)
            
            HStack {
                TextField("Enter AT command or message", text: $commandToSend)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendCommand()
                    }
                
                Button("Send") {
                    sendCommand()
                }
                .disabled(commandToSend.isEmpty || bluetoothViewModel.connectedPeripheral == nil)
            }
            .padding(.horizontal)
        }
        .padding(.top)
        .sheet(isPresented: $showingCommandPicker) {
            CommandHistoryView(
                commandHistory: commandHistory,
                selectedCommand: $commandToSend
            )
        }
    }
    
    private func sendCommand() {
        guard !commandToSend.isEmpty else { return }
        
        commandHistory.addCommand(commandToSend)
        bluetoothViewModel.send(string: commandToSend)
        commandToSend = ""
    }
}

// MARK: - Enhanced Message Console
struct EnhancedMessageConsole: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Console Output")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear") {
                    bluetoothViewModel.receivedMessages.removeAll()
                }
                .font(.caption)
                .disabled(bluetoothViewModel.receivedMessages.isEmpty)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if bluetoothViewModel.receivedMessages.isEmpty {
                        Text("Console output will appear here...")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(Array(bluetoothViewModel.receivedMessages.enumerated()), id: \.offset) { index, message in
                            ConsoleMessageRow(message: message, index: index)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct ConsoleMessageRow: View {
    let message: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1).")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
            
            Text(message)
                .font(.caption)
                .foregroundColor(messageColor)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private var messageColor: Color {
        let parsedResponse = HM10ResponseParser.parseResponse(message)
        return parsedResponse.type.color
    }
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    @Binding var commandToSend: String
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @ObservedObject var commandHistory: CommandHistoryManager
    
    var body: some View {
        HStack(spacing: 12) {
            Button("Disconnect") {
                bluetoothViewModel.disconnect()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(bluetoothViewModel.connectedPeripheral == nil)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// MARK: - Supporting Views
struct InfoCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Command History View
struct CommandHistoryView: View {
    @ObservedObject var commandHistory: CommandHistoryManager
    @Binding var selectedCommand: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(commandHistory.commandHistory, id: \.self) { command in
                    Button(action: {
                        selectedCommand = command
                        dismiss()
                    }) {
                        Text(command)
                            .foregroundColor(.primary)
                    }
                }
                .onDelete { indexSet in
                    commandHistory.commandHistory.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Command History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
