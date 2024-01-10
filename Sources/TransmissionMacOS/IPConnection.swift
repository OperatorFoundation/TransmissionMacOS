//
//  IPConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 3/11/23.
//

import Foundation
#if os(macOS)
import os.log
#else
import Logging
#endif
import Network

import Chord
import Datable
import SwiftHexTools
import SwiftQueue
import TransmissionBase
import TransmissionTypes
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))

import Network

public class IPConnection: BaseConnection
{
    var buffer: Data = Data()
    let log: Logger?
    let states: BlockingQueue<Bool> = BlockingQueue<Bool>()
    let startQueue = DispatchQueue(label: "TransmissionConnection")

    var connection: NWConnection
    var connectionClosed = false

    public convenience init?(host: String, port: Int, using connectionType: ConnectionType = .tcp, logger: Logger? = nil)
    {
        let nwhost = NWEndpoint.Host(host)
        let port16 = UInt16(port)
        let nwport = NWEndpoint.Port(integerLiteral: port16)

        let nwconnection: NWConnection
        switch connectionType
        {
            case .tcp:
                nwconnection = NWConnection(host: nwhost, port: nwport, using: .tcp)
            case .udp:
                nwconnection = NWConnection(host: nwhost, port: nwport, using: .udp)
        }
        
        self.init(connection: nwconnection, logger: logger)
    }

    public init?(connection: NWConnection, logger: Logger? = nil)
    {
        self.connection = connection
        self.log = logger
        
        let newID = UUID()
        super.init(id: newID.hashValue)
        
        self.connection.stateUpdateHandler = self.handleState
        self.connection.start(queue: startQueue)
        
        let success = self.states.dequeue()
        guard success else {return nil}
    }

    func handleState(state: NWConnection.State)
    {
        switch state
        {
            case .ready:
                self.states.enqueue(element: true)
                return
            case .cancelled:
                self.states.enqueue(element: false)
                self.close()
                return
            case .failed(let error):
                print(error)
                self.states.enqueue(element: false)
                self.failConnect()
                return
            case .waiting(let error):
                print(error)
                self.states.enqueue(element: false)
                self.close()
                return
            default:
                return
        }
    }

    func failConnect()
    {
        self.log?.debug("TransmissionMacOS: TransmissionConnection received a failed state. Closing connection.")
        close()
    }

    public override func close()
    {
        if !connectionClosed
        {
            self.log?.debug("TransmissionMacOS: TransmissionConnection is closing the connection")
            self.connectionClosed = true
            self.connection.cancel()
            self.connection.stateUpdateHandler = nil
        }
        else
        {
            self.log?.debug("TransmissionMacOS: TransmissionConnection close requested, but the connection is already closed.")
        }
    }

    public override func networkRead(size: Int) throws -> Data
    {
        let result: Result<Data, Error> = Synchronizer.sync
        {
            callback in

            self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
            {
                content, contentContext, isComplete, maybeError in

                if let error = maybeError
                {
                    callback(.failure(error))
                }
                else if let data = content
                {
                    callback(.success(data))
                }
                else
                {
                    callback(.failure(TCPConnectionError.nilData))
                }
            }
        }

        switch result
        {
            case .success(let success):
                return success

            case .failure(let failure):
                throw failure
        }
    }

    public override func networkWrite(data: Data) throws
    {
        let maybeError: Error? = Synchronizer.sync
        {
            callback in

            self.connection.send(content: data, contentContext: NWConnection.ContentContext.defaultStream, completion: .contentProcessed(callback))
        }

        if let error = maybeError
        {
            throw error
        }
    }
}

public enum IPConnectionError: Error
{
    case receiveError
    case nilData
}

#endif
