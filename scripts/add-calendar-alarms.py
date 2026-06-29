#!/usr/bin/env python3
"""Add/replace a default VALARM on every VEVENT in an .ics file."""
import sys
from pathlib import Path


def add_alarms(input_path: Path, output_path: Path, minutes_before: int = 15) -> None:
    text = input_path.read_text(encoding="utf-8", errors="surrogateescape")
    lines = text.splitlines()
    out_lines = []
    i = 0
    in_event = False
    in_alarm = False
    event_buffer = []

    def flush_event():
        nonlocal event_buffer, out_lines
        if event_buffer:
            # Append our single VALARM right before END:VEVENT
            event_buffer.insert(-1, "BEGIN:VALARM")
            event_buffer.insert(-1, "ACTION:DISPLAY")
            event_buffer.insert(-1, f"TRIGGER:-PT{minutes_before}M")
            event_buffer.insert(-1, "DESCRIPTION:Reminder")
            event_buffer.insert(-1, "END:VALARM")
            out_lines.extend(event_buffer)
            event_buffer = []

    while i < len(lines):
        line = lines[i]
        if line.startswith("BEGIN:VEVENT"):
            flush_event()
            in_event = True
            event_buffer.append(line)
        elif line.startswith("END:VEVENT"):
            event_buffer.append(line)
            flush_event()
            in_event = False
        elif in_event and line.startswith("BEGIN:VALARM"):
            # Drop old alarm entirely; we'll inject a fresh one at END:VEVENT
            in_alarm = True
        elif in_event and line.startswith("END:VALARM"):
            in_alarm = False
        elif in_event and in_alarm:
            pass  # skip old alarm lines
        elif in_event:
            event_buffer.append(line)
        else:
            out_lines.append(line)
        i += 1

    flush_event()
    output_path.write_text("\r\n".join(out_lines) + "\r\n", encoding="utf-8")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: add-calendar-alarms.py <input.ics> [output.ics] [minutes]")
        sys.exit(1)
    inp = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else inp.with_suffix(".with-alarms.ics")
    minutes = int(sys.argv[3]) if len(sys.argv) > 3 else 15
    add_alarms(inp, out, minutes)
