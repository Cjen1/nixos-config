#!/usr/bin/env python3

# Copyright (C) 2020 Richard Mortier <mort@cantab.net>. All Rights Reserved.
#
# Licensed under the GPL v3; see LICENSE.md in the root of this distribution or
# the full text at https://opensource.org/licenses/GPL-3.0

# Computes total and all (src, dst) pairs bandwidth given a PCAP trace.
# Currently assumes a "cooked Linux" (SLL) format trace captured using `tcpdump
# -i any` from a mininet simulation.
#
# Requires `pip|pip3 install dpkt`.
#
# Useful pre-processing command lines for large PCAP files include:
#
# $ editcap -S0 -d -A"YYYY-MM-DD HH:mm:SS" -B"YYYY-MM-DD HH:mm:SS" in.pcap \
#     fragment.pcap
# 
# Update 2023 Chris Jensen (cjj39@cam.ac.uk)
# - Allow for lower than second precision in window,
# - return long format data rather than wide
# - lossless compression assuming points will be plotted with straight line (0th derivative rather than anything fancy)
# - don't require host names
# Exemplar usage:
# python pcap_bw.py file.pcap -w 0.1

import sys, socket, pprint, json
import dpkt
import argparse
import copy
import itertools as it
from typing import Generator, Tuple, Any

## dpkt.pcap.Reader iterator doesn't provide the PCAP header, only the timestamp
class R(dpkt.pcap.Reader):
    def __iter__(self):
        while 1:
            buf = self._Reader__f.read(dpkt.pcap.PktHdr.__hdr_len__)
            if not buf:
                break
            hdr = self._Reader__ph(buf)
            buf = self._Reader__f.read(hdr.caplen)
            yield (hdr.tv_sec + (hdr.tv_usec / self._divisor), hdr, buf)

    # ensure next calls into the iterator
    def __next__(self):
        return next(self.__iter__())


## from dpkt print_pcap example
def inet_to_str(inet):
    try:
        return socket.inet_ntop(socket.AF_INET, inet)
    except ValueError:
        return socket.inet_ntop(socket.AF_INET6, inet)


def get_sll_pkt(buf, hdr, version=1):
    sll : (dpkt.sll.SLL | dpkt.sll2.SLL2)
    if version == 1:
        sll = dpkt.sll.SLL(buf)
    elif version == 2:
        sll = dpkt.sll2.SLL2(buf)
    else:
        raise ValueError("version can only be 1 or 2 not %d" % version)

    pkt = None
    if sll.ethtype == 0x0800:  ## IPv4
        if sll.type == 3:  ## sent to someone else
            pkt = sll.ip
        elif sll.type == 4:  ## sent by us, ie., emitted from switch
            pass
        else:
            print(
                "[dropped %04x / %d]..." % (sll.ethtype, sll.type),
                end="",
                sep="",
                file=sys.stderr,
            )
    elif sll.ethtype == 0x0806:  ## ARP
        print(
            "[dropped ARP / %d bytes]..." % hdr.len,
            end="",
            sep="",
            file=sys.stderr,
        )
    else:
        print(
            "[dropped %04x / %d]..." % (sll.ethtype, sll.type),
            end="",
            sep="",
            file=sys.stderr,
        )
    return pkt

class Window:
    def __init__(self, window, window_start):
        self.window = window
        self.window_start = window_start
        self.window_end = window_start + window
        self.len = 0

    def get_bw(self):
        return float(self.len) / float(self.window) 

# keep track of most recent 3 windows
# if all three are the same when the window advances, then don't emit middle
# if different then emit middle
class WindowSM:
    def __init__(self, direction, window, start):
        self.window = window
        self.direction = direction

        self.prev = None
        self.curr = None
        self.next = Window(window, start)

    def advance(self):
        should_cull = \
          self.prev is not None and self.curr is not None \
          and self.prev.len == self.curr.len and self.curr.len == self.next.len

        if self.curr is not None and not should_cull:
            yield (self.curr.window_start, self.curr.window_end, self.direction, self.curr.get_bw())

        self.prev = self.curr
        self.curr = self.next
        self.next = Window(self.window, self.next.window_end)

    def try_advance(self, ts):
        while ts > self.next.window_end:
            yield from self.advance()

    def add_pkt(self, ts, len):
        yield from self.try_advance(ts)

        self.next.len += len

    def close(self):
        yield from self.advance()
        yield from self.advance()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Get the bandwidth per window from a pcap file."
    )
    parser.add_argument("INPUT", help="Pcap file to analyse")
    parser.add_argument(
        "-w",
        "--window",
        dest="WINDOW",
        default=1,
        help="Window size for bandwidth averaging. Measured in seconds",
        type=float,
    )
    parser.add_argument(
        "-v",
        dest="SLL_VERSION",
        default = 2,
        help = "Which version of linux cooked packets to use, v1 or v2",
        type = int,
    )

    parser.add_argument(
        "--tcp",
        dest="TCP_LEN",
        action="store_true",
        )

    args = parser.parse_args()

    INPUT = args.INPUT
    WINDOW = args.WINDOW  ## float seconds
    VERSION = args.SLL_VERSION
    TCP_LEN = args.TCP_LEN

    print(f"Getting bandwidth from {INPUT}", file=sys.stderr)
    print("Using IP length" if not TCP_LEN else "Using TCP segment length", file=sys.stderr, flush=True)


    with open(INPUT, "rb") as f:
        def gen():
            totbw = None
            hostbw = {}

            for cnt, item in enumerate(R(f)):
                if cnt % 10000 == 0:
                    print(cnt, "...", end="", sep="", flush=True, file=sys.stderr)

                ts, hdr, buf = item
                pkt = get_sll_pkt(buf, hdr, version=VERSION) # ip packet
                if pkt is not None:
                    src = inet_to_str(pkt.src)
                    dst = inet_to_str(pkt.dst)
                    if totbw is None:
                        totbw = WindowSM('total', WINDOW, ts)
                    if (src, dst) not in hostbw:
                        hostbw[(src, dst)] = WindowSM(f'{src}:{dst}', WINDOW, ts)
                    length = len(pkt.data.data) if TCP_LEN else pkt.len
                    yield from totbw.add_pkt(ts, length)
                    yield from hostbw[(src,dst)].add_pkt(ts, length)
            if totbw is not None:
                yield from totbw.close()
            for _, wd in hostbw.items():
                yield from wd.close()

        print("time,direction,bw", flush=True)
        for (st, ed, direction, bw) in gen():
            print(st, direction, bw, sep=",", flush=True)

