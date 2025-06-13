import SwiftUI
import CoreBluetooth

// Color constants (approximations based on HTML mockup)
private let appBackgroundColor = Color(UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)) // bg-white
private let appPrimaryTextColor = Color(UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)) // #141414
private let appSecondaryTextColor = Color(UIColor(red: 0.46, green: 0.46, blue: 0.46, alpha: 1.0)) // #757575
private let textFieldBorderColor = Color(UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)) // #e0e0e0
private let disconnectButtonBackgroundColor = Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)) // #f2f2f2

struct DeviceControlView: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    var peripheral: CBPeripheral // The peripheral to control

    @State private var commandToSend: String = ""
    @Environment(\.presentationMode) var presentationMode // To dismiss the view on disconnect

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Device Info" Section Title
            Text("Device Info")
                .font(.title3.bold()) // Updated font
                .foregroundColor(appPrimaryTextColor) // Updated color
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)) // Updated padding

            // Name
            InfoRow(label: "Name", value: peripheral.name ?? "N/A")

            // UUID
            InfoRow(label: "UUID", value: peripheral.identifier.uuidString)

            // "Connection Status" Section Title
            Text("Connection Status")
                .font(.title3.bold()) // Updated font
                .foregroundColor(appPrimaryTextColor) // Updated color
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)) // Updated padding

            HStack {
                Text(bluetoothViewModel.statusMessage)
                    .font(.body) // Updated font
                    .foregroundColor(appPrimaryTextColor) // Updated color
                    .padding(.horizontal, 16) // Updated padding
                Spacer()
            }
            .frame(minHeight: 30)
            .padding(.bottom, 16) // Updated padding


            // "Send Command" Section Title
            Text("Send Command")
                .font(.title3.bold()) // Updated font
                .foregroundColor(appPrimaryTextColor) // Updated color
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)) // Updated padding

            TextField("Enter command", text: $commandToSend)
                .textFieldStyle(PlainTextFieldStyle()) // Apply PlainTextFieldStyle
                .padding(15) // Inner padding for text
                .frame(height: 50) // h-14 (56px) approx, border will add to this
                .background(appBackgroundColor) // Explicit background for TextField
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(textFieldBorderColor)) // Border
                .padding(.horizontal, 16) // Outer padding
                .padding(.bottom, 16) // Outer padding


            // "Received Messages" Section Title
            Text("Received Messages")
                .font(.title3.bold()) // Updated font
                .foregroundColor(appPrimaryTextColor) // Updated color
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)) // Updated padding

            ScrollView {
                VStack(alignment: .leading) {
                    if bluetoothViewModel.receivedMessages.isEmpty {
                        Text("No messages yet. Send a command to see responses.")
                            .foregroundColor(appSecondaryTextColor) // Use an appropriate color
                            .padding() // Add some padding
                            .frame(maxWidth: .infinity, alignment: .center) // Center if desired
                    } else {
                        ForEach(bluetoothViewModel.receivedMessages.suffix(20), id: \.self) { message in
                            Text(message)
                                .font(.body) // Updated font
                                .foregroundColor(appPrimaryTextColor) // Updated color
                                .padding(.vertical, 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16) // Updated padding
            }
            .frame(minHeight: 100, maxHeight: 200) // Updated frame
            .padding(.bottom, 16) // Updated padding

            Spacer() // Pushes buttons to the bottom

            // Bottom Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    if !commandToSend.isEmpty {
                        bluetoothViewModel.send(string: commandToSend)
                        commandToSend = "" // Clear after sending
                    }
                }) {
                    Text("Send Command")
                        .font(.caption.bold())
                        .foregroundColor(Color.white) // Updated text color
                        .frame(maxWidth: .infinity)
                        .frame(height: 40) // h-10
                        .background(Color.black)
                        .clipShape(Capsule()) // Updated shape
                }
                .disabled(bluetoothViewModel.connectedPeripheral == nil || bluetoothViewModel.writeCharacteristic == nil || commandToSend.isEmpty)

                Button(action: {
                    bluetoothViewModel.disconnect()
                }) {
                    Text("Disconnect")
                        .font(.caption.bold())
                        .foregroundColor(appPrimaryTextColor) // Updated text color
                        .frame(maxWidth: .infinity)
                        .frame(height: 40) // h-10
                        .background(disconnectButtonBackgroundColor) // Updated background
                        .clipShape(Capsule()) // Updated shape
                }
                .disabled(bluetoothViewModel.connectedPeripheral == nil)
            }
            .padding(.horizontal, 16) // Updated padding
            .padding(.bottom, 20)
        }
        .background(appBackgroundColor.edgesIgnoringSafeArea(.all)) // Overall background
        .navigationTitle(peripheral.name ?? "Bluetooth Module")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if bluetoothViewModel.connectedPeripheral != peripheral {
                bluetoothViewModel.connect(to: peripheral)
            }
            commandToSend = ""
        }
        .onChange(of: bluetoothViewModel.connectedPeripheral) { newValue in
            if newValue == nil && presentationMode.wrappedValue.isPresented {
                if bluetoothViewModel.connectedPeripheral?.identifier != peripheral.identifier {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// Helper view for consistent info rows
struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.body.weight(.medium))
                .foregroundColor(appPrimaryTextColor) // Updated color
            Text(value)
                .font(.callout)
                .foregroundColor(appSecondaryTextColor) // Updated color
        }
        .padding(.horizontal, 16) // Updated padding
        .frame(minHeight: 36, alignment: .leading) // Updated frame
        .padding(.vertical, 6)
    }
}

// Preview provider (remains challenging without full mock objects)
struct DeviceControlView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Text("DeviceControlView Preview (Complex to fully mock)")
        }
    }
}
