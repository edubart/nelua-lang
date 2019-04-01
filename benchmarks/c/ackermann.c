#include <stdint.h>
#include <stdio.h>

int64_t ack(int64_t m, int64_t n) {
    if(m == 0) {
        return n + 1;
    }
    if(n == 0) {
        return ack(m - 1, 1);
    }
    return ack(m - 1, ack(m, n - 1));
}

int main() {
    int64_t res = ack(3, 10);
    printf("%li\n", res);
    return 0;
}
