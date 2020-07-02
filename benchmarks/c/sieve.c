#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

static int64_t sieve(int64_t N) {
    bool* is_prime = (bool*)malloc(sizeof(bool) * (N+1));
    is_prime[1] = false;
    for(int64_t n = 2; n <= N; n += 1) {
        is_prime[n] = true;
    }
    int64_t nprimes = 0;
    for(int64_t n = 2; n <= N; n += 1) {
        if(is_prime[n]) {
            nprimes = nprimes + 1;
            for(int64_t m = n + n; m <= N; m += n) {
                is_prime[m] = false;
            }
        }
    }
    free(is_prime);
    return nprimes;
}

int main() {
    int64_t res = sieve(10000000);
    printf("%li\n", res);
    assert(res == 664579);
    return 0;
}
