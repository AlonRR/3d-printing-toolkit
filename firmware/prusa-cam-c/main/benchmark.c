/* How fast can this board capture, and how fast can it ship the result?
 *
 * Four measurements, kept SEPARATE on purpose - the same discipline that made
 * the camera format fault diagnosable. An end-to-end number alone cannot say
 * whether the sensor, the CPU or the radio is the limit, and the whole point of
 * the exercise is to find out which.
 *
 *   1. capture only     - fb_get/fb_return in a tight loop. The sensor and DMA
 *                         ceiling, with nothing else in the way.
 *   2. software encode  - frame2jpg on the CPU, milliseconds per frame.
 *   3. radio only       - one buffer already in RAM, sent repeatedly. Pure TCP
 *                         throughput with no camera involved.
 *   4. pipeline         - capture then send, per frame. The real thing.
 *
 * The gap between 3 and 4 is what attributes the bottleneck. If they match, the
 * radio is the limit; if 4 is much slower, the capture or the copy is.
 *
 * A raw TCP socket is used rather than HTTP so the figure is the link and not a
 * parser. The receiving end prints its own MB/s, giving an independent
 * cross-check on the number this file reports - a measurement that only agrees
 * with itself is not evidence.
 *
 * THE BOARD LISTENS; THE PC CONNECTS. The obvious arrangement is the reverse -
 * a sink on the server - but the host firewall is enabled and blocks
 * arbitrary inbound ports, and per-container firewalls are enabled. Opening one
 * would be a change to someone else's host for the sake of a measurement.
 * Inverting the direction avoids that entirely, and it measures the direction
 * that actually matters: how fast this board can TRANSMIT.
 */

#include "benchmark.h"

#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "camera.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "img_converters.h"
#include "wifi.h"

static const char *TAG = "bench";

/* Frames discarded before timing starts. The sensor's auto-exposure and gain
 * are still settling immediately after a mode change, and those first frames
 * arrive at a different rate than the steady state. */
#define WARMUP_FRAMES 5

static int s_listen_fd = -1;

/* Opens the listening socket once. The PC connects to it for each phase. */
static esp_err_t bench_listen(int port)
{
    s_listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (s_listen_fd < 0) {
        ESP_LOGE(TAG, "socket() failed");
        return ESP_FAIL;
    }
    int one = 1;
    setsockopt(s_listen_fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port = htons(port),
        .sin_addr.s_addr = htonl(INADDR_ANY),
    };
    if (bind(s_listen_fd, (struct sockaddr *) &addr, sizeof(addr)) != 0) {
        ESP_LOGE(TAG, "bind(%d) failed", port);
        close(s_listen_fd);
        s_listen_fd = -1;
        return ESP_FAIL;
    }
    listen(s_listen_fd, 2);
    return ESP_OK;
}

/* Waits for the PC to connect for the next phase. */
static int bench_accept(const char *phase)
{
    ESP_LOGI(TAG, "waiting for a connection for: %s", phase);
    struct sockaddr_in peer;
    socklen_t len = sizeof(peer);
    int fd = accept(s_listen_fd, (struct sockaddr *) &peer, &len);
    if (fd < 0) {
        ESP_LOGE(TAG, "accept failed");
        return -1;
    }

    /* Nagle batches small writes and would defer data until a later write
     * filled a segment, making per-frame timing meaningless. */
    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    int sndbuf = 64 * 1024;
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));

    ESP_LOGI(TAG, "  connected from %s", inet_ntoa(peer.sin_addr));
    return fd;
}

/* send() returns after a partial write on a stream socket, so a single call is
 * not a sent buffer. Looping until the whole buffer is gone is the difference
 * between measuring throughput and measuring the first fragment. */
static bool send_all(int fd, const uint8_t *buf, size_t len)
{
    size_t sent = 0;
    while (sent < len) {
        int n = send(fd, buf + sent, len - sent, 0);
        if (n <= 0) {
            return false;
        }
        sent += (size_t) n;
    }
    return true;
}

static void bench_capture(int frames)
{
    for (int i = 0; i < WARMUP_FRAMES; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) esp_camera_fb_return(fb);
    }

    int64_t t0 = esp_timer_get_time();
    size_t bytes = 0;
    int got = 0;
    for (int i = 0; i < frames; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) continue;
        bytes += fb->len;
        got++;
        esp_camera_fb_return(fb);
    }
    int64_t us = esp_timer_get_time() - t0;

    ESP_LOGI(TAG, "1. CAPTURE ONLY : %d frames in %.2f s = %.1f fps, %.2f MB/s",
             got, us / 1e6, got / (us / 1e6), bytes / (us / 1e6) / 1048576.0);
}

