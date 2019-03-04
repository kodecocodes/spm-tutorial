import NIO
import NIOHTTP1

/// A server that replies to every request using a predefined responder
public final class Website<Responder: HTTPResponder> {
    public let group: EventLoopGroup
    private var serverChannel: Channel?
    private let responder: Responder
    
    /// Creates a new Website
    public init(responder: Responder) {
        self.responder = responder
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }
    
    /// Runs the website until the server's socket is closed
    public func run() throws {
        // The host and port to which the webserver will bind
        // ::1 can usually be accessed as `localhost`
        // The difference is that `::1` is also available from other computers
        let host = "::1"
        let port = 8080
        
        let bootstrap = ServerBootstrap(group: group)
            // Specifies that we can have 256 TCP sockets waiting to be accepted for processing at a given time
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            // Allows reusing the IP address and port so that multiple threads can receive clients
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            
            // Sets up the HTTP parser and handler on the SwiftNIO channel
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).then {
                    channel.pipeline.add(handler: HTTPHandler(responder: self.responder))
                }
        }
        
        let serverChannel = try bootstrap.bind(host: host, port: port).wait()
        
        guard serverChannel.localAddress != nil else {
            fatalError("Unable to bind to \(host) at port \(port)")
        }
        
        print("Server started and listening")
        
        self.serverChannel = serverChannel
        try serverChannel.closeFuture.wait()
    }
    
    /// Closes the server's socket and therefore ends running the server
    public func stop() {
        serverChannel?.close(promise: nil)
    }
}
