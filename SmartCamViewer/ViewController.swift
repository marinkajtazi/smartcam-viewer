//
//  ViewController.swift
//  SmartCamViewer
//
//  Created by Marin Kajtazi on 02/12/2019.
//  Copyright © 2019 Marin Kajtazi. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, SmartCamCommunicatorDelegate {
    
    // MARK: Properties
    var communicator : SmartCamCommunicator?
    @IBOutlet var connectButton: NSButton!
    @IBOutlet var ipAddressTextField: NSTextField!
    @IBOutlet var portTextField: NSTextField!
    @IBOutlet var statusImageView: NSImageView!
    @IBOutlet var leftImageView: NSImageView!
    @IBOutlet var rightImageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // MARK: Actions
    @IBAction func connect(_ sender: Any) {
        if ipAddressTextField.stringValue.count < 1 {
            return
        }
        
        if portTextField.stringValue.count < 1 {
            return
        }
        
        communicator?.stop()
        communicator = SmartCamCommunicator(ipAddress: ipAddressTextField.stringValue, port: portTextField.stringValue)
        communicator!.delegate = self
        communicator!.start()
        
        connectButton.isEnabled = false
    }
    
    @IBAction func disconnect(_ sender: Any) {
        communicator?.stop()
        leftImageView.image = NSImage(named: "noimage") // NSImage.stopProgressTemplateName)
        rightImageView.image = NSImage(named: "noimage") // NSImage.stopProgressTemplateName)
        connectButton.isEnabled = false
    }
    
    // MARK: SmartCamCommunicatorDelegate method
    func connectionStatusChanged(to status: ConnectionStatus) {
        DispatchQueue.main.async {
            switch status {
            case .Setup, .Failed, .Cancelled:
                self.statusImageView.image = NSImage(named: NSImage.statusUnavailableName)
                self.connectButton.action = #selector(self.connect(_:))
                self.connectButton.title = "Connect"
            case .Ready:
                self.statusImageView.image = NSImage(named: NSImage.statusAvailableName)
                self.connectButton.action = #selector(self.disconnect(_:))
                self.connectButton.title = "Disconnect"
            case .Preparing, .Waiting:
                self.statusImageView.image = NSImage(named: NSImage.statusPartiallyAvailableName)
                self.connectButton.action = #selector(self.disconnect(_:))
                self.connectButton.title = "Cancel"
            }
            self.connectButton.isEnabled = true
        }
    }
    
    func imagesChanged(leftImage: Data, rightImage: Data, width: Int, height: Int) {
        DispatchQueue.main.async {
            
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            let imageSize = NSSize(width: width, height: height)
            
            guard let leftProvider = CGDataProvider(data: NSData(data: leftImage))
                else { return }
            guard let rightProvider = CGDataProvider(data: NSData(data: rightImage))
                else { return }
            
            guard let cgLeftImage = CGImage(width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bitsPerPixel: 8,
                                      bytesPerRow: width,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo,
                                      provider: leftProvider,
                                      decode: nil,
                                      shouldInterpolate: true,
                                      intent: .defaultIntent)
                else { return }

            
            guard let cgRightImage = CGImage(width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bitsPerPixel: 8,
                                       bytesPerRow: width,
                                       space: colorSpace,
                                       bitmapInfo: bitmapInfo,
                                       provider: rightProvider,
                                       decode: nil,
                                       shouldInterpolate: true,
                                       intent: .defaultIntent)
                else { return }
            
            
            self.leftImageView.image = NSImage(cgImage: cgLeftImage, size: imageSize)
            self.rightImageView.image = NSImage(cgImage: cgRightImage, size: imageSize)
        }
    }
}

