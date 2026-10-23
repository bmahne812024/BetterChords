#!/usr/bin/env python3
"""Extract bank 0/program 0 and its referenced samples from GeneralUser GS.
Usage: python3 scripts/extract_piano_soundfont.py source.sf2 destination.sf2
Retains sample loops, stereo links, zones, modulators and upstream INFO metadata.
"""
import struct
import sys
from pathlib import Path


def chunks(data):
    offset = 0
    while offset + 8 <= len(data):
        tag, size = struct.unpack_from('<4sI', data, offset)
        yield tag, data[offset + 8:offset + 8 + size]
        offset += 8 + size + size % 2


def chunk(tag, data):
    return tag + struct.pack('<I', len(data)) + data + b'\0' * (len(data) % 2)


def extract(source, destination):
    raw = Path(source).read_bytes()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'sfbk'
    lists = {data[:4]: data[4:] for tag, data in chunks(raw[12:]) if tag == b'LIST'}
    pdta = dict(chunks(lists[b'pdta']))
    sdta = dict(chunks(lists[b'sdta']))
    assert b'sm24' not in sdta, 'This extractor expects 16-bit GeneralUser GS samples'

    def rows(tag, fmt):
        return list(struct.iter_unpack('<' + fmt, pdta[tag]))

    phdr = rows(b'phdr', '20sHHHIII')
    pbag = rows(b'pbag', 'HH')
    pgen = rows(b'pgen', 'HH')
    inst = rows(b'inst', '20sH')
    ibag = rows(b'ibag', 'HH')
    igen = rows(b'igen', 'HH')
    shdr = rows(b'shdr', '20sIIIIIBbHH')
    preset = next(i for i, row in enumerate(phdr[:-1]) if row[1:3] == (0, 0))
    preset_zones = range(phdr[preset][3], phdr[preset + 1][3])
    instruments = sorted({value for z in preset_zones for op, value in pgen[pbag[z][0]:pbag[z + 1][0]] if op == 41})
    instrument_map = {old: new for new, old in enumerate(instruments)}
    samples = {value for i in instruments for z in range(inst[i][1], inst[i + 1][1]) for op, value in igen[ibag[z][0]:ibag[z + 1][0]] if op == 53}
    pending = list(samples)
    while pending:
        old = pending.pop()
        if shdr[old][-1] & 6:
            linked = shdr[old][-2]
            if linked not in samples:
                samples.add(linked)
                pending.append(linked)
    sample_map = {old: new for new, old in enumerate(sorted(samples))}
    sample_data = bytearray()
    new_headers = []
    for old in sorted(samples):
        row = list(shdr[old])
        start, end = row[1:3]
        new_start = len(sample_data) // 2
        sample_data += sdta[b'smpl'][start * 2:end * 2] + bytes(92)
        shift = new_start - start
        row[1:5] = [value + shift for value in row[1:5]]
        if row[-1] & 6:
            row[-2] = sample_map[row[-2]]
        new_headers.append(tuple(row))
    terminal = len(sample_data) // 2
    new_headers.append((b'EOS', terminal, terminal, terminal, terminal, 0, 0, 0, 0, 1))

    def copy_zones(zones, bags, gens, reference_op, mapping):
        new_bags, new_gens = [], []
        for z in zones:
            new_bags.append((len(new_gens), bags[z][1]))
            new_gens += [(op, mapping[value] if op == reference_op else value) for op, value in gens[bags[z][0]:bags[z + 1][0]]]
        return new_bags, new_gens

    new_pbag, new_pgen = copy_zones(preset_zones, pbag, pgen, 41, instrument_map)
    new_pbag.append((len(new_pgen), (len(pdta[b'pmod']) // 10) - 1))
    new_pgen.append((0, 0))
    new_inst, new_ibag, new_igen = [], [], []
    for old in instruments:
        new_inst.append((inst[old][0], len(new_ibag)))
        bags, gens = copy_zones(range(inst[old][1], inst[old + 1][1]), ibag, igen, 53, sample_map)
        new_ibag += [(g + len(new_igen), m) for g, m in bags]
        new_igen += gens
    new_inst.append((b'EOI', len(new_ibag)))
    new_ibag.append((len(new_igen), (len(pdta[b'imod']) // 10) - 1))
    new_igen.append((0, 0))
    new_phdr = [(*phdr[preset][:3], 0, *phdr[preset][4:]), (b'EOP', 0, 0, len(new_pbag) - 1, 0, 0, 0)]

    def pack(fmt, data):
        return b''.join(struct.pack('<' + fmt, *row) for row in data)

    tables = [(b'phdr', pack('20sHHHIII', new_phdr)), (b'pbag', pack('HH', new_pbag)), (b'pmod', pdta[b'pmod']), (b'pgen', pack('HH', new_pgen)), (b'inst', pack('20sH', new_inst)), (b'ibag', pack('HH', new_ibag)), (b'imod', pdta[b'imod']), (b'igen', pack('HH', new_igen)), (b'shdr', pack('20sIIIIIBbHH', new_headers))]
    body = b'sfbk' + chunk(b'LIST', b'INFO' + lists[b'INFO']) + chunk(b'LIST', b'sdta' + chunk(b'smpl', sample_data)) + chunk(b'LIST', b'pdta' + b''.join(chunk(tag, data) for tag, data in tables))
    Path(destination).write_bytes(chunk(b'RIFF', body))
    print(f'{len(instruments)} piano instruments, {len(samples)} samples; {len(body) + 8:,} bytes')


if __name__ == '__main__':
    extract(*sys.argv[1:])
