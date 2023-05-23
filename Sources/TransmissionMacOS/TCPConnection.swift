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

    public override func networkRead(size: Int, timeoutSeconds: Int) throws -> Data
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
    case timeout
}

#endif
