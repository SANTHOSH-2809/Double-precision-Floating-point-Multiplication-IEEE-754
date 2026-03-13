# Double-precision-Floating-point-Multiplicaiton
Double precision floating point multiplication in IEEE-754 format.

---
## Description

This project implements a 64-bit IEEE-754 double-precision floating-point multiplier in Verilog. The design extracts the sign, exponent, and mantissa fields from two 64-bit floating-point operands, performs mantissa multiplication, normalizes the result, and reconstructs the final floating-point number according to the IEEE-754 standard.

The architecture also handles special floating-point values such as NaN, Infinity, and Zero. The design is modular and synthesizable, making it suitable for FPGA prototyping and VLSI RTL design practice.

## Project Attributes

| Attribute           | Description                                                            |
| ------------------- | ---------------------------------------------------------------------- |
| Language            | Verilog HDL                                                            |
| Standard            | IEEE-754 Double Precision                                              |
| Data Width          | 64 bits                                                                |
| Sign Bit            | 1 bit                                                                  |
| Exponent            | 11 bits                                                                |
| Mantissa            | 52 bits                                                                |
| Mantissa Multiplier | 53 × 53 bit multiplication                                             |
| Design Style        | Combinational RTL                                                      |
| Modules             | Floating-point core logic with normalization and special-case handling |
| Verification        | Simulation testbench with normal, edge, and special cases              |


## Features

 - IEEE-754 double precision (64-bit) format support

 - Automatic sign calculation using XOR logic

 - Exponent bias removal and rebiasing

 - 53-bit mantissa multiplication

 - Result normalization

 - Detection and handling of:

      - NaN

      - Infinity

      - Zero

      - Overflow detection

      - Underflow detection

 - Modular design for easier debugging and extension


## Possible Operation

| Operand A      | Operand B | Result             |
| -------------- | --------- | ------------------ |
| Normal         | Normal    | Normalized product |
| Normal         | Zero      | Zero               |
| Zero           | Normal    | Zero               |
| Zero           | Zero      | Zero               |
| Infinity       | Normal    | Infinity           |
| Normal         | Infinity  | Infinity           |
| Infinity       | Zero      | NaN                |
| Zero           | Infinity  | NaN                |
| Infinity       | Infinity  | Infinity           |
| NaN            | Any       | NaN                |
| Any            | NaN       | NaN                |
| Overflow case  | Any       | Infinity           |
| Underflow case | Any       | Zero               |

## Range in Magnitude

| Result magnitude                                | Output                    |
| ----------------------------------------------- | ------------------------- |
| `2^-1022` ≤ result ≤ `1.7976931348623157 × 10^308` | correct normalized number |
| `< 2^-1022`                                     | **0 (flush-to-zero)**     |
| `> 1.7976931348623157 × 10^308`                 | **Infinity (overflow)**   |

## Equivalent Hex Range (IEEE-754 Double)

| Result magnitude                                 | Output                    |
| ------------------------------------------------ | ------------------------- |
| `0010000000000000` ≤ result ≤ `7FEFFFFFFFFFFFFF` | correct normalized number |
| result `< 0010000000000000`                      | **0000000000000000 (0)**  |
| result `> 7FEFFFFFFFFFFFFF`                      | **7FF0000000000000 (+Infinity)** |


### hw_vio_1
<img width="1196" height="471" alt="Screenshot 2026-03-12 174029" src="https://github.com/user-attachments/assets/ea4ceca8-e055-4030-a509-45d85b792c79" />

### Schematic
<img width="1551" height="441" alt="image" src="https://github.com/user-attachments/assets/a1a1518c-dc29-45fc-9787-b2a3a1bc2f55" />
<img width="1114" height="772" alt="image" src="https://github.com/user-attachments/assets/ae3e6371-3006-4fb7-86d1-7c2dd94fe1a8" />

### design_wrapper
<img width="764" height="271" alt="image" src="https://github.com/user-attachments/assets/83088c32-82af-4f91-a5ee-3ef403029cda" />

### I/O Ports
<img width="1615" height="352" alt="Screenshot 2026-03-12 172229" src="https://github.com/user-attachments/assets/5bdec026-09a1-42cc-bdff-f38c7a953dbf" />

## Summary

### Power Summary
<img width="1604" height="495" alt="image" src="https://github.com/user-attachments/assets/b0057455-674c-4af9-9d6d-d72e6c88ccbe" />

### Timing
<img width="1582" height="508" alt="image" src="https://github.com/user-attachments/assets/0c29c05a-2dc7-4662-b083-4699bd3207b4" />
