#include <stdint.h>
#include <stdio.h>
#include <assert.h>

static int64_t fibmod(int64_t n, int64_t m) {
    int64_t a = 0;
    int64_t b = 1;
    for(int64_t i = 1; i <= n; i += 1) {
        int64_t nb = (a + b) % m;
        a = b;
        b = nb;
    }
    return a;
}

int main() {
    int64_t res = fibmod(100000000, 1000000000000);
    printf("%li\n", res);
    assert(res == 167760546875);
    return 0;
}
