//
//  SmartCamCommunicator.swift
//  SmartCamViewer
//
//  Created by Marin Kajtazi on 02/12/2019.
//  Copyright © 2019 Marin Kajtazi. All rights reserved.
//

import Cocoa
import Network

private struct Constants {
    static let pictureWidth = 320
    static let pictureHeight = 320
    static let bufferLength = pictureWidth * pictureHeight * 2
}

enum ConnectionStatus {
    case Setup
    case Preparing
    case Waiting
    case Ready
    case Failed
    case Cancelled
}

protocol SmartCamCommunicatorDelegate {
    func connectionStatusChanged(to status : ConnectionStatus)
    func imagesChanged(leftImage : Data, rightImage : Data, width: Int, height: Int)
}

class SmartCamCommunicator {

    // MARK: Public properties
    var delegate : SmartCamCommunicatorDelegate?
    
    // MARK: Private properties
    private var connectionAlive : Bool = false
    private var connection : NWConnection! // Implicitly unwrapped optional
    private let hostEndpoint : NWEndpoint.Host
    private let portEndpoint : NWEndpoint.Port?
    
    // MARK: Constructors
    init(ipAddress : String, port: String) {
        hostEndpoint = NWEndpoint.Host.init(ipAddress)
        portEndpoint = NWEndpoint.Port.init(port)
    }
    
    // MARK: Public methods
    func start() {
        connection = NWConnection(host: hostEndpoint, port: portEndpoint!, using: .tcp)
        connection.stateUpdateHandler = stateDidChange(to:)
        connection.start(queue: DispatchQueue.global())
    }
    
    func stop() {
        connection?.cancel()
    }
    
    // MARK: Private methods
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            delegate?.connectionStatusChanged(to: .Setup)
        case .preparing:
            delegate?.connectionStatusChanged(to: .Preparing)
        case .waiting(let error):
            delegate?.connectionStatusChanged(to: .Waiting)
            print("The connection is waiting for a network path change: " + error.localizedDescription)
        case .ready:
            delegate?.connectionStatusChanged(to: .Ready)
            sendOneByte()
        case .failed(let error):
            delegate?.connectionStatusChanged(to: .Failed)
            print("The connection has disconnected or encountered an error: " + error.localizedDescription)
        case .cancelled:
            delegate?.connectionStatusChanged(to: .Cancelled)
        default:
            break
        }
    }
    
    private func sendOneByte() {
        var num : UInt8 = 2
        let data = Data(bytes: &num, count: 1)
        
        connection.send(content: data, completion: .contentProcessed({error in
            if let error = error {
                print("sendEndOfStream: error \(error.localizedDescription)")
                self.connection!.cancel()
            }
            else {
                self.recvOneByte()
            }
        }))
    }
    
    private func recvOneByte() {
        self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, contectContext, isComplete, error in
            if isComplete {
                print("receive: isComplete handle end of stream")
                self.connection!.cancel()
            }
            else if let error = error {
                print("receive: error \(error.localizedDescription)")
            }
            else {
                if let data = data, !data.isEmpty {
                    if data[0] == 0x00 {
                        print("No image data coming")
                        Thread.sleep(forTimeInterval: 0.25)
                        self.sendOneByte()
                    }
                    else {
                        print("Image data coming")
                        self.recvImages()
                    }
                }
            }
        }
    }
    
    private func recvImages() {
        print("Buffer length \(Constants.bufferLength)")
        self.connection.receive(minimumIncompleteLength: Constants.bufferLength, maximumLength: Constants.bufferLength) { data, contectContext, isComplete, error in
            if isComplete {
                print("receive: isComplete handle end of stream")
                self.connection!.cancel()
            }
            else if let error = error {
                print("receive: error \(error.localizedDescription)")
            }
            else {
                if let data = data, !data.isEmpty {
                    let leftImageData = data[0..<Constants.bufferLength/2]
                    let rightImageData = data[Constants.bufferLength/2..<Constants.bufferLength]
                    self.delegate?.imagesChanged(leftImage: leftImageData,
                                                 rightImage: rightImageData,
                                                 width: Constants.pictureWidth,
                                                 height: Constants.pictureHeight)
                    self.sendOneByte()
                }
            }
        }
    }
}
