#!/usr/bin/env python3
"""Measure macOS process CPU deltas and physical footprint without sampling lyrics."""
import argparse
import ctypes
import json
import statistics
import time


class Usage(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in (
            "user_ns", "system_ns", "idle_wakeups", "interrupt_wakeups", "pageins",
            "wired", "resident", "footprint", "started", "exited"
        )
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pid", type=int)
    parser.add_argument("--seconds", type=float, default=30)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
    lib.proc_pid_rusage.restype = ctypes.c_int

    def read():
        usage = Usage()
        if lib.proc_pid_rusage(args.pid, 0, ctypes.byref(usage)):
            raise OSError(ctypes.get_errno(), "proc_pid_rusage failed")
        return usage

    first = read()
    start = time.monotonic()
    footprint = [first.footprint]
    resident = [first.resident]
    while time.monotonic() - start < args.seconds:
        time.sleep(min(1, max(0, args.seconds - (time.monotonic() - start))))
        last = read()
        footprint.append(last.footprint)
        resident.append(last.resident)
    elapsed = time.monotonic() - start
    cpu_seconds = (last.user_ns + last.system_ns - first.user_ns - first.system_ns) / 1e9
    print(json.dumps({
        "pid": args.pid, "elapsed_seconds": round(elapsed, 3),
        "cpu_seconds": round(cpu_seconds, 6), "cpu_percent_one_core": round(100 * cpu_seconds / elapsed, 3),
        "idle_wakeups": last.idle_wakeups - first.idle_wakeups,
        "median_footprint_mib": round(statistics.median(footprint) / 1048576, 2),
        "max_footprint_mib": round(max(footprint) / 1048576, 2),
        "median_resident_mib": round(statistics.median(resident) / 1048576, 2),
    }, indent=2))


if __name__ == "__main__":
    main()
