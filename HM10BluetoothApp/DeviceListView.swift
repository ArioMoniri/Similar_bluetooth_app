import SwiftUI
import CoreBluetooth // For CBPeripheral

// Color constants (approximations based on HTML mockup)
private let appBackgroundColor = Color(UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)) // #f8f8f8 (bg-neutral-50)
private let appPrimaryTextColor = Color(UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)) // #141414
private let appSecondaryTextColor = Color.gray // For UUIDs, text-neutral-500
private let appTertiaryTextColor = Color(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)) // Slightly darker gray for chevrons if needed
private let appButtonTextColor = Color.white // For text on dark buttons (text-neutral-50)
private let appActiveScanButtonColor = Color.black // For the "Scan" button background


struct DeviceListView: View {
    @StateObject var bluetoothViewModel = BluetoothViewModel()
    // To be used for navigation to DeviceControlView
    @State private var selectedPeripheral: CBPeripheral?

    var body: some View {
        NavigationView { // Or NavigationStack for iOS 16+
            VStack(spacing: 0) {
                // Use the extracted CustomTopBarView
                CustomTopBarView()

                // "Discovered Devices" Section Title
                HStack {
                    Text("Discovered Devices")
                        .font(.title3.bold()) // Updated font
                        .foregroundColor(appPrimaryTextColor) // Updated color
                    Spacer()
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)) // px-4 pb-2 pt-4
                .background(appBackgroundColor) // Updated background


                // Device List
                if bluetoothViewModel.discoveredPeripherals.isEmpty {
                    Spacer() // Added Spacer
                    if bluetoothViewModel.isScanning {
                        Text("Scanning for devices...")
                            .foregroundColor(appSecondaryTextColor)
                            .padding()
                    } else {
                        Text("No devices found. Tap 'Scan' to discover.")
                            .foregroundColor(appSecondaryTextColor)
                            .padding()
                    }
                    Spacer() // Added Spacer
                } else {
                    List {
                        ForEach(bluetoothViewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                            NavigationLink(
                                destination: DeviceControlView(bluetoothViewModel: bluetoothViewModel, peripheral: peripheral),
                            tag: peripheral,
                            selection: $selectedPeripheral
                        ) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.body.weight(.medium)) // Updated font & weight
                                        .foregroundColor(appPrimaryTextColor) // Updated color
                                        .lineLimit(1)
                                    Text("UUID: \(peripheral.identifier.uuidString)")
                                        .font(.callout) // Updated font
                                        .foregroundColor(appSecondaryTextColor) // Updated color
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(appTertiaryTextColor) // Updated color for chevron
                            }
                            .padding(.symmetric(horizontal: 16, vertical: 8)) // Content padding within the row
                            .frame(minHeight: 56) // min-h-[72px] approx (content 56 + padding 8+8 = 72)
                        }
                        .listRowBackground(appBackgroundColor) // Set background for each row
                        .onTapGesture {
                            if bluetoothViewModel.connectedPeripheral != peripheral {
                                // Optional: Initiate connection early.
                                // bluetoothViewModel.connect(to: peripheral)
                            }
                            self.selectedPeripheral = peripheral // Explicitly set to trigger navigation
                        }
                    }
                }
                .listStyle(PlainListStyle()) // Keep PlainListStyle
                .scrollContentBackground(.hidden) // Necessary for List background color in iOS 16+
                .background(appBackgroundColor) // Apply background to the List itself
                } // End of Else for List


                Spacer() // Pushes scan button to bottom

                // Scan Button
                Button(action: {
                    if bluetoothViewModel.isScanning {
                        bluetoothViewModel.stopScanning()
                    } else {
                        bluetoothViewModel.startScanning()
                    }
                }) {
                    Text(bluetoothViewModel.isScanning ? "Stop Scan" : "Scan")
                        .font(.headline) // text-base font-bold (matches HTML)
                        .foregroundColor(appButtonTextColor) // Updated text color
                        .frame(maxWidth: .infinity)
                        .frame(height: 48) // h-12
                        .background(bluetoothViewModel.isScanning ? Color.red : (bluetoothViewModel.isBluetoothPoweredOn ? appActiveScanButtonColor : Color.gray)) // Updated background logic
                        .clipShape(Capsule()) // rounded-full
                }
                .padding(.horizontal, 16) // px-4
                .padding(.bottom, 20) // Consistent bottom padding
                // Disable if BT is off, unless already scanning (though scanning shouldn't be possible if BT is off after init)
                .disabled(!bluetoothViewModel.isBluetoothPoweredOn && !bluetoothViewModel.isScanning)
            }
            .background(appBackgroundColor.edgesIgnoringSafeArea(.all)) // Ensure overall background
            .navigationBarHidden(true) // Keep custom navigation bar
            .onAppear {
                 // Ensure status message is reasonable for this view
                 if !bluetoothViewModel.isScanning && bluetoothViewModel.isBluetoothPoweredOn {
                    bluetoothViewModel.statusMessage = "Ready to scan."
                 }
            }
        }
        // If BluetoothViewModel needs to be shared with other top-level views,
        // it should be instantiated in the App struct and passed via .environmentObject()
        // or as an @ObservedObject from an ancestor.
        // For this view being the root, @StateObject is appropriate for self-contained ownership.
    }
}

// Helper view for the custom top bar
private struct CustomTopBarView: View {
    // These constants are defined at the file level in DeviceListView.swift
    // and are accessible here as this struct is in the same file.

    var body: some View {
        HStack {
            Spacer()
            Text("Bluetooth Devices")
                .font(.title3.bold())
                .foregroundColor(appPrimaryTextColor)
                .padding(.leading, 48)
            Spacer()
            Button(action: {
                print("Settings button tapped")
            }) {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(appPrimaryTextColor)
            }
            .padding(.trailing, 16)
        }
        .padding(.horizontal)
        .frame(height: 44)
        .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
        .background(appBackgroundColor)
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
}
