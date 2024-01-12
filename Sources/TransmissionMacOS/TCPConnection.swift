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
