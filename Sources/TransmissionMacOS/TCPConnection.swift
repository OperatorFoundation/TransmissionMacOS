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
    public init?(host: String, port: Int, logger: Logger? = nil)
    {
        let nwhost = NWEndpoint.Host(host)
        let port16 = UInt16(port)
        let nwport = NWEndpoint.Port(integerLiteral: port16)
        let nwconnection = NWConnection(host: nwhost, port: nwport, using: .tcp)
        
        super.init(connection: nwconnection, logger: logger)
    }

    public override init?(connection: NWConnection, logger: Logger? = nil)
    {
        super.init(connection: connection, logger: logger)
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
        let tcpReadLock = DispatchSemaphore(value: 0)
        
        print("\n\nTransmissionMacOS: networkRead(size: \(size) is calling connection.receive...")
        
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in
            
            print("\n\nTransmissionMacOS: networkRead() returned from connection.receive")
                        
            guard maybeError == nil else
            {
                print("TransmissionMacOS: networkRead received an error: \(maybeError!)")
                tcpReadLock.signal()
                
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
            
            tcpReadLock.signal()
        }
        
        tcpReadLock.wait()

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

            self.connection.send(content: data, contentContext: NWConnection.ContentContext.defaultStream, isComplete: false, completion: .contentProcessed(callback))
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
