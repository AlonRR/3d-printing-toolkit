#pragma once

/* Runs the four-part benchmark and logs a table.
 *
 * The BOARD LISTENS on `port`; the PC connects to it once per network phase.
 * That direction avoids needing an inbound firewall rule on the lab hosts, and
 * it measures transmit throughput, which is the direction that matters.
 *
 * Requires WiFi up and the camera started. Blocks waiting for connections. */
void benchmark_run(int port);
