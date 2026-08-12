import Flutter
import UIKit
import CoreBluetooth

public class FlutterNfcAcsPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterStreamHandler {

    private static let CONNECT = "CONNECT"
    private static let DISCONNECT = "DISCONNECT"

    private static let CONNECTED = "CONNECTED"
    private static let CONNECTING = "CONNECTING"
    private static let DISCONNECTED = "DISCONNECTED"
    private static let DISCONNECTING = "DISCONNECTING"
    private static let UNKNOWN_CONNECTION_STATE = "UNKNOWN_CONNECTION_STATE"

    private static let ERROR_MISSING_ADDRESS = "missing_address"
    private static let ERROR_DEVICE_NOT_FOUND = "device_not_found"
    private static let ERROR_NO_PERMISSIONS = "no_permissions"

    // ACR1255U-J1 UUIDs
    private static let acsServiceUUID = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    private static let acsServiceUUID2 = CBUUID(string: "3C4AFFF0-4783-3DE5-A983-D348718EF133")
    private static let commandTxUUID = CBUUID(string: "0000FFF1-0000-1000-8000-00805F9B34FB")
    private static let commandRxUUID = CBUUID(string: "0000FFF2-0000-1000-8000-00805F9B34FB")

    private static let batteryServiceUUID = CBUUID(string: "180F")
    private static let batteryLevelUUID = CBUUID(string: "2A19")

    private static let defaultMasterKey: [UInt8] = [65, 67, 82, 49, 50, 53, 53, 85, 45, 74, 49, 32, 65, 117, 116, 104] // ACR1255U-J1 Auth

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?

    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var deviceMap: [String: String] = [:]

    // Stream Sinks
    private var devicesSink: FlutterEventSink?
    private var statusSink: FlutterEventSink?
    private var batterySink: FlutterEventSink?
    private var cardSink: FlutterEventSink?

    private var targetAddress: String?
    private var connectionState: String = DISCONNECTED

    private var currentPage: Int = 1
    private var combineHex: String = ""
    private var defaultHex: String = ""
    private var foundEoR: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterNfcAcsPlugin()

        let channel = FlutterMethodChannel(name: "flutter.vnet.com/nfc/acs", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)

        let devicesChannel = FlutterEventChannel(name: "flutter.vnet.com/nfc/acs/devices", binaryMessenger: registrar.messenger())
        devicesChannel.setStreamHandler(DevicesStreamHandler(plugin: instance))

        let statusChannel = FlutterEventChannel(name: "flutter.vnet.com/nfc/acs/device/status", binaryMessenger: registrar.messenger())
        statusChannel.setStreamHandler(StatusStreamHandler(plugin: instance))

        let batteryChannel = FlutterEventChannel(name: "flutter.vnet.com/nfc/acs/device/battery", binaryMessenger: registrar.messenger())
        batteryChannel.setStreamHandler(BatteryStreamHandler(plugin: instance))

