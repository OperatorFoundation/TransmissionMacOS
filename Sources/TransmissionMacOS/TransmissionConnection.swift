import Foundation

import Chord
import Datable
import os.log
import SwiftHexTools
import SwiftQueue
import TransmissionTypes
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))

import Network

public class TransmissionConnection: TransmissionTypes.Connection
{
    let log: Logger?
    let states: BlockingQueue<Bool> = BlockingQueue<Bool>()
    let startQueue = DispatchQueue(label: "TransmissionConnection")
    let connectionType: ConnectionType
    
    var connection: Transport.Connection
    var connectionClosed = false
    
    var connectLock = DispatchGroup()
    var readLock = DispatchGroup()
    var writeLock = DispatchGroup()

    public required init?(host: String, port: Int, type: ConnectionType = .tcp, logger: Logger? = nil)
    {

        let nwhost = NWEndpoint.Host(host)
        let port16 = UInt16(port)
        let nwport = NWEndpoint.Port(integerLiteral: port16)
        self.connectionType = type
        self.log = logger

        switch type
        {
            case .tcp:
                let nwconnection = NWConnection(host: nwhost, port: nwport, using: .tcp)
                self.connection = nwconnection
                self.connection.stateUpdateHandler = self.handleState
                self.connection.start(queue: startQueue)

                let success = self.states.dequeue()
                guard success else {return nil}
            case .udp:
                let nwconnection = NWConnection(host: nwhost, port: nwport, using: .udp)
                self.connection = nwconnection
                self.connection.stateUpdateHandler = self.handleState
                self.connection.start(queue: startQueue)

                let success = self.states.dequeue()
                guard success else {return nil}
        }
    }

    public required init?(transport: Transport.Connection, logger: Logger? = nil)
    {
        self.log = logger
        self.connectionType = .tcp // FIXME - support UDP
        self.connection = transport
        self.connection.stateUpdateHandler = self.handleState
        self.connection.start(queue: .global())

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
    
    public func close()
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

    // Reads exactly size bytes
    public func read(size: Int) -> Data?
    {
        var result: Data?

        self.readLock.enter()
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            guard maybeError == nil else
            {
                self.log?.error("leaving Transmission read's receive callback with error: \(String(describing: maybeError), privacy: .public)")
                self.readLock.leave()
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
            
            self.readLock.leave()
        }

        readLock.wait()
        
        return result
    }

    // reads up to maxSize bytes
    public func read(maxSize: Int) -> Data?
    {
        var result: Data?

        self.readLock.enter()
        self.connection.receive(minimumIncompleteLength: 1, maximumLength: maxSize)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            guard maybeError == nil else
            {
                self.log?.error("leaving Transmission read's receive callback with error: \(String(describing: maybeError), privacy: .public)")
                self.readLock.leave()
                return
            }

            if let data = maybeData
            {
                result = data
            }

            self.readLock.leave()
        }

        readLock.wait()

        return result
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        var result: Data?

        self.readLock.enter()

        var maybeCount: Int? = nil

        let countLock = DispatchSemaphore(value: 0)
        switch prefixSizeInBits
        {
            case 8:
                self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in

                    guard maybeError == nil else
                    {
                        countLock.signal()
                        self.readLock.leave()
                        return
                    }

                    if let data = maybeData
                    {
                        if let count = data.maybeNetworkUint8
                        {
                            maybeCount = Int(count)
                        }
                    }
                    countLock.signal()
                }
            case 16:
                self.connection.receive(minimumIncompleteLength: 2, maximumLength: 2)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in

                    guard maybeError == nil else
                    {
                        countLock.signal()
                        self.readLock.leave()
                        return
                    }

                    if let data = maybeData
                    {
                        if let count = data.maybeNetworkUint16
                        {
                            maybeCount = Int(count)
                            
                            print("Read a 2 byte length data: \(data.hex)")
                            print("Interpreted length: \(String(describing: maybeCount))")
                        }
                    }
                    countLock.signal()
                }
            case 32:
                self.connection.receive(minimumIncompleteLength: 4, maximumLength: 4)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in

                    guard maybeError == nil else
                    {
                        countLock.signal()
                        self.readLock.leave()
                        return
                    }

                    if let data = maybeData
                    {
                        if let count = data.maybeNetworkUint32
                        {
                            maybeCount = Int(count)
                        }
                    }
                    countLock.signal()
                }
            case 64:
                self.connection.receive(minimumIncompleteLength: 8, maximumLength: 8)
                {
                    (maybeData, maybeContext, isComplete, maybeError) in

                    guard maybeError == nil else
                    {
                        countLock.signal()
                        self.readLock.leave()
                        return
                    }

                    if let data = maybeData
                    {
                        if let count = data.maybeNetworkUint64
                        {
                            maybeCount = Int(count)
                        }
                    }
                    countLock.signal()
                }
            default:
                countLock.signal()
                self.readLock.leave()
                return nil
        }

        countLock.wait()

        guard let size = maybeCount else
        {
            self.readLock.leave()
            return nil
        }
        
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (maybeData, maybeContext, isComplete, maybeError) in

            guard maybeError == nil else
            {
                self.readLock.leave()
                return
            }

            if let data = maybeData
            {
                result = data
            }

            self.readLock.leave()
        }

        self.readLock.wait()

        return result
    }

    public func write(string: String) -> Bool
    {
        let data = string.data
        return write(data: data)
    }

    public func write(data: Data) -> Bool
    {
        var success = false

        self.writeLock.enter()

        let complete = self.connectionType == .udp

        self.connection.send(content: data, contentContext: NWConnection.ContentContext.defaultMessage, isComplete: complete, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeError) in

                guard maybeError == nil else
                {
                    success = false
                    self.writeLock.leave()
                    return
                }

                success = true
                self.writeLock.leave()
                return
            }))

        self.writeLock.wait()

        return success
    }

    public func writeWithLengthPrefix(data: Data, prefixSizeInBits: Int) -> Bool
    {
        var maybeCountData: Data? = nil

        switch prefixSizeInBits
        {
            case 8:
                let count = UInt8(data.count)
                maybeCountData = count.maybeNetworkData
            case 16:
                let count = UInt16(data.count)
                maybeCountData = count.maybeNetworkData
            case 32:
                let count = UInt32(data.count)
                maybeCountData = count.maybeNetworkData
            case 64:
                let count = UInt64(data.count)
                maybeCountData = count.maybeNetworkData
            default:
                print("TransmissionMacOS.writeWithLengthPrefix: Error - Unsupported prefix size: \(prefixSizeInBits)")
                return false
        }

        guard let countData = maybeCountData else
        {
            print("TransmissionMacOS.writeWithLengthPrefix: Error - unable to parse count data")
            return false
        }

        var success = false

        self.writeLock.enter()

        self.connection.send(content: countData, contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeError) in

                guard maybeError == nil else
                {
                    success = false
                    print("TransmissionMacOS.writeWithLengthPrefix: Error sending count data - \(maybeError!)")
                    self.writeLock.leave()
                    return
                }

                self.connection.send(content: data, contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
                    {
                        (maybeError) in

                        guard maybeError == nil else
                        {
                            success = false
                            print("TransmissionMacOS.writeWithLengthPrefix: Error sending content data - \(maybeError!)")
                            self.writeLock.leave()
                            return
                        }

                        success = true
                        self.writeLock.leave()
                        return
                    }))
            }))

        self.writeLock.wait()

        return success
    }
}

#endif
