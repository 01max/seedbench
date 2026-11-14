"""Stream a stopped deployment's state without opening its payload mount."""
import gzip
import io
import json
import os
import re
import shutil
import sqlite3
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path

MANIFEST = ".seedbench-backup.json"
RESTORE = ".seedbench-restored"
ENVIRONMENT = os.environ.get("RAILS_ENV", "production")
STATE = Path(os.environ["SEEDBENCH_STATE_ROOT"])
ARTIFACT_ROOTS = ("cover-assets", "inspection-covers", "personalized-torrents", "preparation-locks", "preparation-torrents")
KEYS = (
    ("SECRET_KEY_BASE", "secret_key_base", r".{1,1024}"),
    ("SEEDBENCH_ENCRYPTION_KEY", "provider_encryption_key", r"[0-9a-fA-F]{64}"),
)


def validate_state(root):
    for suffix in ("", "_queue"):
        database = root / f"{ENVIRONMENT}{suffix}.sqlite3"
        if not database.is_file() or database.is_symlink():
            raise ValueError("The application and queue databases are required")
        with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as connection:
            if connection.execute("PRAGMA quick_check").fetchone() != ("ok",):
                raise ValueError("SQLite integrity check failed")


def recovery_keys(root, *, restoring=False):
    keys = {}
    for variable, filename, pattern in KEYS:
        external = os.environ.get(variable)
        path = root / filename
        if path.is_symlink():
            raise ValueError("Key files must not be symlinks")
        key = path.read_text().strip() if restoring or not external else external
        if not re.fullmatch(pattern, key) or (restoring and external and external != key):
            raise ValueError("Missing or mismatched key recovery material")
        keys[filename] = key.encode()
    return keys


def state_entry(member):
    parts = Path(member.name).parts
    if not parts or member.name.startswith("/") or ".." in parts:
        raise ValueError("Unsafe archive path")
    if parts[0] in (RESTORE, MANIFEST) or not (member.isfile() or member.isdir()):
        raise ValueError("Unsupported archive entry")
    return member


def backup():
    if (STATE / RESTORE).exists():
        raise ValueError("Complete recovery of this state before backing it up")
    validate_state(STATE)
    keys = recovery_keys(STATE)
    with tarfile.open(mode="w|gz", fileobj=sys.stdout.buffer) as archive:
        metadata = json.dumps({"version": 1, "environment": ENVIRONMENT,
                               "backed_up_at": datetime.now(timezone.utc).isoformat()}).encode()
        archive_bytes(archive, MANIFEST, metadata)
        for filename, key in keys.items():
            archive_bytes(archive, filename, key)
        for path in sorted(STATE.iterdir()):
            if path.name in ARTIFACT_ROOTS or state_database(path.name):
                archive.add(path, arcname=path.name, filter=state_entry)


def state_database(name):
    for suffix in ("", "_queue"):
        filename = f"{ENVIRONMENT}{suffix}.sqlite3"
        if name in (filename, filename + "-wal", filename + "-shm", filename + "-journal"):
            return True
    return False


def archive_bytes(archive, name, data):
    header = tarfile.TarInfo(name)
    header.mode = 0o600
    header.size = len(data)
    archive.addfile(header, io.BytesIO(data))


def backup_metadata(archive):
    header = archive.next()
    if not header or header.name != MANIFEST or not header.isfile() or header.size > 1024:
        raise ValueError("Missing backup manifest")
    metadata = json.load(archive.extractfile(header))
    if metadata.get("version") != 1 or metadata.get("environment") != ENVIRONMENT:
        raise ValueError("Incompatible backup version or Rails environment")
    datetime.fromisoformat(metadata["backed_up_at"])
    return metadata


def extract(archive, root):
    seen = set()
    while member := archive.next():
        state_entry(member)
        relative = Path(member.name)
        if relative in seen:
            raise ValueError("Duplicate archive path")
        seen.add(relative)
        path = root / relative
        if member.isdir():
            path.mkdir(mode=0o700, parents=True, exist_ok=True)
        else:
            path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with path.open("xb") as destination:
                shutil.copyfileobj(archive.extractfile(member), destination)
                destination.flush()
                os.fsync(destination.fileno())


def restore():
    if any(STATE.iterdir()):
        raise ValueError("Restore into a new, empty state directory or volume")
    with tempfile.TemporaryDirectory(prefix=".restore-", dir=STATE) as staging:
        root = Path(staging)
        with gzip.GzipFile(fileobj=sys.stdin.buffer) as compressed:
            with tarfile.open(mode="r|", fileobj=compressed) as archive:
                metadata = backup_metadata(archive)
                extract(archive, root)
            while compressed.read(65536):
                pass
        validate_state(root)
        recovery_keys(root, restoring=True)
        write_marker(STATE / RESTORE, metadata | {"restored": False})
        sync_directory(STATE)
        for path in root.iterdir():
            path.rename(STATE / path.name)
        sync_directory(STATE)
        completed = root / RESTORE
        write_marker(completed, metadata | {"restored": True})
        completed.replace(STATE / RESTORE)
        sync_directory(STATE)


def write_marker(path, metadata):
    with path.open("x") as marker:
        json.dump(metadata, marker)
        marker.flush()
        os.fsync(marker.fileno())


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        os.umask(0o077)
        if os.getuid() == 0 or not STATE.is_absolute() or STATE.resolve() != STATE:
            raise ValueError("Use the application UID and a canonical absolute state root")
        command, = sys.argv[1:]
        {"backup": backup, "restore": restore}[command]()
    except (OSError, ValueError, KeyError, EOFError, sqlite3.Error, tarfile.TarError):
        print("State backup or restore failed. Check the archive, state directory, databases, and keys.", file=sys.stderr)
        sys.exit(1)
