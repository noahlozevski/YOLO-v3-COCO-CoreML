//
//  M365Info.swift
//  ble-ios
//
//  Created by Michał Jach on 11/07/2019.
//  Copyright © 2019 Michał Jach. All rights reserved.
//

import Foundation
import CoreBluetooth

let scooterName = "MIScooter2222" //name of scooter follows form: MIScooterXXXX

//Commands
let powerOff : [UInt8] = [ 0x55, 0xaa, 0x03, 0x20, 0x03, 0x79, 0x01, 0x5f, 0xff ] //Power off
let cruiseOn : [UInt8] = [ 0x55, 0xaa, 0x04, 0x20, 0x03, 0x7c, 0x01, 0x00, 0x5b, 0xff] //Set cruise control on
let cruiseOff : [UInt8] = [ 0x55, 0xaa, 0x04, 0x20, 0x03, 0x7c, 0x00, 0x00, 0x5b, 0xff] //CC off
let readSpeed : [UInt8] = [0x55, 0xaa, 0x03, 0x20, 0x01, 0xb5, 0x02, 0x24, 0xff] //reads speed
let slowDown : [UInt8] = [0x55, 0xAA, 0x07, 0x20, 0x65, 0x00, 0x04, 0x04, 0x01, 0x00, 0x01, 0x00, 0x00] //Lowers CC speed to 5km/h (to simulate braking in presense of object)

var txCharacteristic : CBCharacteristic?
var rxCharacteristic : CBCharacteristic?
var characteristicASCIIValue = NSString()

protocol M365DataDelegate {
    func didUpdateValues(values: [String:String])
}

protocol M365DevicesDelegate {
    func didDiscoverDevice(peripheral: CBPeripheral)
    func didConnect(peripheral: CBPeripheral)
}

protocol M365StateDelegate {
    func didChangeState(state: CBManagerState)
}

class M365Info: NSObject {
    public var centralManager: CBCentralManager!
    public var dataDelegate: M365DataDelegate?
    public var devicesDelegate: M365DevicesDelegate?
    public var stateDelegate: M365StateDelegate?
    public var devices: [CBPeripheral] = []
    public var connectedDevice: CBPeripheral?
 //   var thePer
    
    var values: [String: String] = [:]
    
    private let writeCharacterisitc = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let readCharacterisitc = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    
    private var speedTimer: Timer?
    
    
    var payloads: [[UInt8]] = [
        [0x55, 0xAA, 0x03, 0x20, 0x01, 0x10, 0x0e, 0xbd, 0xFF], // Serial Number
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x1A, 0x02, 0xbf, 0xff], // Firmware Version
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x22, 0x02, 0xb7, 0xff], // Battery Level
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x3e, 0x02, 0x9b, 0xff], // Body Temperature
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x29, 0x04, 0xae, 0xff], // Total mileage
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x47, 0x02, 0x92, 0xff], // Voltage
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0xb5, 0x02, 0x24, 0xff], // Current speed
        [0x55, 0xaa, 0x04, 0x20, 0x03, 0x7c, 0x01, 0x00, 0x5b, 0xff] //cruise cntl commad
    ]
    
    required override init() {
        super.init()

        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func discover() {
        centralManagerDidUpdateState(self.centralManager)
        centralManager.scanForPeripherals(withServices: nil)
    }
    
    
    func connect(device: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connect(device, options: nil)
    }
    
    func disconnect() {
        if let connectedDevice = connectedDevice {
            speedTimer?.invalidate()
            centralManager.cancelPeripheralConnection(connectedDevice)
        }
    }
}

extension M365Info: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        case .poweredOff:
            print("poweredOff")
            centralManager?.stopScan()
        case .poweredOn:
            print("poweredOn")
            centralManager?.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if devices.filter({ $0.name == peripheral.name }).count == 0 {
            //print("We found a new pheripheral devices with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print ("Advertisement Data : \(advertisementData)")
            devices.append(peripheral)
            devicesDelegate?.didDiscoverDevice(peripheral: peripheral)
            
            if (peripheral.name == scooterName){ //
                centralManager.stopScan()
                centralManager.connect(peripheral)
                print("Connected to scooter\n")
                }
               // thePer = peripheral
            }
        }
    }
    
    /*func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        connectedDevice = peripheral
        devicesDelegate?.didConnect(peripheral: peripheral)
        peripheral.discoverServices([])
        
        let sendBytes : [UInt8] = [ 0x55, 0xaa, 0x03, 0x20, 0x03, 0x70, 0x01, 0x68, 0xff]
        let valueString = Data(bytes:sendBytes)
                
        peripheral.writeValue(valueString, for: txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        }
}*/

