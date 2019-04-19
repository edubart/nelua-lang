#include <stdint.h>
#include <stdio.h>
#include <assert.h>

static int64_t mandel(int64_t width) {
    int64_t height = width; double wscale = 2.0 / width;
    int64_t m = 50; double limit2 = 4.0;
    int64_t sum = 0;
    for(int64_t y = 0; y <= height - 1; y += 1) {
        double Ci = ((2.0 * y) / height) - 1;
        for(int64_t xb = 0; xb <= width - 1; xb += 8) {
            int64_t bits = 0;
            int64_t xbb = xb + 7;
            int64_t xblimit = 0;
            if(xbb < width) {
                xblimit = xbb;
            } else {
                xblimit = width - 1;
            }
            for(int64_t x = xb; x <= xblimit; x += 1) {
                bits = bits + bits;
                double Zr = 0.0; double Zi = 0.0; double Zrq = 0.0; double Ziq = 0.0;
                double Cr = (x * wscale) - 1.5;
                for(int64_t i = 1; i <= m; i += 1) {
                    double Zri = Zr * Zi;
                    Zr = (Zrq - Ziq) + Cr;
                    Zi = (Zri + Zri) + Ci;
                    Zrq = Zr * Zr;
                    Ziq = Zi * Zi;
                    if((Zrq + Ziq) > limit2) {
                        bits = bits + 1;
                        break;
                    }
                }
            }
            if(xbb >= width) {
                for(int64_t x = width; x <= xbb; x += 1) {
                    bits = (bits + bits) + 1;
                }
            }
            sum = sum + bits;
        }
    }
    return sum;
}

int main() {
    int64_t res = mandel(1024);
    printf("%li\n", res);
    assert(res == 20164264);
    return 0;
}
