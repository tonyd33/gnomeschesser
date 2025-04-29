#include <cstdint>

uint16_t swap16(uint16_t x) { return (x << 8) | (x >> 8); }

uint32_t swap32(uint32_t x) {
  return ((x << 24) & 0xFF000000) | ((x << 8) & 0x00FF0000) |
         ((x >> 8) & 0x0000FF00) | ((x >> 24) & 0x000000FF);
}

uint64_t swap64(uint64_t x) {
  return ((x << 56) & 0xFF00000000000000ULL) |
         ((x << 40) & 0x00FF000000000000ULL) |
         ((x << 24) & 0x0000FF0000000000ULL) |
         ((x << 8) & 0x000000FF00000000ULL) |
         ((x >> 8) & 0x00000000FF000000ULL) |
         ((x >> 24) & 0x0000000000FF0000ULL) |
         ((x >> 40) & 0x000000000000FF00ULL) |
         ((x >> 56) & 0x00000000000000FFULL);
}
