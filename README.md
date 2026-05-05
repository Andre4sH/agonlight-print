# Agonlight Print Moslet

A simple MOSlet for Agon Light that prints text files on your printer.

## Requirements

- Agon Light computer
- ESP8266 with ZiModem firmware
- `ez80asm` installed (for building)

## Usage

```sh
print <textfile>
```

## Build

```sh
ez80asm print.asm print.bin
```

## Install

```sh
move mos/print.bin /mos
```

## Printer Configuration

Create the file `/.printer.cfg` on your Agon Light filesystem.

Put a single line in the file with your printer endpoint in this format:

```text
AT+PRINTA:<printer-ip>:631/ipp/printer
```

Example:

```text
AT+PRINTA:192.168.0.4:631/ipp/printer
```

Replace `<printer-ip>` with your printer's actual IP address.
