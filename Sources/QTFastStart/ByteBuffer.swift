//
//  ByteBuffer.swift
//  QTFastStart
//
//  Created by Jacky on 2020/12/10.
//

import Foundation

class ByteBuffer {
    
    enum Error: Swift.Error {
        case eof
        case parse
    }
    
    private(set) var data = Data()

    open var position: Int = 0

    open var bytesAvailable: Int {
        data.count - position
    }
    
    open var length: Int {
        get {
            data.count
        }
        set {
            switch true {
            case (data.count < newValue):
                data.append(Data(count: newValue - data.count))
            case (newValue < data.count):
                data = data.subdata(in: 0..<newValue)
            default:
                break
            }
        }
    }

    open subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
    }
    
    init(data: Data) {
        self.data = data
        position = 0
    }

    init(size: Int) {
        data = Data(repeating: 0x00, count: size)
        position = 0
    }
    
    @discardableResult
    open func clear() -> Self {
        position = 0
        return self
    }
    
    open func rewind() {
        position = 0
    }
    
    open func readBytes(_ length: Int) throws -> Data {
        guard length <= bytesAvailable else {
            throw ByteBuffer.Error.eof
        }
        position += length
        return data.subdata(in: position - length..<position)
    }
    
    @discardableResult
    open func writeBytes(_ value: Data) -> Self {
        if position == data.count {
            data.append(value)
            position = data.count
            return self
        }
        let length: Int = min(data.count, value.count)
        data[position..<position + length] = value[0..<length]
        if length == data.count {
            data.append(value[length..<value.count])
        }
        position += value.count
        return self
    }
    
    @discardableResult
    open func put<T: FixedWidthInteger>(_ value: T) -> ByteBuffer {
        writeBytes(value.data)
    }

    @discardableResult
    open func put(_ value: Float) -> ByteBuffer {
        writeBytes(Data(value.data.reversed()))
    }

    @discardableResult
    open func put(_ value: Double) -> ByteBuffer {
        writeBytes(Data(value.data.reversed()))
    }
    
    open func getInteger<T: FixedWidthInteger>() throws -> T {
        let sizeOfInteger = MemoryLayout<T>.size
        guard sizeOfInteger <= bytesAvailable else {
            throw ByteBuffer.Error.eof
        }
        position += sizeOfInteger
        return T(data: data[position - sizeOfInteger..<position]).bigEndian
    }
    
    open func getInteger<T: FixedWidthInteger>(_ index: Int) throws -> T {
        let sizeOfInteger = MemoryLayout<T>.size
        guard sizeOfInteger + index <= length else {
            throw ByteBuffer.Error.eof
        }
        return T(data: data[index..<index+sizeOfInteger]).bigEndian
    }

    open func getFloat() throws -> Float {
        let sizeOfFloat = MemoryLayout<UInt32>.size
        guard sizeOfFloat <= bytesAvailable else {
            throw ByteBuffer.Error.eof
        }
        position += sizeOfFloat
        return Float(data: Data(data.subdata(in: position - sizeOfFloat..<position).reversed()))
    }

    open func getDouble() throws -> Double {
        let sizeOfDouble = MemoryLayout<UInt64>.size
        guard sizeOfDouble <= bytesAvailable else {
            throw ByteBuffer.Error.eof
        }
        position += sizeOfDouble
        return Double(data: Data(data.subdata(in: position - sizeOfDouble..<position).reversed()))
    }
    
}

extension ExpressibleByIntegerLiteral {
    var data: Data {
        var value: Self = self
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }

    init(data: Data) {
        let diff: Int = MemoryLayout<Self>.size - data.count
        if 0 < diff {
            var buffer = Data(repeating: 0, count: diff)
            buffer.append(data)
            self = buffer.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
            return
        }
        self = data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
    }

    init(data: Slice<Data>) {
        self.init(data: Data(data))
    }
}

