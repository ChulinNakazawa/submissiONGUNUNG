#!/usr/bin/env python3
import gzip, re, subprocess

def encode(x):
    return '<U{:08X}>'.format(x)

width = {}
mx = 0
is_width = False

# read original width information from charmaps/UTF-8
with gzip.open('/usr/share/i18n/charmaps/UTF-8.gz') as f:
    lines = f.read().decode().splitlines()
    for line in lines:
        if line == 'WIDTH'