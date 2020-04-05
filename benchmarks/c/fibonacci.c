#include <stdint.h>
#include <stdio.h>
#include <assert.h>

static uint64_t fibmod(uint64_t n, uint64_t m) {
    uint64_t a = 0;
    uint64_t b = 1;
    for(uint64_t i = 1; i <= n; i += 1) {
        uint64_t nb = (a + b) % m;
        a = b;
        b = nb;
    }
    return a;
}

int main() {
    uint64_t res = fibmod(100000000, 1000000000000);
    printf("%lu\n", res);
    assert(res == 167760546875);
    return 0;
}