        let cardChannel = FlutterEventChannel(name: "flutter.vnet.com/nfc/acs/device/card", binaryMessenger: registrar.messenger())
        cardChannel.setStreamHandler(CardStreamHandler(plugin: instance))
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterNfcAcsPlugin.CONNECT:
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: FlutterNfcAcsPlugin.ERROR_MISSING_ADDRESS, message: "Address argument required", details: nil))
                return
            }

            targetAddress = address
            if connect(to: address) {
                result(nil)
            } else {
                result(FlutterError(code: FlutterNfcAcsPlugin.ERROR_DEVICE_NOT_FOUND, message: "Device not found", details: nil))
            }

        case FlutterNfcAcsPlugin.DISCONNECT:
            disconnect()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connect(to address: String) -> Bool {
        updateConnectionState(FlutterNfcAcsPlugin.CONNECTING)
        if let peripheral = discoveredPeripherals[address] {
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            return true
        } else if let uuid = UUID(uuidString: address),
                  let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            return true
        }
        updateConnectionState(FlutterNfcAcsPlugin.DISCONNECTED)
        return false
    }

    private func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        updateConnectionState(FlutterNfcAcsPlugin.DISCONNECTED)
    }

    private func updateConnectionState(_ state: String) {
        connectionState = state
        DispatchQueue.main.async { [weak self] in
            self?.statusSink?(state)
        }
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        } else {
            updateConnectionState(FlutterNfcAcsPlugin.DISCONNECTED)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let identifier = peripheral.identifier.uuidString
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown ACS Device"

        discoveredPeripherals[identifier] = peripheral
        deviceMap[identifier] = name

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.devicesSink?(self.deviceMap)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        updateConnectionState(FlutterNfcAcsPlugin.CONNECTED)
        peripheral.discoverServices([FlutterNfcAcsPlugin.acsServiceUUID, FlutterNfcAcsPlugin.acsServiceUUID2, FlutterNfcAcsPlugin.batteryServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateConnectionState(FlutterNfcAcsPlugin.DISCONNECTED)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        updateConnectionState(FlutterNfcAcsPlugin.DISCONNECTED)
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, error == nil else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics, error == nil else { return }
        for characteristic in characteristics {
            if characteristic.uuid == FlutterNfcAcsPlugin.commandRxUUID || characteristic.properties.contains(.notify) {
                rxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == FlutterNfcAcsPlugin.commandTxUUID || characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                txCharacteristic = characteristic
            }
            if characteristic.uuid == FlutterNfcAcsPlugin.batteryLevelUUID {
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, error == nil else { return }

        if characteristic.uuid == FlutterNfcAcsPlugin.batteryLevelUUID {
            if let batteryLevel = data.first {
                DispatchQueue.main.async { [weak self] in
                    self?.batterySink?(Int(batteryLevel))
                }
            }
            return
        }

        // Handle Card / APDU Responses from ACS reader
        let bytes = [UInt8](data)
        handleAcsResponse(bytes)
    }

    private func handleAcsResponse(_ bytes: [UInt8]) {
        guard bytes.count >= 2 else { return }
        let hexString = bytes.dropLast(2).map { String(format: "%02X", $0) }.joined()

        if hexString.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.cardSink?("00000000000000000000000000000000")
            }
            return
        }

        if currentPage >= 5 {
            combineHex += hexString
        } else {
            defaultHex += hexString
        }

        if currentPage >= 5 {
            for b in bytes {
                if b == 0x00 {
                    foundEoR = true
                    break
                }
            }
        }

        if !foundEoR {
            currentPage += 4
            transmitApdu(pageToRead: currentPage)
        } else {
            let resultString: String
            if combineHex.count > 10 {
                let startIndex = combineHex.index(combineHex.startIndex, offsetBy: 10)
                let subStr = String(combineHex[startIndex...])
                resultString = hexToString(subStr) + ":" + defaultHex
            } else {
                resultString = defaultHex
            }

            DispatchQueue.main.async { [weak self] in
                self?.cardSink?(resultString)
            }
        }
    }

    private func transmitApdu(pageToRead: Int) {
        guard let peripheral = connectedPeripheral, let tx = txCharacteristic else { return }
        let pageLength: [UInt8] = [UInt8(pageToRead), 16]
        let apduHex = "FFB000" + pageLength.map { String(format: "%02X", $0) }.joined()
        if let apduBytes = hexToBytes(apduHex) {
            let data = Data(apduBytes)
            let type: CBCharacteristicWriteType = tx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(data, for: tx, type: type)
        }
    }

    private func hexToBytes(_ hex: String) -> [UInt8]? {
        var data = [UInt8]()
        var tempHex = hex
        while !tempHex.isEmpty {
            let sub = String(tempHex.prefix(2))
            tempHex = String(tempHex.dropFirst(2))
            if let byte = UInt8(sub, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        return data
    }

    private func hexToString(_ hex: String) -> String {
        var str = ""
        var tempHex = hex
        while !tempHex.isEmpty {
            let sub = String(tempHex.prefix(2))
            tempHex = String(tempHex.dropFirst(2))
            if let code = UInt8(sub, radix: 16), code != 0 {
                str.append(Character(UnicodeScalar(code)))
            }
        }
        return str
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }

    // Stream Handlers for individual channels
    class DevicesStreamHandler: NSObject, FlutterStreamHandler {
        unowned let plugin: FlutterNfcAcsPlugin
        init(plugin: FlutterNfcAcsPlugin) { self.plugin = plugin }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin.devicesSink = events
            events(plugin.deviceMap)
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin.devicesSink = nil
            return nil
        }
    }

    class StatusStreamHandler: NSObject, FlutterStreamHandler {
        unowned let plugin: FlutterNfcAcsPlugin
        init(plugin: FlutterNfcAcsPlugin) { self.plugin = plugin }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin.statusSink = events
            events(plugin.connectionState)
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin.statusSink = nil
            return nil
        }
    }

    class BatteryStreamHandler: NSObject, FlutterStreamHandler {
        unowned let plugin: FlutterNfcAcsPlugin
        init(plugin: FlutterNfcAcsPlugin) { self.plugin = plugin }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin.batterySink = events
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin.batterySink = nil
            return nil
        }
    }

    class CardStreamHandler: NSObject, FlutterStreamHandler {
        unowned let plugin: FlutterNfcAcsPlugin
        init(plugin: FlutterNfcAcsPlugin) { self.plugin = plugin }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            plugin.cardSink = events
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            plugin.cardSink = nil
            return nil
        }
    }
}
