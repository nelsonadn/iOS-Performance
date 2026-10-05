# Measurement Overhead

No universal overhead numbers are published from this repository. Sampling uses a configurable 50, 100, 250, 500, or 1000 ms cadence and is intended to run only while one or more named sessions are active. The implementation's overhead must be measured on the target physical device before interpreting small differences between applications.

Recommended method: create equivalent Release builds and use the same device, OS, backend, data, and scenario. Alternate uninstrumented and instrumented runs to reduce thermal/order bias. Compare XCTest/Instruments CPU, memory, and hitch results across no instrumentation and each configured interval. Use enough repeated runs to report median and spread. Avoid claiming that one device's estimate generalizes to other hardware. Report SDK sampling values separately from XCTest and Instruments values.
