import Foundation
import Network

/// HTTP Server for receiving external messages (e.g., from Antigravity MCP)
/// Listens on port 1012 for POST /meow requests
class MeowHTTPServer {
    static let shared = MeowHTTPServer()
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 1012
    
    private init() {}
    
    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: port)
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[MeowHTTPServer] Listening on port \(self.port)")
                case .failed(let error):
                    print("[MeowHTTPServer] Failed to start: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
        } catch {
            print("[MeowHTTPServer] Error starting server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        print("[MeowHTTPServer] Server stopped")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let error = error {
                print("[MeowHTTPServer] Receive error: \(error)")
                connection.cancel()
                return
            }
            
            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                self?.sendResponse(connection: connection, status: "400 Bad Request", body: "Invalid request")
                return
            }
            
            self?.processRequest(request, connection: connection)
        }
    }
    
    private func processRequest(_ request: String, connection: NWConnection) {
        // Parse HTTP request
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Empty request")
            return
        }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Malformed request")
            return
        }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        // Handle POST /meow
        if method == "POST" && path == "/meow" {
            // Extract body (after empty line)
            if let bodyIndex = request.range(of: "\r\n\r\n")?.upperBound {
                let body = String(request[bodyIndex...])
                handleMeowRequest(body: body, connection: connection)
            } else {
                sendResponse(connection: connection, status: "400 Bad Request", body: "No body found")
            }
        } else if method == "GET" && path == "/" {
            // Health check
            sendResponse(connection: connection, status: "200 OK", body: "🐱 MeowHTTPServer is running!")
        } else {
            sendResponse(connection: connection, status: "404 Not Found", body: "Endpoint not found")
        }
    }
    
    private func handleMeowRequest(body: String, connection: NWConnection) {
        // Parse JSON body
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Invalid JSON or missing 'message' field")
            return
        }
        
        // Show message via pet bubble
        DispatchQueue.main.async {
            ChatState.shared.chatMessage = message
            ChatState.shared.showChatBubble = true
            ChatState.shared.isLoading = false
        }
        
        print("[MeowHTTPServer] Received message: \(message)")
        sendResponse(connection: connection, status: "200 OK", body: "{\"success\": true}")
    }
    
    private func sendResponse(connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/plain\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { error in
            if let error = error {
                print("[MeowHTTPServer] Send error: \(error)")
            }
            connection.cancel()
        })
    }
}
