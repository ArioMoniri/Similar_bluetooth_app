
// Test line - remove after testing

import SwiftUI
import CoreBluetooth

// Color constants (approximations based on HTML mockup)
private let appBackgroundColor = Color(UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)) // #f8f8f8 (bg-neutral-50)
private let appPrimaryTextColor = Color(UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)) // #141414
private let appSecondaryTextColor = Color.gray // For UUIDs, text-neutral-500
private let appTertiaryTextColor = Color(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)) // Slightly darker gray for chevrons if needed
private let appButtonTextColor = Color.white // For text on dark buttons (text-neutral-50)
private let appActiveScanButtonColor = Color.black // For the "Scan" button background

struct DeviceListView: View {
    @StateObject var bluetoothViewModel = BluetoothViewModel()
    @State private var selectedPeripheral: CBPeripheral?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // FIXED: Break down complex expression - Custom Top Bar
                CustomTopBar()
                
                // FIXED: Break down complex expression - Section Title
                SectionTitle()
                
                // FIXED: Break down complex expression - Device List or Empty State
                DeviceListContent(
                    bluetoothViewModel: bluetoothViewModel,
                    selectedPeripheral: $selectedPeripheral
                )
                
                Spacer()
                
                // FIXED: Break down complex expression - Scan Button
                ScanButton(bluetoothViewModel: bluetoothViewModel)
            }
            .background(appBackgroundColor.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear {
                if !bluetoothViewModel.isScanning && bluetoothViewModel.isBluetoothPoweredOn {
                    bluetoothViewModel.statusMessage = "Ready to scan."
                }
            }
        }
    }
}

// FIXED: Extract CustomTopBar to separate view
struct CustomTopBar: View {
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
        .padding(.top, getSafeAreaTop())
        .background(appBackgroundColor)
    }
    
    // FIXED: Extract safe area calculation to separate function
    private func getSafeAreaTop() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 0
    }
}

// FIXED: Extract SectionTitle to separate view
struct SectionTitle: View {
    var body: some View {
        HStack {
            Text("Discovered Devices")
                .font(.title3.bold())
                .foregroundColor(appPrimaryTextColor)
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
        .background(appBackgroundColor)
    }
}

// FIXED: Extract DeviceListContent to separate view
struct DeviceListContent: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @Binding var selectedPeripheral: CBPeripheral?
    
    var body: some View {
        if bluetoothViewModel.discoveredPeripherals.isEmpty {
            EmptyStateView(isScanning: bluetoothViewModel.isScanning)
        } else {
            DeviceList(
                bluetoothViewModel: bluetoothViewModel,
                selectedPeripheral: $selectedPeripheral
            )
        }
    }
}

// FIXED: Extract EmptyStateView to separate view
struct EmptyStateView: View {
    let isScanning: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if isScanning {
                Text("Scanning for devices...")
                    .foregroundColor(appSecondaryTextColor)
                    .padding()
            } else {
                Text("No devices found. Tap 'Scan' to discover.")
                    .foregroundColor(appSecondaryTextColor)
                    .padding()
            }
            Spacer()
        }
    }
}

// FIXED: Extract DeviceList to separate view
struct DeviceList: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @Binding var selectedPeripheral: CBPeripheral?
    
    var body: some View {
        List {
            ForEach(bluetoothViewModel.discoveredPeripherals, id: \.identifier) { peripheral in
                // FIXED: Use the correct DeviceControlView name and structure
                NavigationLink(
                    destination: DeviceControlView(
                        bluetoothViewModel: bluetoothViewModel,
                        peripheral: peripheral
                    ),
                    tag: peripheral,
                    selection: $selectedPeripheral
                ) {
                    DeviceRowView(peripheral: peripheral)
                }
                .listRowBackground(appBackgroundColor)
                .onTapGesture {
                    selectedPeripheral = peripheral
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
    }
}

// FIXED: Extract DeviceRowView to separate view with corrected padding
struct DeviceRowView: View {
    let peripheral: CBPeripheral
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.body.weight(.medium))
                    .foregroundColor(appPrimaryTextColor)
                    .lineLimit(1)
                Text("UUID: \(peripheral.identifier.uuidString)")
                    .font(.callout)
                    .foregroundColor(appSecondaryTextColor)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(appTertiaryTextColor)
        }
        // FIXED: Use explicit EdgeInsets instead of .symmetric
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .frame(minHeight: 56)
    }
}

// FIXED: Extract ScanButton to separate view
struct ScanButton: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    
    var body: some View {
        Button(action: {
            if bluetoothViewModel.isScanning {
                bluetoothViewModel.stopScanning()
            } else {
                bluetoothViewModel.startScanning()
            }
        }) {
            Text(bluetoothViewModel.isScanning ? "Stop Scan" : "Scan")
                .font(.headline)
                .foregroundColor(appButtonTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(scanButtonColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .disabled(!bluetoothViewModel.isBluetoothPoweredOn && !bluetoothViewModel.isScanning)
    }
    
    private var scanButtonColor: Color {
        if bluetoothViewModel.isScanning {
            return Color.red
        } else if bluetoothViewModel.isBluetoothPoweredOn {
            return appActiveScanButtonColor
        } else {
            return Color.gray
        }
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
}
