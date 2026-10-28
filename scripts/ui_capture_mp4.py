"""Bounded readiness of actual AVC media in this diagnostic recorder's MP4.

Unlike process existence/file preallocation, a complete nonzero coded-picture
NAL establishes emitted encoded video. Final duration/full decoding remain
independent mandatory acceptance gates; this is not a general MP4 validator.
"""
import struct

MAX_FILE_BYTES = 128_000_000
MAX_NAL_BYTES = 2_000_000


def _slice_header(nal):
    # AVC emulation prevention excludes a long all-zero sparse/preallocated
    # region from valid EBSP. Up to four terminal padding bytes are tolerated.
    if len(nal) < 5 or b'\0\0\0' in nal[1:-4]: return None
    rbsp = nal[1:].replace(b'\0\0\3', b'\0\0')
    bits = ''.join(f'{value:08b}' for value in rbsp[:64])
    index = 0
    def unsigned_exp_golomb():
        nonlocal index
        zeros = 0
        while index < len(bits) and bits[index] == '0':
            zeros += 1; index += 1
            if zeros > 31: raise ValueError('Unbounded slice prefix')
        if index + zeros >= len(bits): raise ValueError('Incomplete slice header')
        index += 1
        suffix = int(bits[index:index+zeros] or '0', 2); index += zeros
        return (1 << zeros) - 1 + suffix
    try:
        first, kind, parameter_set = [unsigned_exp_golomb() for _ in range(3)]
    except ValueError:
        return None
    return (first, kind, parameter_set) if first <= 1_000_000 and kind <= 9 and parameter_set <= 255 else None


def encoded_avc_readiness(read_at, file_size):
    """read_at(offset,count) reads only the already-owned recorder output."""
    def pending(reason): return {'ready': False, 'reason': reason, 'fileBytes': file_size}
    if not 8 <= file_size <= MAX_FILE_BYTES: return pending('No bounded MP4 header yet')
    offset = 0
    for _ in range(32):
        header = read_at(offset, min(16, file_size-offset))
        if len(header) < 8: return pending('Incomplete top-level MP4 header')
        length, kind = struct.unpack('>I4s', header[:8]); header_size = 8
        if length == 1:
            if len(header) < 16: return pending('Incomplete extended MP4 header')
            length = struct.unpack('>Q', header[8:16])[0]; header_size = 16
        if kind == b'mdat':
            # MPEG4Writer may leave an open/placeholder mdat size until stop.
            limit = min(file_size, offset+length) if length >= header_size else file_size
            position = offset + header_size
            for _ in range(32):
                prefix = read_at(position, min(5, max(0, limit-position)))
                if len(prefix) < 5: return pending('No complete AVC NAL header in mdat')
                nal_size = struct.unpack('>I', prefix[:4])[0]
                if not 1 <= nal_size <= MAX_NAL_BYTES: return pending('No real bounded AVC sample; zero/preallocated mdat')
                end = position+4+nal_size
                if end > limit: return pending('AVC payload has not been fully written')
                nal = read_at(position+4, nal_size)
                if len(nal) != nal_size: return pending('Incomplete actual AVC payload read')
                if nal[0] & 0x80: return pending('Invalid AVC forbidden bit')
                nal_type = nal[0] & 0x1f
                if nal_type in (1,5):
                    values = _slice_header(nal)
                    if values is None: return pending('Invalid/incomplete or sparse AVC coded-picture payload')
                    return {'ready': True, 'fileBytes': file_size, 'mdatOffset': offset,
                            'nalOffset': position+4, 'nalBytes': nal_size, 'nalType': nal_type,
                            'firstMacroblock': values[0], 'sliceType': values[1], 'parameterSet': values[2],
                            'scope': 'Complete coded-picture AVC NAL emitted in owned mdat; final whole-video decode/duration gates still required'}
                if nal_type not in (6,7,8,9): return pending('No supported AVC metadata/picture sample')
                position = end
            return pending('No coded-picture NAL within bounded sample scan')
        if length < header_size or length > MAX_FILE_BYTES or offset+length > file_size:
            return pending('Incomplete metadata/free box; no media sample')
        offset += length
        if offset >= file_size: return pending('Metadata/header only; no mdat video')
    return pending('MP4 header scan exceeded bounded box count')
