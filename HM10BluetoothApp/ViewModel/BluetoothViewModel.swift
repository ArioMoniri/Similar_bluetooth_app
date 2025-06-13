import SwiftUI
import CoreBluetooth // For Bluetooth functionalities

// MARK: - BluetoothViewModel Class
/**
 * `BluetoothViewModel` is an `ObservableObject` class responsible for all Bluetooth Low Energy (BLE)
 * interactions within the app. It acts as a central manager (`CBCentralManagerDelegate`) to scan for,
 * connect to, and manage BLE peripherals, and also as a peripheral delegate (`CBPeripheralDelegate`)
 * to handle events from a connected peripheral, such as service discovery and data updates.
 *
 * This class publishes properties that the SwiftUI views can observe to update the UI based on
 * Bluetooth state changes, discovered devices, connection status, and received data.
 */
class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Published Properties
    /// A list of discovered `CBPeripheral` objects during scanning.
    @Published var discoveredPeripherals: [CBPeripheral] = []
    /// A string message reflecting the current Bluetooth status or last significant event.
    @Published var statusMessage: String = "Status: Not Connected"
    /// The currently connected `CBPeripheral` object. `nil` if no device is connected.
    @Published var connectedPeripheral: CBPeripheral?
    /// An array of strings representing messages received from the connected peripheral.
    @Published var receivedMessages: [String] = []
    /// A boolean indicating whether the central manager is currently scanning for peripherals.
    @Published var isScanning: Bool = false
    /// The `CBCharacteristic` identified for writing data to the connected peripheral. `nil` if not found or not connected.
    @Published var writeCharacteristic: CBCharacteristic?
    /// The `CBCharacteristic` identified for receiving notifications from the connected peripheral. `nil` if not found or not connected.
    @Published var notifyCharacteristic: CBCharacteristic?
    /// A boolean indicating whether the device's Bluetooth is powered on and available.
    @Published var isBluetoothPoweredOn: Bool = false

    // MARK: - Private Properties
    /// The `CBCentralManager` instance that manages BLE operations like scanning and connecting.
    private var centralManager: CBCentralManager?

    // Standard HM-10 Service and Characteristic UUIDs (currently discovering all, so these are for reference)
    // let hm10ServiceUUID = CBUUID(string: "FFE0")
    // let hm10CharacteristicUUID = CBUUID(string: "FFE1") // Often used for both TX and RX for HM-10

    // MARK: - Initialization
    override init() {
        super.init()
        // Initialize the CBCentralManager.
        // `delegate: self` means this class will handle central manager delegate callbacks.
        // `queue: nil` specifies that delegate callbacks will be dispatched on the main dispatch queue.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Interface Methods

    /**
     * Starts scanning for nearby BLE peripherals.
     * Ensures Bluetooth is powered on before initiating a scan.
     * Clears previously discovered peripherals and updates status messages.
     */
    public func startScanning() {
        print("startScanning called")
        guard centralManager?.state == .poweredOn else { // Or use self.isBluetoothPoweredOn
            statusMessage = "Bluetooth is not powered on. Cannot start scan."
            print("Cannot scan, Bluetooth is not powered on.")
            return
        }

        discoveredPeripherals.removeAll() // Clear any previously discovered peripherals before a new scan.
        statusMessage = "Scanning for devices..."
        isScanning = true
        // Start scanning for any available BLE peripheral.
        // `withServices: nil` means discover all types of peripherals.
        // `options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]` means we get one discovery event per peripheral,
        // even if it advertises multiple times. Set to true if continuous updates (e.g., for RSSI) are needed.
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    /**
     * Stops any ongoing scan for BLE peripherals.
     * Updates status messages accordingly.
     */
    public func stopScanning() {
        print("stopScanning called")
        if centralManager?.isScanning ?? false { // Check if the central manager is actually scanning.
            centralManager?.stopScan()
        }
        isScanning = false
        // Avoid overwriting status if it's related to connection state (e.g., "Connected to...")
        if !statusMessage.contains("Connected to") && !statusMessage.contains("Connecting to") && !statusMessage.contains("Disconnect") {
             statusMessage = "Scan stopped."
        }
    }

    /**
     * Attempts to connect to a specified `CBPeripheral`.
     * - Parameter peripheral: The `CBPeripheral` object to connect to.
     */
    public func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to: \(peripheral.name ?? "Unknown peripheral")")
        statusMessage = "Connecting to \(peripheral.name ?? "Unknown Device")..."
        // Initiate connection to the peripheral. Delegate methods will handle success/failure.
        centralManager?.connect(peripheral, options: nil)
    }

    /**
     * Disconnects from the currently connected peripheral, if any.
     */
    public func disconnect() {
        print("Disconnect called")
        if let peripheral = connectedPeripheral { // Ensure there is a peripheral to disconnect from.
            statusMessage = "Disconnecting from \(peripheral.name ?? "Unknown Device")..."
            // Request cancellation of the peripheral connection.
            // `centralManager(_:didDisconnectPeripheral:error:)` delegate method will be called.
            centralManager?.cancelPeripheralConnection(peripheral)
        } else {
            statusMessage = "No device connected to disconnect."
            print("No device connected to disconnect.")
        }
    }

    /**
     * Sends a string to the connected peripheral via the `writeCharacteristic`.
     * - Parameter string: The string message to send.
     * The string is converted to UTF-8 data. The write type (with/without response)
     * is determined by the properties of the `writeCharacteristic`.
     */
    func send(string: String) {
        // Ensure we have a connected peripheral and a characteristic to write to.
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            statusMessage = "Not connected or write characteristic not found."
            print("Error: Not connected or write characteristic not found. Cannot send data.")
            return
        }

        // Convert the string to Data using UTF-8 encoding.
        guard let data = string.data(using: .utf8) else {
            statusMessage = "Error: Could not convert string to sendable data."
            print("Error: Could not convert string to data.")
            return
        }

        // Determine the write type. `.withResponse` will trigger `peripheral(_:didWriteValueFor:error:)`.
        // `.withoutResponse` is faster but doesn't confirm the write. HM-10 often uses `.withoutResponse`.
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse

        // Perform the write operation.
        peripheral.writeValue(data, for: characteristic, type: writeType)

        // Update status for immediate feedback.
        // If using .withResponse, `peripheral(_:didWriteValueFor:error:)` can provide more definitive success/failure.
        statusMessage = "Sent: \(string)"
        print("Sent string: \"\(string)\" to characteristic \(characteristic.uuid) with type: \(writeType == .withResponse ? "withResponse" : "withoutResponse")")
    }

    // MARK: - CBCentralManagerDelegate Methods

    /**
     * Called when the central manager's state (e.g., Bluetooth power) changes.
     * This is a crucial first delegate method. It informs the app about the availability of Bluetooth.
     * - Parameter central: The `CBCentralManager` whose state has changed.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Update our published property reflecting Bluetooth power state.
        isBluetoothPoweredOn = (central.state == .poweredOn)

        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth is On. Ready to scan."
            // This is the ideal state. The app can now proceed with BLE operations.
        case .poweredOff:
            statusMessage = "Bluetooth is Off. Please turn it on."
            isScanning = false // Stop scanning if it was active.
            // Clear connection-related properties as any active connection would be lost.
            connectedPeripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil
        case .unsupported:
            statusMessage = "Bluetooth is not supported on this device."
            isScanning = false
            // The device doesn't support BLE.
        case .unauthorized:
            statusMessage = "Bluetooth access denied. Please enable it in Settings for this app."
            isScanning = false
            // The app is not authorized to use Bluetooth. User needs to grant permission in Settings.
        case .resetting:
            statusMessage = "Bluetooth is resetting. Please wait."
            isScanning = false
            // The Bluetooth connection is temporarily lost. It may recover.
        case .unknown:
            statusMessage = "Bluetooth state is unknown."
            isScanning = false
            // The state is unknown.
        @unknown default:
            statusMessage = "Bluetooth state is in an unknown new state. Please check Bluetooth settings."
            isScanning = false
            // Handle any future states gracefully.
        }
    }

    /**
     * Called when the central manager discovers a peripheral while scanning.
     * - Parameters:
     *   - central: The `CBCentralManager` providing this update.
     *   - peripheral: The `CBPeripheral` object that was discovered.
     *   - advertisementData: A dictionary containing advertisement data. Useful for filtering by advertised services.
     *   - RSSI: The received signal strength indicator (RSSI) for the peripheral, in decibels.
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Log the discovery. Peripheral name can be nil if not advertised.
        print("Discovered peripheral: \(peripheral.name ?? "Unknown Peripheral") (UUID: \(peripheral.identifier.uuidString)), RSSI: \(RSSI)")

        // Add the discovered peripheral to our array if it's not already there.
        // `CBPeripheral` objects are unique by their `identifier` (a UUID).
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
    }

    /**
     * Called when a connection is successfully established with a peripheral.
     * - Parameters:
     *   - central: The `CBCentralManager` providing this information.
     *   - peripheral: The `CBPeripheral` that has connected.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Successfully connected to: \(peripheral.name ?? "Unknown Peripheral") (UUID: \(peripheral.identifier.uuidString))")
        connectedPeripheral = peripheral // Store the connected peripheral.

        // Crucially, set this ViewModel as the delegate for the connected peripheral.
        // This allows us to receive peripheral-specific events (service discovery, data updates, etc.).
        peripheral.delegate = self

        stopScanning() // Stop scanning as we've found and connected to a device.

        statusMessage = "Connected to \(peripheral.name ?? "device"). Discovering services..."
        print("Initiating service discovery for \(peripheral.name ?? "Unknown Peripheral")...")
        // Discover all available services on the peripheral.
        // Alternatively, pass an array of `CBUUID` objects to discover specific services: `peripheral.discoverServices([myServiceUUID])`.
        peripheral.discoverServices(nil)
    }

    /**
     * Called when the central manager fails to create a connection with a peripheral.
     * - Parameters:
     *   - central: The `CBCentralManager` providing this information.
     *   - peripheral: The `CBPeripheral` that failed to connect.
     *   - error: An optional `Error` object indicating the reason for failure.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        print("Failed to connect to: \(peripheral.name ?? "Unknown Peripheral") (UUID: \(peripheral.identifier.uuidString)), Error: \(errorMessage)")

        // Clear connection state.
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        statusMessage = "Failed to connect to \(peripheral.name ?? "device"): \(errorMessage). Please try again."
    }

    /**
     * Called when an existing connection with a peripheral is lost or disconnected.
     * - Parameters:
     *   - central: The `CBCentralManager` providing this information.
     *   - peripheral: The `CBPeripheral` that has disconnected.
     *   - error: An optional `Error` object. If present, it indicates an unexpected disconnection. `nil` for intentional disconnects.
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceName = peripheral.name ?? "Unknown Device"
        var logMessage = "Disconnected from: \(deviceName) (UUID: \(peripheral.identifier.uuidString))"
        var userMessage = "Disconnected from \(deviceName)"

        if let error = error { // An unexpected disconnection.
            logMessage += ", Error: \(error.localizedDescription)"
            userMessage += ". Error: \(error.localizedDescription)"
        } else { // An intentional disconnection (e.g., `cancelPeripheralConnection` was called).
            logMessage += " (clean disconnect)"
        }
        print(logMessage)

        // Clear connection state only if this is the peripheral we thought was connected,
        // or if our connectedPeripheral state is somehow already nil (defensive).
        if self.connectedPeripheral == peripheral || self.connectedPeripheral == nil {
            connectedPeripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil
            statusMessage = userMessage
        }
        isScanning = false // Ensure scanning is stopped if it was active.
    }

    // MARK: - CBPeripheralDelegate Methods

    /**
     * Called when the services of a peripheral have been discovered.
     * This is the callback for `peripheral.discoverServices()`.
     * - Parameters:
     *   - peripheral: The `CBPeripheral` whose services were discovered.
     *   - error: An optional `Error` object if discovery failed.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            statusMessage = "Error discovering services for \(peripheral.name ?? "device"): \(error.localizedDescription)"
            print("Error discovering services on \(peripheral.name ?? "Unknown Peripheral"): \(error.localizedDescription)")
            // Depending on the app's needs, you might want to disconnect here.
            // centralManager?.cancelPeripheralConnection(peripheral)
            return
        }

        // Ensure services were actually found.
        guard let services = peripheral.services, !services.isEmpty else {
            statusMessage = "No services found on \(peripheral.name ?? "Unknown"). Ensure the device is advertising correctly."
            print("No services found on \(peripheral.name ?? "Unknown Peripheral")")
            return
        }

        statusMessage = "Services discovered for \(peripheral.name ?? "device"). Discovering characteristics..."
        let serviceUUIDs = services.map { $0.uuid.uuidString }.joined(separator: ", ")
        print("Discovered services for \(peripheral.name ?? "Unknown Peripheral"): [\(serviceUUIDs)]")

        // Reset any previously stored characteristics for this peripheral before rediscovery.
        self.writeCharacteristic = nil
        self.notifyCharacteristic = nil

        // For each discovered service, initiate discovery of its characteristics.
        for service in services {
            print("Discovering characteristics for service: \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            // Discover all characteristics for this service.
            // Alternatively, pass an array of `CBUUID`s for specific characteristics: `peripheral.discoverCharacteristics([myCharacteristicUUID], for: service)`.
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    /**
     * Called when the characteristics of a service have been discovered.
     * This is the callback for `peripheral.discoverCharacteristics(_:for:)`.
     * - Parameters:
     *   - peripheral: The `CBPeripheral` whose characteristics were discovered.
     *   - service: The `CBService` whose characteristics were discovered.
     *   - error: An optional `Error` object if discovery failed.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            statusMessage = "Error discovering characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "device"): \(error.localizedDescription)"
            print("Error discovering characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral"): \(error.localizedDescription)")
            return
        }

        // Ensure characteristics were found for this service.
        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            statusMessage = "No characteristics found for service \(service.uuid.uuidString) on \(peripheral.name ?? "device")."
            print("No characteristics found for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            return
        }

        let characteristicDetails = characteristics.map { "\($0.uuid.uuidString) (properties: \($0.properties))" }.joined(separator: ", ")
        print("Discovered characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral"): [\(characteristicDetails)]")

        // Iterate through the discovered characteristics to find the ones we need.
        for characteristic in characteristics {
            // Typically, you'd check `characteristic.uuid` against known UUIDs (e.g., `hm10CharacteristicUUID`).
            // Here, we check properties to find suitable write and notify characteristics.

            // Check for Writable property (either .write or .writeWithoutResponse).
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                print("Found WRITABLE characteristic: \(characteristic.uuid.uuidString) for service: \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown")")
                // Store this characteristic. If multiple are found, this logic prefers .write over .writeWithoutResponse,
                // or simply takes the first suitable one encountered. More specific logic may be needed for complex devices.
                if self.writeCharacteristic == nil || (characteristic.properties.contains(.write) && (self.writeCharacteristic?.properties.contains(.writeWithoutResponse) ?? true)) {
                     self.writeCharacteristic = characteristic
                }
            }

            // Check for Notify property.
            if characteristic.properties.contains(.notify) {
                print("Found NOTIFY characteristic: \(characteristic.uuid.uuidString) for service: \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown"). Subscribing...")
                // Store this characteristic. If multiple notify characteristics exist, specific UUID matching is better.
                if self.notifyCharacteristic == nil {
                    self.notifyCharacteristic = characteristic
                    // Subscribe to notifications for this characteristic.
                    // `peripheral(_:didUpdateNotificationStateFor:error:)` will be called as a result.
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }

        // Update status message based on characteristic discovery.
        // This message might be updated multiple times if multiple services are processed.
        // A more sophisticated approach might wait until all services are processed.
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            statusMessage = "Device \(peripheral.name ?? "is") ready: Write and notify characteristics found."
        } else if writeCharacteristic != nil && service.characteristics?.contains(where: { $0.properties.contains(.notify) }) == false {
            // If this service didn't have a notify characteristic anyway, this message is fine.
            statusMessage = "Device \(peripheral.name ?? "") partially ready: Write characteristic found. Still seeking notify."
        } else if notifyCharacteristic != nil && service.characteristics?.contains(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) == false {
            // If this service didn't have a write characteristic anyway.
            statusMessage = "Device \(peripheral.name ?? "") partially ready: Notify characteristic found. Still seeking write."
        } else if writeCharacteristic == nil && notifyCharacteristic == nil && service.characteristics?.isEmpty == false {
            // This service had characteristics, but not the ones we're looking for.
            statusMessage = "Found characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? ""), but not the required W/N ones yet."
        } else {
            // This service either had no characteristics or didn't have the ones we want.
            print("Characteristic discovery for service \(service.uuid.uuidString) on \(peripheral.name ?? "") did not yield desired W/N characteristics for this service.")
        }
    }

    /**
     * Called when the peripheral confirms the notification state change for a characteristic.
     * This is the callback for `peripheral.setNotifyValue(_:for:)`.
     * - Parameters:
     *   - peripheral: The `CBPeripheral` providing this update.
     *   - characteristic: The `CBCharacteristic` whose notification state changed.
     *   - error: An optional `Error` object if the state change failed.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            statusMessage = "Error changing notification state for \(characteristic.uuid.uuidString) on \(peripheral.name ?? "device"): \(error.localizedDescription)"
            print("Error changing notification state for \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral"): \(error.localizedDescription)")
            return
        }

        // Successfully subscribed or unsubscribed.
        if characteristic.isNotifying {
            print("Successfully SUBSCRIBED to notifications for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            if characteristic == self.notifyCharacteristic { // Check if it's our primary notify characteristic
                 statusMessage = "Subscribed to notifications. Ready to receive data from \(peripheral.name ?? "device")."
            }
        } else {
            print("Successfully UNSUBSCRIBED from notifications for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            if characteristic == self.notifyCharacteristic {
                statusMessage = "Unsubscribed from notifications for \(peripheral.name ?? "device")."
            }
        }
    }

    /**
     * Called when a peripheral sends data for a characteristic for which notifications are enabled.
     * This is where incoming data (e.g., sensor readings, messages) is received.
     * - Parameters:
     *   - peripheral: The `CBPeripheral` providing the data.
     *   - characteristic: The `CBCharacteristic` whose value has updated. This is typically our `notifyCharacteristic`.
     *   - error: An optional `Error` object if an error occurred.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            statusMessage = "Error receiving data from \(peripheral.name ?? "device") on char \(characteristic.uuid.uuidString): \(error.localizedDescription)"
            print("Error updating value for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral"): \(error.localizedDescription)")
            return
        }

        // Ensure data is present.
        guard let data = characteristic.value else {
            print("No data received for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            statusMessage = "Received empty data packet from \(peripheral.name ?? "device") on char \(characteristic.uuid.uuidString)."
            return
        }

        // Attempt to convert the data to a UTF-8 string. Adjust encoding if your device uses something else.
        if let receivedString = String(data: data, encoding: .utf8) {
            let trimmedString = receivedString.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Received string: \"\(trimmedString)\" from characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            // Update the UI on the main thread.
            DispatchQueue.main.async {
                if !trimmedString.isEmpty { // Avoid adding empty or whitespace-only messages.
                    self.receivedMessages.append("Received: \(trimmedString)")
                    // Optionally, limit the number of messages stored.
                    if self.receivedMessages.count > 100 {
                        self.receivedMessages.removeFirst(self.receivedMessages.count - 100)
                    }
                }
            }
        } else {
            // If data is not a valid UTF-8 string, log it as hexadecimal.
            let hexString = data.hexEncodedString()
            print("Received non-string data (hex): \(hexString) from characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
            DispatchQueue.main.async {
                 self.receivedMessages.append("Received (hex): \(hexString)")
                 if self.receivedMessages.count > 100 {
                    self.receivedMessages.removeFirst(self.receivedMessages.count - 100)
                }
            }
        }
    }

    /**
     * Called after a value is successfully written to a characteristic, *only* if the write type was `.withResponse`.
     * If `.withoutResponse` was used, this method is not called.
     * - Parameters:
     *   - peripheral: The `CBPeripheral` to which the value was written.
     *   - characteristic: The `CBCharacteristic` to which the value was written. This is typically our `writeCharacteristic`.
     *   - error: An optional `Error` object if the write failed.
     */
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value to characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral"): \(error.localizedDescription)")
            statusMessage = "Error sending data to \(peripheral.name ?? "device"): \(error.localizedDescription)"
            // Optionally, add to a chat log: self.receivedMessages.append("Error sending: \(error.localizedDescription)")
            return
        }

        // This confirms the data was successfully written to the peripheral (for `.withResponse` writes).
        // The `statusMessage = "Sent: \(string)"` in the `send(string:)` method provides more immediate feedback for UI,
        // especially for `.withoutResponse` writes.
        print("Successfully wrote value to characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown Peripheral")")
        // You might update statusMessage here if specific confirmation is needed for `.withResponse` writes.
        // e.g., statusMessage = "Data sent successfully to \(peripheral.name ?? "device")."
    }
}

// MARK: - Data Extension
// Helper extension to convert Data to a hexadecimal string for debugging non-UTF8 data.
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
