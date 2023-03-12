//
//  UDPConnection.swift
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
import SwiftHexTools
import SwiftQueue
import TransmissionBase
import TransmissionTypes
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))

import Network

public class UDPConnection: IPConnection
{
    public required init?(host: String, port: Int, logger: Logger? = nil)
    {
        let nwhost = NWEndpoint.Host(host)
        let port16 = UInt16(port)
        let nwport = NWEndpoint.Port(integerLiteral: port16)

        let nwconnection = NWConnection(host: nwhost, port: nwport, using: .udp)

        super.init(connection: nwconnection, connectionType: .udp, logger: logger)
    }

    public init?(connection: NWConnection, logger: Logger? = nil)
    {
        super.init(connection: connection, connectionType: .udp, logger: logger)
    }
}

#endif
