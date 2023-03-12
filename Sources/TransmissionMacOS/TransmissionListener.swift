#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
//
//  Listener.swift
//
//
//  Created by Dr. Brandon Wiley on 8/31/20.
//

import Foundation
import Chord
#if os(macOS)
import os.log
#else
import Logger
#endif
import Net
import TransmissionTypes

public class TransmissionListener: Listener
{
    let listener: NWListener
    let queue: BlockingQueue<Connection> = BlockingQueue<Connection>()
    let lock: DispatchGroup = DispatchGroup()

    required public init?(port: Int, type: ConnectionType = .tcp, logger: Logger?)
    {
        let port16 = UInt16(port)
        let nwport = NWEndpoint.Port(integerLiteral: port16)

        var params: NWParameters!
        switch type
        {
            case .tcp:
                params = NWParameters.tcp
            case .udp:
                params = NWParameters.udp
        }

        guard let listener = try? NWListener(using: params, on: nwport) else {return nil}
        self.listener = listener

        self.listener.newConnectionHandler =
        {
            nwconnection in

            let connection: TransmissionTypes.Connection
            switch type
            {
                case .tcp:
                    guard let newConnection = TCPConnection(connection: nwconnection, logger: logger) else {return}
                    connection = newConnection

                case .udp:
                    guard let newConnection = UDPConnection(connection: nwconnection, logger: logger) else {return}
                    connection = newConnection
            }

            self.queue.enqueue(element: connection)
        }

        self.listener.start(queue: .global())
    }

    public func accept() -> Connection
    {
        return self.queue.dequeue()
    }

    public func close()
    {
        self.listener.cancel()
    }
}

#endif
