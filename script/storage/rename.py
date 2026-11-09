"""Atomically rename one file on Linux, refusing replacement and cross-mount copies."""
import ctypes
import errno
import os
import sys

libc = ctypes.CDLL(None, use_errno=True)
rename = libc.renameat2
rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
rename.restype = ctypes.c_int
result = rename(-100, os.fsencode(sys.argv[1]), -100, os.fsencode(sys.argv[2]), 1)
code = ctypes.get_errno()
sys.exit(0 if result == 0 else code if code in (errno.EEXIST, errno.EXDEV) else 1)
