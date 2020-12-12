# AES-GCM PoC generator from a Mitra-generated polyglot.

import sys
import argparse

load('gcm.sage')


def mix(d1, d2, cuts):
    """mixing data with exclusive parts of each data"""
    assert len(d1) == len(d2)
    d = b""
    start = 0
    keep = d1
    skip = d2
    for end in cuts:
        d += keep[start:end]
        start = end
        keep, skip = skip, keep
    d += keep[start:]
    return d


parser = argparse.ArgumentParser(description="Turn a non-overlapping, block-aligned polyglot into a dual AES-GCM ciphertext.")
parser.add_argument('polyglot',
    help="input polyglot - requires special naming like 'P(10-5c).png.rar'.")
parser.add_argument('-k', '--keys', nargs=2, default=[unhexlify('01'*16), unhexlify('02'*16)],
    help="Encryption keys - default: 01*16 / 02*16 .")
parser.add_argument('-n', '--nonce', default=unhexlify('03'*12),
    help="Nonce - default: 03*12 .")
parser.add_argument('-a', '--additional_data', default=unhexlify(b'\xaa'*32),
    help="Additional Data - default: AA*32 .")
parser.add_argument('-t', '--tag', default=unhexlify('04'*16),
    help="Tag - default: 04*16 .")
parser.add_argument('-i', '--index', default=0,
    help="Index of correction blocks.")
parser.add_argument('-p', '--dump_plaintexts', default=False, action="store_true",
    help="Dump decrypted payloads.")

args = parser.parse_args()

fn = args.polyglot
key1, key2 = args.keys
nonce = args.nonce
additional_data = args.additional_data
tag = args.tag
index = int(args.index)

# GCM cuts are at byte boundary
cuts = fn[fn.find("(") + 1:]
cuts = cuts[:cuts.find(")")]
cuts = cuts.split("-")

if len(cuts) < 1:
    printf("Invalid cuts parameters from filename - aborting.")
    sys.exit()

with open(fn, "rb") as f:
    fdata = f.read()

cipher = AES.new(key1, AES.MODE_GCM, nonce=nonce)
_ = cipher.update(additional_data)
c1, _ = cipher.encrypt_and_digest(fdata)

cipher = AES.new(key2, AES.MODE_GCM, nonce=nonce)
_ = cipher.update(additional_data)
c2, _ = cipher.encrypt_and_digest(fdata)

ciphertext = mix(c1, c2, cuts)


num_ad_blocks = len(additional_data) // 16
ad_blocks = [additional_data[i*16: i*16+16] for i in range(num_ad_blocks)]

# if index is null, then we append 2 blocks and use them for correction
if index == 0:
    ciphertext += b"\0" * (16 - len(ciphertext) % 16)
    index = len(ciphertext)
    ciphertext += b"\0" * 32
else:
# In practice, we can put these 2 blocks anywhere - even in AD -
# but it's not supported here.    
    correction_indices = [
        num_ad_blocks + index,
        num_ad_blocks + index + 1
    ]

num_ct_blocks = len(ciphertext) // 16
ct_blocks = [ciphertext[i*16: i*16+16] for i in range(num_ct_blocks)]


ad_blocks, ct_blocks = gcm(key1, key2, nonce, tag,
    correction_indices,
    num_ct_blocks, ct_blocks,
    num_ad_blocks, ad_blocks)

additional_data = b''.join(ad_blocks)
ciphertext = b''.join(ct_blocks)

print(f'Key1: {hexlify(key1)}')
print(f'Key2: {hexlify(key2)}')
print(f'Nonce: {hexlify(nonce)}')
print(f'AdditionalData: {hexlify(additional_data)}')
print(f'Ciphertext: {hexlify(ciphertext[:32])}')
print(f'Tag: {hexlify(tag)}')

if args.dump_plaintexts:
    cipher = AES.new(key1, AES.MODE_GCM, nonce=nonce)
    _ = cipher.update(additional_data)
    m1 = cipher.decrypt_and_verify(ciphertext, tag)

    cipher = AES.new(key2, AES.MODE_GCM, nonce=nonce)
    _ = cipher.update(additional_data)
    m2 = cipher.decrypt_and_verify(ciphertext, tag)
    with open("gcm1.bin", "wb") as f: f.write(m1)
    with open("gcm2.bin", "wb") as f: f.write(m2)
