"""Rename one file on Linux without replacement, symlink traversal or copying."""
import ctypes
import errno
import os
import sys
from contextlib import ExitStack


def parent_fd(path, stack):
    parts = path.split('/')
    if parts[0] or any(part in ('', '.', '..') for part in parts[1:]):
        raise ValueError('Invalid absolute path')
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    fd = os.open('/', flags)
    stack.callback(os.close, fd)
    for component in parts[1:-1]:
        fd = os.open(component, flags, dir_fd=fd)
        stack.callback(os.close, fd)
    return fd, os.fsencode(parts[-1])


def main():
    libc = ctypes.CDLL(None, use_errno=True)
    rename = libc.renameat2
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    with ExitStack() as stack:
        source_fd, source = parent_fd(sys.argv[1], stack)
        destination_fd, destination = parent_fd(sys.argv[2], stack)
        result = rename(source_fd, source, destination_fd, destination, 1)
        code = ctypes.get_errno()
        return 0 if result == 0 else code if code in (errno.EEXIST, errno.EXDEV) else 1


try:
    sys.exit(main())
except (OSError, ValueError, AttributeError):
    sys.exit(1)
