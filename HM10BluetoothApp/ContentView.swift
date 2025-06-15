
import SwiftUI
import CoreBluetooth // Though not directly used here, it's good context for what bluetoothViewModel handles.

// MARK: - ContentView Struct
/**
 * `ContentView` is the main SwiftUI View for the application.
 * It provides the user interface for interacting with Bluetooth Low Energy (BLE) devices.
 * This includes scanning for devices, connecting to a device, sending messages,
 * and viewing received messages and status updates.
 */
struct ContentView: View {
    // MARK: - State Objects and Properties
    /// The `@StateObject` property wrapper ensures that `bluetoothViewModel` is instantiated once
    /// and its lifecycle is managed by the view. It serves as the single source of truth for
    /// all Bluetooth-related state and operations.
    @StateObject var bluetoothViewModel = BluetoothViewModel()

    /// `@State` property to hold the text entered by the user in the `TextField` for sending messages.
    @State private var messageToSend: String = ""

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // MARK: Discovered Devices List
                // Displays a list of peripherals discovered by the `bluetoothViewModel`.
                // Each row is tappable to initiate a connection.
                List(bluetoothViewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                    HStack {
                        // Display the name of the peripheral, or "Unknown Device" if the name is nil.
                        Text(peripheral.name ?? "Unknown Device")
                        Spacer()
                        // Show a checkmark if this peripheral is the currently connected one.
                        if bluetoothViewModel.connectedPeripheral == peripheral {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle()) // Makes the entire HStack area tappable.
                    .onTapGesture {
                        // Action to connect to the tapped peripheral.
                        if bluetoothViewModel.connectedPeripheral != peripheral {
                            // If already connected to a different peripheral, disconnect first (optional behavior).
                            if bluetoothViewModel.connectedPeripheral != nil {
                                bluetoothViewModel.disconnect()
                            }
                            bluetoothViewModel.connect(to: peripheral)
                        } else {
                            // Optionally, tapping an already connected peripheral could disconnect it.
                            // bluetoothViewModel.disconnect()
                        }
                    }
                }
                .navigationTitle("Bluetooth Devices") // Title for the navigation bar.

                // MARK: Status Display Area
                // Displays the current status message from the `bluetoothViewModel`.
                Text(bluetoothViewModel.statusMessage)
                    .padding()

                // "Disconnect" button, visible only when a peripheral is connected.
                if bluetoothViewModel.connectedPeripheral != nil {
                    Button("Disconnect") {
                        bluetoothViewModel.disconnect() // Action to disconnect from the current peripheral.
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.orange) // Styling for the disconnect button.
                    .cornerRadius(8)
                }

                // MARK: Received Messages Console
                // A ScrollView to display messages received from the connected peripheral.
                ScrollView {
                    VStack(alignment: .leading) {
                        // Iterates through the `receivedMessages` array in the `bluetoothViewModel`.
                        // Using `.indices` and `id: \.self` for `ForEach` is a common way to handle
                        // arrays of non-Identifiable simple types or when indices are needed.
                        // If messages were complex structs, `id: \.id` (with a UUID `id` property) would be better.
                        ForEach(bluetoothViewModel.receivedMessages.indices, id: \.self) { index in
                            Text(bluetoothViewModel.receivedMessages[index])
                                .padding(.vertical, 1)
                                .textSelection(.enabled) // Allows users to copy text from the console.
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure text aligns left.
                    .padding()
                }
                .frame(height: 200) // Fixed height for the console.
                .border(Color.gray, width: 1) // Border for visual separation.
                .padding(.horizontal)


                // MARK: Send Controls
                // HStack containing the TextField for message input and the "Send" button.
                HStack {
                    TextField("Enter message", text: $messageToSend)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // Disable TextField if not connected or if the write characteristic is not available.
                        .disabled(bluetoothViewModel.connectedPeripheral == nil || bluetoothViewModel.writeCharacteristic == nil)

                    Button("Send") {
                        if !messageToSend.isEmpty {
                            bluetoothViewModel.send(string: messageToSend) // Call ViewModel's send method.
                            // `statusMessage` in ViewModel might briefly show "Sent:..."
                            messageToSend = "" // Clear the TextField after sending.
                        }
                    }
                    // Disable "Send" button if not connected, write characteristic unavailable, or message is empty.
                    .disabled(bluetoothViewModel.connectedPeripheral == nil || bluetoothViewModel.writeCharacteristic == nil || messageToSend.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)

                // MARK: Scan Controls
                // Dynamic button for starting or stopping the Bluetooth scan.
                Button(action: {
                    // Toggle scanning state based on `bluetoothViewModel.isScanning`.
                    if bluetoothViewModel.isScanning {
                        bluetoothViewModel.stopScanning()
                    } else {
                        bluetoothViewModel.startScanning()
                    }
                }) {
                    // Button label changes based on scanning state.
                    Text(bluetoothViewModel.isScanning ? "Stop Scan" : "Start Scan")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        // Background color changes based on scanning state and Bluetooth power state.
                        .background(bluetoothViewModel.isScanning ? Color.red : (bluetoothViewModel.isBluetoothPoweredOn && bluetoothViewModel.connectedPeripheral == nil ? Color.blue : Color.gray))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                // Disable scan button if a peripheral is connected OR if Bluetooth is not powered on.
                // This prevents scanning when already interacting with a device or when Bluetooth is unavailable.
                .disabled(bluetoothViewModel.connectedPeripheral != nil || !bluetoothViewModel.isBluetoothPoweredOn)
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
