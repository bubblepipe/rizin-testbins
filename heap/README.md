# Reproduction 

## Linux 

To reproduce these binary: 

```
cd rizin-testbins/heap/src
nix profile install -f simpleheap.nix
```

The following binaries will be installed with their revelent glibc versions configured: 

```
simpleheap-2.23  
simpleheap-2.24  
simpleheap-2.26  
simpleheap-2.27  
simpleheap-2.30  
simpleheap-2.35
```

Run one of the binary, then attach `pwndgb`. The memory heap can be extracted with the following command: 

```
pwndbg> p sizeof(struct malloc_state)
$3 = 2200
pwndbg> arenas
  arena type    arena address    heap address       map start         map end    perm    size    offset    file
------------  ---------------  --------------  --------------  --------------  ------  ------  --------  ------
  main_arena   0x7f01c9a07ac0  0x562800205000  0x562800205000  0x562800226000    rw-p   21000         0  [heap]
```

arena starts at `0x7f01c9a07ac0` and ends at `0x7f01c9a07ac0 + 2200 = 
0x7f01c9a08358`, heap starts at `0x562800205000` and ends at `0x562800226000`. To dump them, use the following command: 

```
dump binary memory arena.bin 0x7f01c9a07ac0 0x7f01c9a08358
dump binary memory heap.bin 0x562800205000 0x562800226000
```

Then use `cat` to merge them into a single binary file: 
```
cat arena.bin heap.bin > simpleheap_linux_glibc-*_x64.bin
```

The command to config memory mapping in rizin is:
```
om 3 0x7f01c9a07ac0 0x898 0x0 rw- arena
om 3 0x562800205000 0x21000 0x898 rw- [heap]
```

# Memory map configurations 
simpleheap_linux_glibc-2.35_x64.bin
```
om 3 0x7f1123bfaaa0 0x898 0x0 rw- arena 
om 3 0x90c000 0x21000 0x898 rw- [heap]
```

simpleheap_linux_glibc-2.30_x64.bin
```
om 3 0x7fecf94179e0 0x898 0x0 rw- arena 
om 3 0x2476e000 0x21000 0x898 rw- [heap]
```

simpleheap_linux_glibc-2.27_x64.bin
```
om 3 0x7f4ea3630aa0 0x898 0x0 rw- arena 
om 3 0x2db29000 0x21000 0x898 rw- [heap]
```

simpleheap_linux_glibc-2.26_x64.bin
```
om 3 0x7f5c2efacaa0 0x898 0x0 rw- arena 
om 3 0x1dbc5000 0x21000 0x898 rw- [heap]
```

simpleheap_linux_glibc-2.24_x64.bin
```
om 3 0x7f7a50198a80 0x898 0x0 rw- arena 
om 3 0x32c64000 0x21000 0x898 rw- [heap]
```

simpleheap_linux_glibc-2.23_x64.bin
```
om 3 0x7ff1c3f9bb20 0x898 0x0 rw- arena 
om 3 0x2975e000 0x21000 0x898 rw- [heap]
```

