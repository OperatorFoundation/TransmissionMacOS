//
//  TCPConnection.swift
//  TransmissionMacOS
//
//  Created by Dr. Brandon Wiley on 3/11/23.
//

import Foundation
#if os(macOS) || os(iOS)
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

    public override func networkRead(size: Int, timeoutSeconds: Int = 60) throws -> Data
    {
        var result: Data? = nil
        let tcpReadLock = DispatchSemaphore(value: 0)
        
        print("📻 TransmissionMacOS: networkRead(size: \(size) is calling connection.receive... 📻")
        
        self.connection.receive(minimumIncompleteLength: 1, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            defer
            {
                tcpReadLock.signal()
            }

            print("📻 TransmissionMacOS: networkRead() returned from connection.receive 📻")

            guard maybeError == nil else
            {
                print(maybeError!)
                print("❗️ TransmissionMacOS: networkRead received an error: \(maybeError!)")
                return
            }

            if let data = maybeData
            {
                if data.count != size
                {
                    print("📻 Read request for size \(size), but we only received \(data.count) bytes.")
                }
                
                result = data
            }
        }
        
        let start = DispatchTime.now()
        let timeoutTimeInterval = DispatchTimeInterval.nanoseconds(timeoutSeconds * 1000000000)
        let expectedTimeoutTime = start.advanced(by: timeoutTimeInterval)

        let tcpReadResultType = tcpReadLock.wait(timeout: expectedTimeoutTime)
        
        switch tcpReadResultType
        {
            case .success:
                print("⏰ TransmissionMacOS: networkRead completed")
                if let result
                {
                    return result
                }
                else
                {
                    throw TCPConnectionError.nilData
                }

            case .timedOut:
                print("⏰ TransmissionMacOS: networkRead timed out")
                throw TCPConnectionError.timeout
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
    case timeout
}

#endif
