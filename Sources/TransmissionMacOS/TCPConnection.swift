//
//  TCPConnection.swift
//  TransmissionMacOS
//
//  Created by Dr. Brandon Wiley on 3/11/23.
//

import Foundation
#if os(macOS)
import os.log
#else
import Logging
#endif

import Chord
import Datable
import Network
import SwiftHexTools
import SwiftQueue
import TransmissionBase
import TransmissionTypes
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))

import Network

public class TCPConnection: IPConnection
{
    var readLock = DispatchSemaphore(value: 0)
    
    public override init?(host: String, port: Int, using: ConnectionType = .tcp, logger: Logger? = nil)
    {
        super.init(host: host, port: port, using: using, logger: logger)
    }

    public init?(connection: NWConnection, logger: Logger? = nil)
    {
        super.init(connection: connection, connectionType: .tcp, logger: logger)
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
        var result: Data?

        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            guard maybeError == nil else
            {
                print(maybeError!)
                self.readLock.signal()
                
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
            
            self.readLock.signal()
        }
        
        readLock.wait()

        if let result
        {
            return result
        }
        else
        {
            throw TCPConnectionError.nilData
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

public enum TCPConnectionError: Error
{
    case receiveError
    case nilData
}

#endif
