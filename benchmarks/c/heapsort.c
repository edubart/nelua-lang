#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

void heapsort(double* a, int64_t n) {
    int l = n / 2, p, j, t;
    while(true) {
        if (l > 0) {
            l--;
            t = a[l];
        } else {
            n--;
            if(n == 0)
                return;
            t = a[n];
            a[n] = a[0];
        }
        p = l;
        j = l * 2 + 1;
        while(j < n) {
            if((j + 1 < n) && (a[j + 1] > a[j]))
                j++;
            if (a[j] > t) {
                a[p] = a[j];
                p = j;
                j = p * 2 + 1;
            } else
                break;
        }
        a[p] = t;
    }
}

int64_t random_int(int64_t seed) {
    return ((1103515245 * seed) + 12345) % 2147483648;
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
    for(int64_t i = 0; i < N - 1; i += 1)
        assert(a[i] <= a[i + 1]);
    free(a);
    return 0;
}
