gcc -g -shared -fPIC -O3 -o picoshim.so shim.c -ldl -pthread && chmod +x package/rootfs/home/pico/wget && echo BUILT!
