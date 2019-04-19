#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

static void heapsort(double* a, int64_t n) {
    int64_t j = 0; int64_t i = 0; double t = 0;
    int64_t l = n / 2;
    int64_t k = n - 1;
    while(true) {
        if(l > 0) {
            l = l - 1;
            t = a[l];
        } else {
            t = a[k];
            a[k] = a[0];
            k = k - 1;
            if(k == 0) {
                a[0] = t;
                return;
            }
        }
        i = l;
        j = l * 2 + 1;
        while(j <= k) {
            if(j < k && a[j] < a[j + 1])
                j = j + 1;
            if(t < a[j]) {
                a[i] = a[j];
                i = j;
                j = j + i + 1;
            } else
                j = k + 1;
        }
        a[i] = t;
    }
}

static int64_t random_int(int64_t seed) {
    return (214013 * seed + 2531011) % 2147483648;
}

int main() {
    const int64_t N = 1000000;
    double* a = (double*)malloc(sizeof(double) * N);
    int64_t rand = 123456789;
    for(int64_t i = 0; i < N; i += 1) {
        rand = random_int(rand);
        a[i] = rand;
    }
    heapsort(a, N);
    double sum = 0;
    for(int64_t i = 0; i < N - 1; i += 1) {
        assert(a[i] <= a[i + 1]);
        sum = sum + (a[i + 1] - a[i]);
    }
    printf("%lf\n", sum);
    assert(sum == 2147480127.0);
    free(a);
    return 0;
}
