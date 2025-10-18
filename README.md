# Pix - Wake The Frick Up

## What it do?

Zig program that runs as a service to send magic packets to wake on lan
enabled devices based on pairs of MAC addresses and IP addresses.

## How it do?

```sh

./pix-wtfu -p 192.168.20.1,00:11:22:33:44:55 

# note that -p can be repeated multiple times for multiple pairs
```

## Why it do?

I wanted write something in zig, and something useful I could use
