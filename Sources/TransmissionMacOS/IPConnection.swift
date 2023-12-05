//
//  IPConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 3/11/23.
//

import Foundation
#if os(macOS) || os(iOS)
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

    public func networkRead(size: Int, timeoutSeconds: Int) throws -> Data
    {
        var result: Data?

        let lock: DispatchSemaphore = DispatchSemaphore(value: 0)

        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            guard maybeError == nil else
            {
                print(maybeError!)
                lock.signal()
                return
            }

            if let data = maybeData
            {
                if data.count == size
                {
                    result = data
                }
                else
                {
                    self.log?.debug("Read request for size \(size), but we only received \(data.count) bytes.")
                    result = nil
                }
            }

            lock.signal()
            return
        }

        let waitResult = lock.wait(timeout: DispatchTime.now().advanced(by: .seconds(timeoutSeconds)))
        switch waitResult
        {
            case .success:
                if let result
                {
                    return result
                }
                else
                {
                    throw TCPConnectionError.nilData
                }

            case .timedOut:
                throw TCPConnectionError.timeout
        }    }

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
