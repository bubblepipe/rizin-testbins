#include <stdio.h>
  #include <stdlib.h>
  #include <string.h>
  #include <unistd.h>

  int main() {
      printf("PID: %d\n", getpid());

      // Allocate small chunk (32 bytes)
      char *small = malloc(32);
      strcpy(small, "hello world");
      printf("Small chunk at %p: %s\n", small, small);

      // Allocate big chunk (1024 bytes)
      char *big = malloc(1024);
      strcpy(big, "hello world");
      printf("Big chunk at %p: %s\n", big, big);

      printf("\nWaiting... (press Enter to exit)\n");
      getchar();

      free(small);
      free(big);

      return 0;
  }
