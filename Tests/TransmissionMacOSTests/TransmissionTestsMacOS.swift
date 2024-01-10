import XCTest
import Foundation
@testable import TransmissionMacOS
import Network
import Datable

final class TransmissionMacOSTests: XCTestCase
{
    public func testConnection()
    {
        let lock = DispatchGroup()
        let queue = DispatchQueue(label: "testing")
        
        lock.enter()
        
        queue.async
        {
            self.runServer(lock)
        }
        
        lock.wait()
        XCTAssertTrue(runClient())
    }
    
    func runServer(_ lock: DispatchGroup)
    {
        guard let listener = TransmissionListener(port: 1234, logger: nil) else {return}
        lock.leave()

        let connection = listener.accept()
        let _ = connection.read(size: 4)
        let _ = connection.write(string: "back")
    }
    
    func runClient() -> Bool
    {
        let connection = TransmissionConnection(host: "127.0.0.1", port: 1234, logger: nil)
        let writeSuccess = connection!.write(string: "test")
        let result = connection!.read(size: 4)
        
        connection?.close()
        
        return (result == "back" && writeSuccess)
    }

    public func testUDP()
    {
        guard let connection = UDPConnection(host: "127.0.0.1", port: 1234, logger: nil) else
        {
            XCTFail()
            return
        }

        guard connection.write(string: "test") else
        {
            XCTFail()
            return
        }
        
        connection.close()
    }

    public func testUDPNetwork()
    {
        let queue = DispatchQueue(label: "testUDPNetwork")
        let lock = DispatchSemaphore(value: 0)

        guard let ipv4 = IPv4Address("127.0.0.1") else
        {
            XCTFail()
            return
        }

        let host = NWEndpoint.Host.ipv4(ipv4)
        let port = NWEndpoint.Port(integerLiteral: 1234)
        let conn = NWConnection(host: host, port: port, using: .udp)
        conn.stateUpdateHandler =
        {
            state in

            switch state
            {
                case .ready:
                    print("ready")
                    let data = "string".data
                    conn.send(content: data, completion: .contentProcessed(
                    {
                        error in

                        print("sent")
                        lock.signal()
                    }))
                default:
                    print("state: \(state)")
                    return
            }
        }
        conn.start(queue: queue)

        lock.wait()
    }
    
    func testTimeout()
    {
        let timeoutSeconds = 60
        let start = DispatchTime.now()
        let timeoutInterval = DispatchTimeInterval.seconds(60)
        let timeoutTime = start.advanced(by: timeoutInterval)
        
        let actualTimeoutInterval = start.distance(to: timeoutTime)
        print("# Actual timeout interval: \(actualTimeoutInterval)")
        XCTAssertEqual(actualTimeoutInterval, timeoutInterval)
    }

    func testReadAndWriteSimultaneous()
    {
        guard let connection = TCPConnection(host: "127.0.0.1", port: 1234) else
        {
            XCTFail()
            return
        }

        Task
        {
            while true
            {
                if let data = connection.read(size: 4)
                {
                    print(data)
                }
            }
        }

        Task
        {
            connection.write(string: "asdf")
        }
    }
}
