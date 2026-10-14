"""Uuenduspaketi krüpteerimine (ainult Pythoni standardteek).

Avalikus GitHubi hoidlas on pakett krüpteeritult – ilma võtmeta ei saa seda lugeda.
Skeem: HMAC-SHA256 loendurirežiimis (voogšiffer) + HMAC-SHA256 terviklikkuse kontroll (encrypt-then-MAC).
Faili kuju: b"MAKR1" + nonce(16) + krüpteeritud sisu + märgis(32).
Võti: 64 hex-märki (failis uuendusvoti.txt või seaded.env -> UUENDUSTE_VOTI).
"""
from __future__ import annotations

import hashlib
import hmac
import os
import struct

MAAGIA = b"MAKR1"


class KruptViga(Exception):
    pass


def _votmed(voti: str) -> tuple[bytes, bytes]:
    v = (voti or "").strip()
    if not v:
        raise KruptViga("Uuenduste võti puudub.")
    try:
        juur = bytes.fromhex(v) if len(v) == 64 else hashlib.sha256(v.encode("utf-8")).digest()
    except ValueError:
        juur = hashlib.sha256(v.encode("utf-8")).digest()
    return (hmac.new(juur, b"abiline-krupteerimine", hashlib.sha256).digest(),
            hmac.new(juur, b"abiline-kontroll", hashlib.sha256).digest())


def _voog(k: bytes, nonce: bytes, andmed: bytes) -> bytes:
    valja = bytearray(len(andmed))
    for i in range(0, len(andmed), 32):
        plokk = hmac.new(k, nonce + struct.pack(">Q", i // 32), hashlib.sha256).digest()
        tykk = andmed[i:i + 32]
        valja[i:i + len(tykk)] = bytes(a ^ b for a, b in zip(tykk, plokk))
    return bytes(valja)


def krupteeri(andmed: bytes, voti: str) -> bytes:
    k_enc, k_mac = _votmed(voti)
    nonce = os.urandom(16)
    sisu = _voog(k_enc, nonce, andmed)
    margis = hmac.new(k_mac, MAAGIA + nonce + sisu, hashlib.sha256).digest()
    return MAAGIA + nonce + sisu + margis


def dekrupteeri(blob: bytes, voti: str) -> bytes:
    if not blob.startswith(MAAGIA) or len(blob) < len(MAAGIA) + 16 + 32:
        raise KruptViga("See pole abilise krüpteeritud pakett.")
    k_enc, k_mac = _votmed(voti)
    nonce, sisu, margis = blob[5:21], blob[21:-32], blob[-32:]
    if not hmac.compare_digest(margis, hmac.new(k_mac, MAAGIA + nonce + sisu, hashlib.sha256).digest()):
        raise KruptViga("Vale uuenduste võti või rikutud fail.")
    return _voog(k_enc, nonce, sisu)


def uus_voti() -> str:
    return os.urandom(32).hex()


if __name__ == "__main__":  # käsurealt: python krupt.py dekrupteeri SISEND VÄLJUND VÕTI
    import sys
    if len(sys.argv) == 5 and sys.argv[1] == "dekrupteeri":
        with open(sys.argv[2], "rb") as f:
            tulem = dekrupteeri(f.read(), sys.argv[4])
        with open(sys.argv[3], "wb") as f:
            f.write(tulem)
        print("OK")
    else:
        print(__doc__)
