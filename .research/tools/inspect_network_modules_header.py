#!/usr/bin/env python3
"""Read-only 7z header manifest inspection for hosted network_modules.7z.

Checks the start/next/decoded-directory CRCs, lists declared member sizes
and stored member CRCs. Does NOT unpack game/IOP payload bytes or validate
member CRCs; rejects unexpected archive directory structures.
"""
import argparse
import lzma
import struct
import zlib
from pathlib import Path


def uint(data, p):
    first = data[p]
    mask, value = 0x80, 0
    for n in range(8):
        if not first & mask:
            return value | ((first & (mask - 1)) << (8*n)), p + n + 1
        value |= data[p+1+n] << (8*n)
        mask >>= 1
    return value, p + 9


def manifest(raw):
    if len(raw) < 32 or raw[:6] != bytes.fromhex('377abcaf271c'):
        raise ValueError('Not a 7z archive')
    if zlib.crc32(raw[12:32]) != struct.unpack_from('<I', raw, 8)[0]:
        raise ValueError('Invalid signature header CRC')
    offset, size, crc = struct.unpack_from('<QQI', raw, 12)
    header = raw[32+offset:32+offset+size]
    if len(header) != size or zlib.crc32(header) != crc or header[:2] != b'\x17\x06':
        raise ValueError('Invalid or unsupported encoded header')
    p = 2
    packpos, p = uint(header, p)
    stream_count, p = uint(header, p)
    if stream_count != 1 or header[p] != 9:
        raise ValueError('Unsupported encoded-header stream layout')
    packsize, p = uint(header, p+1)
    if header[p:p+11] != bytes.fromhex('00070b0100012303010105'):
        raise ValueError('Unsupported encoded-header LZMA1 layout')
    p += 11
    props = header[p:p+5]
    p += 5
    if header[p] != 12:
        raise ValueError('Missing decoded header size')
    expected_size, p = uint(header, p+1)
    if header[p:p+2] != b'\x0a\x01':
        raise ValueError('Missing decoded header CRC')
    expected_crc = struct.unpack_from('<I', header, p+2)[0]
    packed = raw[32+packpos:32+packpos+packsize]
    if len(packed) != packsize:
        raise ValueError('Truncated encoded header')
    prop, dictionary = props[0], struct.unpack_from('<I', props, 1)[0]
    lc, prop = prop % 9, prop // 9
    lp, pb = prop % 5, prop // 5
    decoder = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[
        {'id': lzma.FILTER_LZMA1, 'dict_size': dictionary,
         'lc': lc, 'lp': lp, 'pb': pb}])
    decoded = decoder.decompress(packed, max_length=expected_size)
    if len(decoded) != expected_size or zlib.crc32(decoded) != expected_crc:
        raise ValueError('Decoded directory CRC or size mismatch')

    if decoded[:4] != b'\x01\x04\x06\x00':
        raise ValueError('Unexpected archive StreamsInfo')
    p = 3
    _, p = uint(decoded, p)
    streams, p = uint(decoded, p)
    if streams != 1 or decoded[p] != 9:
        raise ValueError('Unexpected data stream layout')
    _, p = uint(decoded, p+1)
    if decoded[p:p+9] != bytes.fromhex('00070b010001212101'):
        raise ValueError('Unsupported data coder (expected LZMA2)')
    if decoded[p+10] != 12:
        raise ValueError('Missing total decoded data size')
    total, p = uint(decoded, p+11)
    if decoded[p:p+5] != b'\x00\x08\x0d\x0c\x09':
        raise ValueError('Unexpected substreams descriptor')
    p += 5
    sizes = []
    for _ in range(11):
        n, p = uint(decoded, p)
        sizes.append(n)
    sizes.append(total - sum(sizes))
    if min(sizes) < 0 or decoded[p:p+2] != b'\x0a\x01':
        raise ValueError('Invalid member sizes/checksum block')
    p += 2
    checksums = [struct.unpack_from('<I', decoded, p+4*i)[0]
                 for i in range(12)]
    if decoded[p+48:p+50] != b'\x00\x00':
        raise ValueError('Unexpected end-of-SubStreamsInfo')
    p += 50
    if decoded[p] != 5:
        raise ValueError('Missing FilesInfo')
    count, p = uint(decoded, p+1)
    if count != 13 or decoded[p] != 14:
        raise ValueError('Expected 12 files and one directory')
    span, p = uint(decoded, p+1)
    if decoded[p:p+span] != b'\x80\x00':
        raise ValueError('Unexpected empty-directory flags')
    p += span
    if decoded[p] == 0x19:
        span, p = uint(decoded, p+1)
        p += span
    if decoded[p] != 0x11:
        raise ValueError('Missing filename property')
    span, p = uint(decoded, p+1)
    if decoded[p] != 0:
        raise ValueError('External filenames unsupported')
    names = [x for x in decoded[p+1:p+span].decode('utf-16le').split('\0') if x]
    if len(names) != 13 or names[0] != 'POPSTARTER':
        raise ValueError('Unexpected root/name list')
    return list(zip(names[1:], sizes, checksums)), total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    entries, total = manifest(args.archive.read_bytes())
    print(f'Verified directory-header CRCs; {len(entries)} files, '
          f'{total} declared unpacked bytes')
    for name, size, crc in entries:
        print(f'{size:>8} B  stored CRC32={crc:08X}  {name}')
    print('Stored CRCs were NOT independently recomputed from member payloads.')


if __name__ == '__main__':
    main()
