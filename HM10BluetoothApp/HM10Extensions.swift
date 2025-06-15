import SwiftUI
import CoreBluetooth
import ObjectiveC

// MARK: - HM-10 Specific Constants
struct HM10Constants {
    // Standard HM-10 UUIDs
    static let serviceUUID = CBUUID(string: "FFE0")
    static let characteristicUUID = CBUUID(string: "FFE1")
    
    // Common AT Commands for HM-10
    static let commonCommands = [
        "AT",           // Test command
        "AT+ROLE?",     // Query role (Master/Slave)
        "AT+ADDR?",     // Query MAC address
        "AT+NAME?",     // Query device name
        "AT+BAUD?",     // Query baud rate
        "AT+VERS?",     // Query firmware version
        "AT+HELP",      // Show available commands
        "AT+RESET"      // Reset module
    ]
}

// MARK: - Enhanced BluetoothViewModel with HM-10 Optimizations
extension BluetoothViewModel {
    
    // Optimized scanning specifically for HM-10 devices
    func startScanningForHM10() {
        guard let central = centralManager, central.state == .poweredOn else {
            statusMessage = "Bluetooth is not powered on. Cannot start scan."
            return
        }
        
        discoveredPeripherals.removeAll()
        statusMessage = "Scanning for HM-10 devices..."
        isScanning = true
        
        // Scan specifically for HM-10 service UUID for better performance
        central.scanForPeripherals(
            withServices: [HM10Constants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    // Quick command sender for common AT commands
    func sendATCommand(_ command: String) {
        send(string: command)
    }
    
    // Helper to check if connected device is likely an HM-10
    var isConnectedToHM10: Bool {
        guard let peripheral = connectedPeripheral else { return false }
        
        // Check if the device has the HM-10 service
        if let services = peripheral.services {
            return services.contains { $0.uuid == HM10Constants.serviceUUID }
        }
        
        // Fallback: check device name
        if let name = peripheral.name?.lowercased() {
            return name.contains("hm") || name.contains("ble") || name.contains("at09")
        }
        
        return false
    }
    
    // Enhanced discovery method for HM-10 characteristics
    func discoverHM10Characteristics(for peripheral: CBPeripheral) {
        // Discover services first, specifically looking for HM-10 service
        peripheral.discoverServices([HM10Constants.serviceUUID])
    }
    
    // Check if the current peripheral has HM-10 characteristics
    var hasHM10Characteristics: Bool {
        guard let characteristic = writeCharacteristic else { return false }
        return characteristic.uuid == HM10Constants.characteristicUUID
    }
}

// MARK: - Command History Manager
class CommandHistoryManager: ObservableObject {
    @Published var commandHistory: [String] = []
    @Published var currentIndex: Int = -1
    
    private let maxHistory = 20
    
    func addCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        // Remove if already exists to avoid duplicates
        commandHistory.removeAll { $0 == command }
        
        // Add to beginning
        commandHistory.insert(command, at: 0)
        
        // Limit history size
        if commandHistory.count > maxHistory {
            commandHistory = Array(commandHistory.prefix(maxHistory))
        }
        
        currentIndex = -1
    }
    
    func getPreviousCommand() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        
        if currentIndex < commandHistory.count - 1 {
            currentIndex += 1
        }
        
        return commandHistory[currentIndex]
    }
    
    func getNextCommand() -> String? {
        guard !commandHistory.isEmpty, currentIndex > 0 else {
            currentIndex = -1
            return ""
        }
        
        currentIndex -= 1
        return commandHistory[currentIndex]
    }
    
    func resetIndex() {
        currentIndex = -1
    }
}

// MARK: - Message Parser for HM-10 Responses
struct HM10ResponseParser {
    static func parseResponse(_ response: String) -> (type: ResponseType, message: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch trimmed {
        case "OK":
            return (.success, "Command executed successfully")
        case "ERROR":
            return (.error, "Command failed")
        case let str where str.hasPrefix("OK+"):
            return (.info, str)
        case let str where str.hasPrefix("AT+"):
            return (.echo, "Echo: \(str)")
        default:
            return (.data, trimmed)
        }
    }
    
    enum ResponseType {
        case success
        case error
        case info
        case echo
        case data
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            case .echo: return .gray
            case .data: return .primary
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .echo: return "arrow.triangle.2.circlepath"
            case .data: return "message.fill"
            }
        }
    }
}

// MARK: - HM-10 Device Information
struct HM10DeviceInfo {
    var name: String?
    var role: String?
    var version: String?
    var baudRate: String?
    var macAddress: String?
    
    init() {
        self.name = nil
        self.role = nil
        self.version = nil
        self.baudRate = nil
        self.macAddress = nil
    }
    
    mutating func parseATResponse(_ response: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("OK+NAME:") {
            name = String(trimmed.dropFirst(8))
        } else if trimmed.hasPrefix("OK+ROLE:") {
            let roleValue = String(trimmed.dropFirst(8))
            role = roleValue == "0" ? "Slave" : "Master"
        } else if trimmed.hasPrefix("OK+VERS:") {
            version = String(trimmed.dropFirst(8))
        } else if trimmed.hasPrefix("OK+BAUD:") {
            baudRate = String(trimmed.dropFirst(8))
        } else if trimmed.hasPrefix("OK+ADDR:") {
            macAddress = String(trimmed.dropFirst(8))
        }
    }
}

// MARK: - Enhanced BluetoothViewModel with Device Info
extension BluetoothViewModel {
    // Device information storage - using a proper key for associated objects
    private static var deviceInfoKey: UInt8 = 0
    
    var hm10DeviceInfo: HM10DeviceInfo {
        get {
            return objc_getAssociatedObject(self, &Self.deviceInfoKey) as? HM10DeviceInfo ?? HM10DeviceInfo()
        }
        set {
            objc_setAssociatedObject(self, &Self.deviceInfoKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // Query all device information
    func queryHM10DeviceInfo() {
        let commands = ["AT+NAME?", "AT+ROLE?", "AT+VERS?", "AT+BAUD?", "AT+ADDR?"]
        
        for (index, command) in commands.enumerated() {
            // Add delay between commands to avoid overwhelming the device
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                self.sendATCommand(command)
            }
        }
    }
    
    // Parse received responses for device info
    func parseHM10Response(_ response: String) {
        hm10DeviceInfo.parseATResponse(response)
    }
}

