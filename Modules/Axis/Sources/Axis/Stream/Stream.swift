public enum StreamError : Error {
    case closedStream
    case timeout
    case writeFileUnsupported
}

public protocol InputStream {
    var closed: Bool { get }
    func open(deadline: Double) throws
    func close()
    
    func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Double) throws -> UnsafeBufferPointer<Byte>
    func read(upTo byteCount: Int, deadline: Double) throws -> Buffer
    func read(exactly byteCount: Int, deadline: Double) throws -> Buffer
}


extension InputStream {
    public func read(upTo byteCount: Int, deadline: Double) throws -> Buffer {
        guard byteCount > 0 else {
            return Buffer()
        }
        
        var bytes = [Byte](repeating: 0, count: byteCount)

        let bytesRead = try bytes.withUnsafeMutableBufferPointer {
            try read(into: $0, deadline: deadline).count
        }

        return Buffer(bytes[0..<bytesRead])
    }
    
    public func read(exactly byteCount: Int, deadline: Double) throws -> Buffer {
        guard byteCount > 0 else {
            return Buffer()
        }
        
        var bytes = [Byte](repeating: 0, count: byteCount)
        
        try bytes.withUnsafeMutableBufferPointer { pointer in
            var address = pointer.baseAddress!
            var remaining = byteCount
            while remaining > 0 {
                let chunk = try read(into: UnsafeMutableBufferPointer(start: address, count: remaining), deadline: deadline)
                guard chunk.count > 0 else {
                    throw StreamError.closedStream
                }
                address = address.advanced(by: chunk.count)
                remaining -= chunk.count
            }
        }
        
        return Buffer(bytes)
    }

    /// Drains the `Stream` and returns the contents in a `Buffer`.
    public func drain(bufferSize: Int = 4096, deadline: Double) throws -> Buffer {
        guard !self.closed else {
            throw StreamError.closedStream
        }

        var drainBuffer = Buffer()
        var readBuffer = UnsafeMutableBufferPointer<Byte>(capacity: bufferSize)
        defer { readBuffer.deallocate(capacity: bufferSize) }

        while !self.closed {
            let chunk = try self.read(into: readBuffer, deadline: deadline)

            guard !chunk.isEmpty else {
                break
            }

            drainBuffer.append(chunk)
        }

        return drainBuffer
    }
}

public protocol OutputStream {
    var closed: Bool { get }
    func open(deadline: Double) throws
    func close()
    
    func write(_ buffer: UnsafeBufferPointer<Byte>, deadline: Double) throws
    func write(_ buffer: Buffer, deadline: Double) throws
    func write(_ buffer: BufferRepresentable, deadline: Double) throws
    func write(filePath: String, deadline: Double) throws
    func flush(deadline: Double) throws
}

extension OutputStream {
    public func write(_ buffer: Buffer, deadline: Double) throws {
        guard !buffer.isEmpty else {
            return
        }
        
        try buffer.bytes.withUnsafeBufferPointer {
            try write($0, deadline: deadline)
        }
    }

    public func write(_ converting: BufferRepresentable, deadline: Double) throws {
        try write(converting.buffer, deadline: deadline)
    }
    
    public func write(_ bytes: [Byte], deadline: Double) throws {
        guard !bytes.isEmpty else {
            return
        }
        try bytes.withUnsafeBufferPointer { try self.write($0, deadline: deadline) }
    }

    public func write(filePath: String, deadline: Double) throws {
        throw StreamError.writeFileUnsupported
    }
}

public typealias Stream = InputStream & OutputStream
