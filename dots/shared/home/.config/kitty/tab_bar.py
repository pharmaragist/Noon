# powerline tabs with CPU/RAM/clock status
from datetime import datetime
from typing import Callable

from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
)

# Noon palette
BG      = as_rgb(0x090f11)
DARK    = as_rgb(0x0f1416)
SEL     = as_rgb(0x004e5e)
COMMENT = as_rgb(0x344a52)
FG      = as_rgb(0xdee3e6)
CYAN    = as_rgb(0x86d1e9)
GREEN   = as_rgb(0xcee7f0)
YELLOW  = as_rgb(0xc1c4eb)
RED     = as_rgb(0xff71bc)
PURPLE  = as_rgb(0xb2ebff)

# CPU state
_timer_id  = None
_cpu_pct   = 0.0
_prev_stat = None


def _tick_cpu() -> None:
    global _cpu_pct, _prev_stat
    try:
        with open('/proc/stat') as f:
            parts = f.readline().split()
        total = sum(int(x) for x in parts[1:])
        idle  = int(parts[4]) + int(parts[5])   # idle + iowait
        if _prev_stat is not None:
            dt = total - _prev_stat[0]
            di = idle  - _prev_stat[1]
            _cpu_pct = round(100.0 * (dt - di) / dt, 1) if dt else 0.0
        _prev_stat = (total, idle)
    except Exception:
        pass


def _ram_used_gb() -> float:
    try:
        mem: dict[str, int] = {}
        with open('/proc/meminfo') as f:
            for line in f:
                k, _, v = line.partition(':')
                key = k.strip()
                if key in ('MemTotal', 'MemAvailable'):
                    mem[key] = int(v.split()[0])
                if len(mem) == 2:
                    break
        return (mem['MemTotal'] - mem['MemAvailable']) / 1_048_576
    except Exception:
        return 0.0


def _timer_cb(_tid: int) -> None:
    _tick_cpu()


def _ensure_timer() -> None:
    global _timer_id
    if _timer_id is None:
        _tick_cpu()
        _timer_id = add_timer(_timer_cb, 2.0, True)


# Per-tab draw (powerline slant via built-in renderer)
def draw_tab(
    draw_data          : DrawData,
    screen             : Screen,
    tab                : TabBarData,
    before_going_active: Callable[[], None],
    max_tab_length     : int,
    index              : int,
    is_last            : bool,
    extra_data         : ExtraData,
) -> int:
    _ensure_timer()
    return draw_tab_with_powerline(
        draw_data, screen, tab,
        before_going_active, max_tab_length,
        index, is_last, extra_data,
    )


# Right-side status bar
def draw_right_status(screen: Screen, is_last: bool) -> int:
    cpu = _cpu_pct
    ram = _ram_used_gb()
    now = datetime.now().strftime('%H:%M')

    cpu_fg = GREEN if cpu < 50 else YELLOW if cpu < 80 else RED

    # (text, fg, bg)  — \uf2db=microchip \uf233=server \uf017=clock
    segments = [
        (' \uf2db ', COMMENT, SEL),
        (f'{cpu:.0f}%  ', cpu_fg, SEL),
        (' \uf233 ', COMMENT, DARK),
        (f'{ram:.1f}G  ', CYAN, DARK),
        (' \uf017 ', COMMENT, SEL),
        (f'{now} ', PURPLE, SEL),
    ]

    total = sum(len(s[0]) for s in segments)
    gap   = screen.columns - screen.cursor.x - total

    if gap > 0:
        screen.cursor.fg = BG
        screen.cursor.bg = BG
        screen.draw(' ' * gap)

    for text, fg, bg in segments:
        screen.cursor.fg = fg
        screen.cursor.bg = bg
        screen.draw(text)

    return screen.cursor.x
