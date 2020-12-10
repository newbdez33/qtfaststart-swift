//
//  QTFastStart.swift
//  QTFastStart
//
//  Created by Jacky on 2020/12/10.
//

import Foundation

/// Optimize mp4 data for audio streaming.
/// return optimized data if success.
/// return original data if failure.

public class QTFastStart {

    private var FREE_ATOM: Int { fourCcToInt("free") }
    private var JUNK_ATOM: Int { fourCcToInt("junk") }
    private var MDAT_ATOM: Int { fourCcToInt("mdat") }
    private var MOOV_ATOM: Int { fourCcToInt("moov") }
    private var PNOT_ATOM: Int { fourCcToInt("pnot") }
    private var SKIP_ATOM: Int { fourCcToInt("skip") }
    private var WIDE_ATOM: Int { fourCcToInt("wide") }
    private var PICT_ATOM: Int { fourCcToInt("pict") }
    private var FTYP_ATOM: Int { fourCcToInt("ftyp") }
    private var UUID_ATOM: Int { fourCcToInt("uuid") }
    
    private var CMOV_ATOM: Int { fourCcToInt("cmov") }
    private var STCO_ATOM: Int { fourCcToInt("stco") }
    private var CO64_ATOM: Int { fourCcToInt("c064") }
    
    private let ATOM_PREAMBLE_SIZE: Int = 8
    
    private func fourCcToInt(_ fourCc: String) -> Int {
        let data = fourCc.data(using: .ascii)!
        return Int(bigEndian: Int(data: data))
    }
    
    func readAndFill(_ data: inout ByteBuffer, _ buffer: inout ByteBuffer) -> Bool {
        buffer.clear()
        do {
            let slicedData: Data = try data.readBytes(buffer.length)
            buffer.writeBytes(slicedData)
            buffer.rewind()
            return true
        } catch {
            return false
        }
        
    }
    
    public func process(_ data: Data) -> Data {
        var dataBytes = ByteBuffer(data: data)
        var atomBytes = ByteBuffer(size: ATOM_PREAMBLE_SIZE)
        var atomType: Int = 0
        var atomSize: Int = 0
        var startOffset: Int = 0
        let lastOffset: Int
        var ftypAtom: ByteBuffer? = nil
        var moovAtom: ByteBuffer
        let moovAtomSize: Int
        
        // mp4의 atom을 조회하여 moov atom이 최하단에 있는지 체크
        do {
            while readAndFill(&dataBytes, &atomBytes) {
                atomSize = Int(try atomBytes.getInteger() as UInt32)
                atomType = Int(try atomBytes.getInteger() as UInt32)
                
                if atomType == FTYP_ATOM {
                    let ftypAtomSize = atomSize
                    ftypAtom = ByteBuffer(size: ftypAtomSize)
                    atomBytes.rewind()
                    ftypAtom!.writeBytes(try atomBytes.readBytes(atomBytes.length))
                    
                    let ftypData = try dataBytes.readBytes(ftypAtom!.bytesAvailable)
                    ftypAtom!.writeBytes(ftypData)
                    ftypAtom!.rewind()
                    
                    startOffset = dataBytes.position

                } else {
                    dataBytes.position = dataBytes.position + atomSize - ATOM_PREAMBLE_SIZE
                }
                
                if atomType != FREE_ATOM
                    && atomType != JUNK_ATOM
                    && atomType != MDAT_ATOM
                    && atomType != MOOV_ATOM
                    && atomType != PNOT_ATOM
                    && atomType != SKIP_ATOM
                    && atomType != WIDE_ATOM
                    && atomType != PICT_ATOM
                    && atomType != UUID_ATOM
                    && atomType != FTYP_ATOM {
                    print("Encountered non-QT top-level atom")
                    break
                }
                
                if (atomSize < 8) {
                    break
                }
                
            }
            
            if atomType != MOOV_ATOM {
                print("last atom in file was not a moov atom")
                return data
            }
            
            // moov atom이 최하단에 있음을 확인 후 moovAtom 전체를 로드함
            moovAtomSize = atomSize
            lastOffset = dataBytes.length - moovAtomSize // moov 뒤에 더이상 데이터가 없다는 가정 (qt-faststart.c)
            dataBytes.position = lastOffset
            moovAtom = ByteBuffer(size: moovAtomSize)
            
            if !readAndFill(&dataBytes, &moovAtom) {
                print("moov parse error")
                return data
            }
            
            if try Int(moovAtom.getInteger(12) as UInt32) == CMOV_ATOM {
                print("Compressed moov atom not supported")
                return data
            }
            
            // stco 또는 co64 atom을 찾기 위해 moov atom을 검사
            while(moovAtom.bytesAvailable >= 8) {
                let atomHead = moovAtom.position
                atomType = Int(try moovAtom.getInteger(atomHead + 4) as UInt32)
                
                if !(atomType == STCO_ATOM || atomType == CO64_ATOM) {
                    moovAtom.position = moovAtom.position + 1
                    continue
                }
                
                atomSize = Int(try moovAtom.getInteger(atomHead) as UInt32)
                if atomSize > moovAtom.bytesAvailable {
                    print("bad atom size")
                    return data
                }
                
                moovAtom.position = atomHead + 12 // skip size (4 bytes), type (4 bytes), version (1 byte) and flags (3 bytes)
                if moovAtom.bytesAvailable < 4 {
                    print("malformed atom")
                    return data
                }
                
                let offsetCount = Int(try moovAtom.getInteger() as UInt32)
                if atomType == STCO_ATOM {
                    print("patching stco atom")
                    if moovAtom.bytesAvailable < offsetCount * 4 {
                        print("bad atom size/element count")
                        return data
                    }
                    
                    for _ in 0..<offsetCount {
                        let currentOffset = Int( try moovAtom.getInteger(moovAtom.position) as UInt32)
                        
                        let newOffset = currentOffset + moovAtomSize
                        
                        if currentOffset < 0 && newOffset >= 0 {
                            print("Unsupported file exception")
                            return data
                        }
                        moovAtom.put(UInt32(newOffset).bigEndian)

                    }
                } else if atomType == CO64_ATOM {
                    print("patching co64 atom")
                    if moovAtom.bytesAvailable < offsetCount * 8 {
                        print("bad atom size/element count")
                        return data
                    }
                    for _ in 0..<offsetCount {
                        let currentOffset = try moovAtom.getInteger(moovAtom.position) as Int
                        moovAtom.put(currentOffset + moovAtomSize)
                    }
                    
                 }
            }
            
            dataBytes.position = startOffset // ftyp atom 뒷부분으로 이동
            
            var outData = Data()
            
            guard let ftypAtom = ftypAtom else { return data }
            print("writing ftyp atom")
            outData.append(ftypAtom.data)
            
            print("writing new moov atom")
            outData.append(moovAtom.data)
            
            print("write rest of data")
            let restOfData = try dataBytes.readBytes(dataBytes.length - startOffset)
            outData.append(restOfData)
            
            return outData
            
        } catch {
            print(error)
            return data
        }
        
    }

}
