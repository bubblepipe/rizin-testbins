# Reproduction 

## Linux - glibc

To reproduce these binary: 

```
cd rizin-testbins/heap/src
nix profile install -f simpleheap.nix
```

The following binaries will be installed with their revelent glibc versions configured: 

```
simpleheap-glibc-2.23  
simpleheap-glibc-2.24  
simpleheap-glibc-2.26  
simpleheap-glibc-2.27  
simpleheap-glibc-2.30  
simpleheap-glibc-2.35
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

## Linux - jemalloc

The same `nix profile install -f simpleheap.nix` command will also install jemalloc binaries:

```
simpleheap-jemalloc-5.3.0
```

jemalloc has different architecture from glibc. In order to perform a full analysis we should dump its etree, extents, tcache, arena and the heap. 


```
pwndbg> p sizeof(tsd_t)
$1 = 2632
pwndbg> p (tsd_t*)pthread_getspecific(je_tsd_tsd)
$2 = (tsd_t *) 0x7ffff7dab738
pwndbg> dump binary memory tsd.bin 0x7ffff7dab738 (0x7ffff7dab738 + 2632)
```

```
pwndbg> p *(tsd_t*)pthread_getspecific(je_tsd_tsd)
$1 = {
  ...
  cant_access_tsd_items_directly_use_a_getter_or_setter_arena = 0x7ffff7a010c0,
...


```
the address of the arena is `0x7ffff7a010c0`. 

```
struct arena_s {
    ... 
	
	/*
	 * The arena is allocated alongside its bins; really this is a
	 * dynamically sized array determined by the binshard settings.
	 * Enforcing cacheline-alignment to minimize the number of cachelines
	 * touched on the hot paths.
	 */
	JEMALLOC_WARN_ON_USAGE("Do not use this field directly. "
	                       "Use `arena_get_bin` instead.")
	JEMALLOC_ALIGNED(CACHELINE)
	bin_with_batch_t			all_bins[0];
};
```
jemalloc defines its arena as a dynamically sized struct. `p sizeof(arena_t)` says the size without `all_bins` is `78952` bytes. 
Dump `0x40000 bytes` from `0x7ffff7a010c0` would be suffice to cover everyting. 
```
dump binary memory arena.bin 0x7ffff7a010c0 (0x7ffff7a010c0 + 0x40000) 
```

```
pwndbg> p/x sizeof(emap_t)
$38 = 0x200078
pwndbg> &je_arena_emap_global
$40 = (emap_t *) 0x55555560a9a0 <je_arena_emap_global>
```

pwndbg locates all extents by traversing the entire radix tree. For simplicity, we dump the entire chunk of memory that contains all extents. 
```
pwndbg> jemalloc-heap 
Jemalloc heap
This command was tested only for jemalloc 5.3.0 and does not support lower versions

Allocated Address: 0x7ffff7800000
Extent Address: 0x7ffff7a16500
Size: 0x8000
Small class: False
State: Active

Allocated Address: 0x7ffff7808000
Extent Address: 0x7ffff7a16580
Size: 0x1000
Small class: True
State: Active

Allocated Address: 0x7ffff7809000
Extent Address: 0x7ffff7a16980
Size: 0x1000
Small class: True
State: Active

Allocated Address: 0x7ffff780a000
Extent Address: 0x7ffff7a16a00
Size: 0x1000
Small class: True
State: Active

Allocated Address: 0x7ffff780b000
Extent Address: 0x7ffff7a16a80
Size: 0x1000
Small class: True
State: Active

Allocated Address: 0x7ffff780c000
Extent Address: 0x7ffff7a16b00
Size: 0x1f4000
Small class: False
State: Retained

pwndbg> p/x sizeof(edata_t)
$42 = 0x80

pwndbg> dump binary memory extents.bin 0x7ffff7800000 (0x7ffff7a16b00 + 0x80) 
```

```
cat /proc/2347404/maps                                                          
555555554000-55555555c000 r--p 00000000 103:02 6190159                   /home/bubblepipe/simpleheap-jemalloc/simpleheap
55555555c000-5555555e7000 r-xp 00008000 103:02 6190159                   /home/bubblepipe/simpleheap-jemalloc/simpleheap
5555555e7000-5555555fc000 r--p 00093000 103:02 6190159                   /home/bubblepipe/simpleheap-jemalloc/simpleheap
5555555fc000-555555602000 r--p 000a7000 103:02 6190159                   /home/bubblepipe/simpleheap-jemalloc/simpleheap
555555602000-555555603000 rw-p 000ad000 103:02 6190159                   /home/bubblepipe/simpleheap-jemalloc/simpleheap
555555603000-55555580d000 rw-p 00000000 00:00 0 
```
Every allocated address from previous pwndbg output resides within the `Inside 7ffff7400000-7ffff7c00000` range. 
```
pwndbg> dump binary memory heap.bin 0x7ffff7400000 0x7ffff7c00000
```

```
cat arena.bin tsd.bin rtree.bin extents.bin heap.bin > simpleheap_linux_jemalloc-5.30_x64.bin
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


simpleheap_linux_jemalloc-5.30_x64.bin
```
om 3 0x7ffff7a010c0 0x40000 0x0 rw- arena 
om 3 0x7ffff7dab738 0xa48 0x40000 rw- tsd
om 3 0x55555560a9a0 0x200078 0x40a48 rw- rtree
om 3 0x7ffff7800000 0x216b80 0x2362048 rw- extents
om 3 0x7ffff7400000 0x800000 0x2578bc8 rw- [heap]
```
