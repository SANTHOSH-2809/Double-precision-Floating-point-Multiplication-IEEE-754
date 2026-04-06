# Double-precision-Floating-point-Multiplicaiton
Double precision floating point multiplication in IEEE-754 format.

---
## Description

This project implements a 64-bit IEEE-754 double-precision floating-point multiplier in Verilog. The design extracts the sign, exponent, and mantissa fields from two 64-bit floating-point operands, performs mantissa multiplication, normalizes the result, and reconstructs the final floating-point number according to the IEEE-754 standard.

The architecture also handles special floating-point values such as NaN, Infinity, and Zero. The design is modular and synthesizable, making it suitable for FPGA prototyping and VLSI RTL design practice.

---

## Project Attributes

| Attribute             | Description                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------- |
| Language              | Verilog HDL                                                                                          |
| Standard              | IEEE-754 Double Precision (partial compliance)                                                       |
| Data Width            | 64 bits                                                                                              |
| Sign Bit              | 1 bit                                                                                                |
| Exponent              | 11 bits (bias = 1023)                                                                                |
| Mantissa              | 52 bits (implicit leading 1 for normalized numbers)                                                  |
| Mantissa Multiplier   | 53 × 53-bit multiplication                                                                           |
| Design Style          | Combinational RTL                                                                                    |
| Modules               | Floating-point multiplication core with normalization, exponent handling, and special-case detection |
| Special Case Handling | Supports NaN, Infinity, Zero; subnormals flushed to zero                                             |
| Rounding              | Not implemented (truncation used)                                                                    |
| Verification          | Simulation testbench with normal, boundary, overflow, underflow, and special cases                   |


---
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

---
## Overview
This project implements a 64-bit double-precision floating-point multiplier in Verilog HDL based on the IEEE-754 standard (partial compliance). The design focuses on normalized number operations with support for special cases such as NaN, Infinity, and Zero.

---
## Features
- 64-bit IEEE-754 double-precision format
- 53 × 53-bit mantissa multiplication
- Exponent bias handling (bias = 1023)
- Normalization of mantissa
- Special case handling:
  - NaN
  - Infinity
  - Zero
- Overflow → Infinity
- Underflow → Zero (flush-to-zero)

---
## Limitations
- Subnormal numbers are not supported (treated as zero)
- Rounding is not implemented (truncation used)
- Combinational design (no pipelining)

---
## Architecture
The multiplier follows these steps:
1. Field extraction (sign, exponent, mantissa)
2. Special case detection
3. Mantissa multiplication
4. Exponent addition and normalization
5. Result reconstruction

---
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

---
## Block Diagram

[Block Diagram for floating point multiplication](https://github.com/user-attachments/assets/c9748242-2738-4481-80bc-7dcaac49d7ba)

---
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

---
### hw_vio_1

<img width="838" height="450" alt="image" src="https://github.com/user-attachments/assets/60ea1693-dc09-43e4-9df6-cbee60961a0f" />

---
## Video
[Demo video](https://drive.google.com/file/d/109JcUdwhV3lv-jsfLOvnb3OAdQbGQAIu/view?usp=sharing)

---

### Schematic
<img width="1172" height="468" alt="image" src="https://github.com/user-attachments/assets/3f241eb7-cf8d-4226-b7cf-75886e328b5d" />
<img width="1121" height="786" alt="image" src="https://github.com/user-attachments/assets/ec9c5f23-41a6-408e-8c77-741fc689c00f" />

---
### Block Design
<img width="764" height="271" alt="image" src="https://github.com/user-attachments/assets/83088c32-82af-4f91-a5ee-3ef403029cda" />

---
### I/O Ports
<img width="1615" height="352" alt="Screenshot 2026-03-12 172229" src="https://github.com/user-attachments/assets/5bdec026-09a1-42cc-bdff-f38c7a953dbf" />

---
## Summary

### Power Summary
<img width="1185" height="458" alt="image" src="https://github.com/user-attachments/assets/785a8715-9727-42fb-a8a9-3fb468aaba7b" />

### Timing
<img width="1267" height="404" alt="image" src="https://github.com/user-attachments/assets/4a79c42c-5352-4a1a-aa5a-34b95a446eaa" />

---

## Resources
The below listed websites are used to debug our code easily according to result
 - [IEEE-754 Converter](https://numeral-systems.com/ieee-754-converter/)
 - [Floating Point Multiplier](https://numeral-systems.com/ieee-754-multiply/)
 - [Zip-file](floaingpoint.zip) Download the raw file and open the Vivado Project File(type of file) then rerun the process from syntheis to bit-stream generation.

---

## Future Work
- Implement IEEE-754 rounding (round-to-nearest-even)
- Add support for subnormal numbers
- Pipeline the design for high-speed applications
- Extend design to posit arithmetic for improved precision

---