static void bench_encode(int frames)
{
    int64_t total = 0;
    size_t jpg_bytes = 0;
    int ok = 0;

    for (int i = 0; i < frames; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) continue;

        uint8_t *out = NULL;
        size_t out_len = 0;
        int64_t t0 = esp_timer_get_time();
        bool good = frame2jpg(fb, 80, &out, &out_len);
        int64_t us = esp_timer_get_time() - t0;
        esp_camera_fb_return(fb);

        if (good && out) {
            total += us;
            jpg_bytes += out_len;
            ok++;
            free(out);
        }
    }

    if (ok == 0) {
        ESP_LOGW(TAG, "2. SW ENCODE    : no frames encoded");
        return;
    }
    ESP_LOGI(TAG, "2. SW ENCODE    : %.0f ms/frame -> %.1f fps ceiling, "
                  "avg %u B/jpeg",
             (total / (double) ok) / 1000.0,
             1e6 / (total / (double) ok),
             (unsigned) (jpg_bytes / ok));
}

static void bench_radio(size_t chunk, int reps)
{
    /* One buffer, filled once, sent many times. No camera involved, so this is
     * the radio and TCP stack alone. */
    uint8_t *buf = heap_caps_malloc(chunk, MALLOC_CAP_SPIRAM);
    if (!buf) {
        ESP_LOGE(TAG, "3. RADIO ONLY   : could not allocate %u bytes",
                 (unsigned) chunk);
        return;
    }
    for (size_t i = 0; i < chunk; i++) {
        buf[i] = (uint8_t) i;   /* not all-zero: some paths compress */
    }

    int fd = bench_accept("3. radio only");
    if (fd < 0) { free(buf); return; }

    int64_t t0 = esp_timer_get_time();
    size_t sent = 0;
    for (int i = 0; i < reps; i++) {
        if (!send_all(fd, buf, chunk)) {
            ESP_LOGW(TAG, "send failed at rep %d", i);
            break;
        }
        sent += chunk;
    }
    int64_t us = esp_timer_get_time() - t0;
    close(fd);
    free(buf);

    ESP_LOGI(TAG, "3. RADIO ONLY   : %.2f MB in %.2f s = %.2f MB/s (rssi %d dBm)",
             sent / 1048576.0, us / 1e6, sent / (us / 1e6) / 1048576.0,
             wifi_rssi());
}

static void bench_pipeline(int frames, bool as_jpeg)
{
    int fd = bench_accept(as_jpeg ? "4b. pipeline JPEG" : "4a. pipeline RAW");
    if (fd < 0) return;

    for (int i = 0; i < WARMUP_FRAMES; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) esp_camera_fb_return(fb);
    }

    int64_t t0 = esp_timer_get_time();
    size_t sent = 0;
    int done = 0;

    for (int i = 0; i < frames; i++) {
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) continue;

        bool ok;
        if (as_jpeg) {
            uint8_t *out = NULL;
            size_t out_len = 0;
            if (frame2jpg(fb, 80, &out, &out_len) && out) {
                ok = send_all(fd, out, out_len);
                if (ok) sent += out_len;
                free(out);
            } else {
                ok = false;
            }
        } else {
            ok = send_all(fd, fb->buf, fb->len);
            if (ok) sent += fb->len;
        }

        esp_camera_fb_return(fb);
        if (!ok) break;
        done++;
    }

    int64_t us = esp_timer_get_time() - t0;
    close(fd);

    ESP_LOGI(TAG, "4. PIPELINE %-4s: %d frames in %.2f s = %.2f fps, %.2f MB/s",
             as_jpeg ? "JPEG" : "RAW", done, us / 1e6,
             done / (us / 1e6), sent / (us / 1e6) / 1048576.0);
}

void benchmark_run(int port)
{
    ESP_LOGI(TAG, "================ BENCHMARK ================");
    ESP_LOGI(TAG, "ip %s   rssi %d dBm   listening on port %d",
             wifi_ip_str(), wifi_rssi(), port);

    /* The two local measurements need no network, so they run first and are
     * still useful even if nothing ever connects. */
    bench_capture(50);
    bench_encode(10);

    if (bench_listen(port) != ESP_OK) {
        ESP_LOGE(TAG, "cannot listen - network phases skipped");
        return;
    }

    bench_radio(64 * 1024, 160);      /* ~10 MB, no camera involved */
    bench_pipeline(30, false);        /* capture -> send, raw */
    bench_pipeline(15, true);         /* capture -> encode -> send */

    close(s_listen_fd);
    s_listen_fd = -1;
    ESP_LOGI(TAG, "===========================================");
}