extension M365Info: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([], for: service)
        }
    }
    /*
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("\n\nRx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("\n\nTx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }*/
    
  /*  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic == rxCharacteristic {
            if let ASCIIstring = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) {
                characteristicASCIIValue = ASCIIstring
                print("Value Recieved: \((characteristicASCIIValue as String))")
                NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)
                
            }
        }
    }*/
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == self.writeCharacterisitc {
                
                print("Sending commands\n\n")
                let valueString = Data(bytes:slowDown)
                peripheral.writeValue(valueString, for: characteristic, type: .withoutResponse)
                
                 for payload in payloads { //sends all commands in payloads array
                     if payload == payloads[6] { //stops at speed reading command
                        self.speedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
                            peripheral.writeValue(Data(payload), for: characteristic, type: .withoutResponse)
                        })
                        self.speedTimer?.fire()
                    } else {
                        peripheral.writeValue(Data(payload), for: characteristic, type: .withoutResponse)
                        sleep(1) //delay before sends
                    }
                    
                }
            }
            if characteristic.uuid == self.readCharacterisitc {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.value!.count > 6 {
            let cmd = characteristic.value![5..<6].map { String(format: "%02hhX", $0) }[0]
            let value = characteristic.value![6..<characteristic.value!.count-2]
            switch cmd {
                case "1A":
                    values["Firmware Version"] = versionSerializer(bytes: value)
                    break
                case "10":
                    values["Serial Number"] = asciiSerializer(bytes: value)
                    break
                case "22":
                    values["Battery Level"] = numberSerializer(bytes: value) + "%"
                    break
                case "3E":
                    values["Body Temperature"] = numberSerializer(bytes: value, factor: 10) + "°C"
                    break
                case "29":
                    values["Total Mileage"] = distanceSerializer(bytes: value) + "km"
                    break
                case "47":
                    values["Voltage"] = numberSerializer(bytes: value, format: "%.2f", factor: 100) + "V"
                    break
                case "B5":
                    values["Current Speed"] = numberSerializer(bytes: value, format: "%.2f", factor: 1000) + "km/h"
                    break
                case "74":
                    values["Speed Limit"] = numberSerializer(bytes: value, format: "%.2f", factor: 1000) + "km/h"
                    break
                case "72":
                    values["Limit Enabled"] = numberSerializer(bytes: value)
                    break
                default:
                    print("unrecognized value")
                    break
            }
            dataDelegate?.didUpdateValues(values: values)
        }
    }
    
    func swapBytes(data: Data) -> Data {
        var mdata = data
        let count = data.count / MemoryLayout<UInt16>.size
        mdata.withUnsafeMutableBytes { (i16ptr: UnsafeMutablePointer<UInt16>) in
            for i in 0..<count {
                i16ptr[i] = i16ptr[i].byteSwapped
            }
        }
        return mdata
    }
    
    func distanceSerializer(bytes: Data) -> String {
        let bytesArray = swapBytes(data: bytes).map { String(format: "%02hhX", $0) }
        let major = Int(bytesArray[0] + bytesArray[1], radix: 16)!
        let minor = Int(bytesArray[2] + bytesArray[3], radix: 16)!
        return String(format: "%.2f", Double(major + minor * 65536)/1000)
    }
    
    func versionSerializer(bytes: Data) -> String {
        let bytesArray = bytes.map { String(format: "%02hhX", $0) }
        let majorVersion = Int(bytesArray[1])!
        let minorVersion = Array(String(Int(bytesArray[0])!))[0]
        let subVersion = Array(String(Int(bytesArray[0])!))[1]
        return String(majorVersion) + "." + String(minorVersion) + "." + String(subVersion)
    }
    
    func asciiSerializer(bytes: Data) -> String {
        return String(data: bytes, encoding: String.Encoding.ascii)!
    }
    
    func numberSerializer(bytes: Data, format: String = "%.0f", factor: Int = 1) -> String {
        let hexString = swapBytes(data: bytes).map { String(format: "%02hhX", $0) }.joined()
        return String(format: format, Double(Int(hexString, radix: 16)!/factor))
    }
}
