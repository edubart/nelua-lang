/* srpmalloc.h - Small rpmalloc   - Public Domain - 2021 Eduardo Bart (https://github.com/edubart)
 * rpmalloc.c  - Memory allocator - Public Domain - 2016-2020 Mattias Jansson
 * This library is a fork of rpmalloc to be used with single thread applications
 * and with old C compilers.
 *
 * This library provides a cross-platform malloc implementation in C99.
 * The latest source code is always available at
 *
 * https://github.com/edubart/srpmalloc
 *
 * This library is put in the public domain; you can redistribute it and/or modify it without any restrictions.
 */

#ifndef RPMALLOC_H
#define RPMALLOC_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if (defined(__clang__) && __clang__ >= 4) || (defined(__GNUC__) && __GNUC__ >= 5)
# define RPMALLOC_EXPORT extern __attribute__((visibility("default")))
# define RPMALLOC_ALLOCATOR
# define RPMALLOC_ATTRIB_MALLOC __attribute__((__malloc__))
# define RPMALLOC_ATTRIB_ALLOC_SIZE(size) __attribute__((alloc_size(size)))
# define RPMALLOC_ATTRIB_ALLOC_SIZE2(count, size)  __attribute__((alloc_size(count, size)))
#elif defined(_MSC_VER)
# define RPMALLOC_EXPORT extern
# define RPMALLOC_ALLOCATOR __declspec(allocator) __declspec(restrict)
# define RPMALLOC_ATTRIB_MALLOC
# define RPMALLOC_ATTRIB_ALLOC_SIZE(size)
# define RPMALLOC_ATTRIB_ALLOC_SIZE2(count,size)
#else
# define RPMALLOC_EXPORT extern
# define RPMALLOC_ALLOCATOR
# define RPMALLOC_ATTRIB_MALLOC
# define RPMALLOC_ATTRIB_ALLOC_SIZE(size)
# define RPMALLOC_ATTRIB_ALLOC_SIZE2(count,size)
#endif

typedef enum rpmalloc_flags_t {
    //! Flag to rpaligned_realloc to not preserve content in reallocation
    RPMALLOC_NO_PRESERVE = 1,
    //! Flag to rpaligned_realloc to fail and return null pointer if grow cannot be done in-place,
    //  in which case the original pointer is still valid (just like a call to realloc which failes to allocate
    //  a new block).
    RPMALLOC_GROW_OR_FAIL = 2,
} rpmalloc_flags_t;

typedef struct rpmalloc_config_t {
    //! Map memory pages for the given number of bytes. The returned address MUST be
    //  aligned to the rpmalloc span size, which will always be a power of two.
    //  Optionally the function can store an alignment offset in the offset variable
    //  in case it performs alignment and the returned pointer is offset from the
    //  actual start of the memory region due to this alignment. The alignment offset
    //  will be passed to the memory unmap function. The alignment offset MUST NOT be
    //  larger than 65535 (storable in an uint16_t), if it is you must use natural
    //  alignment to shift it into 16 bits. If you set a memory_map function, you
    //  must also set a memory_unmap function or else the default implementation will
    //  be used for both.
    void* (*memory_map)(size_t size, size_t* offset);
    //! Unmap the memory pages starting at address and spanning the given number of bytes.
    //  If release is set to non-zero, the unmap is for an entire span range as returned by
    //  a previous call to memory_map and that the entire range should be released. The
    //  release argument holds the size of the entire span range. If release is set to 0,
    //  the unmap is a partial decommit of a subset of the mapped memory range.
    //  If you set a memory_unmap function, you must also set a memory_map function or
    //  else the default implementation will be used for both.
    void (*memory_unmap)(void* address, size_t size, size_t offset, size_t release);
    //! Called when an assert fails, if asserts are enabled. Will use the standard assert()
    //  if this is not set.
    void (*error_callback)(const char* message);
    //! Called when a call to map memory pages fails (out of memory). If this callback is
    //  not set or returns zero the library will return a null pointer in the allocation
    //  call. If this callback returns non-zero the map call will be retried. The argument
    //  passed is the number of bytes that was requested in the map call. Only used if
    //  the default system memory map function is used (memory_map callback is not set).
    int (*map_fail_callback)(size_t size);
    //! Number of spans to map at each request to map new virtual memory blocks. This can
    //  be used to minimize the system call overhead at the cost of virtual memory address
    //  space. The extra mapped pages will not be written until actually used, so physical
    //  committed memory should not be affected in the default implementation. Will be
    //  aligned to a multiple of spans that match memory page size in case of huge pages.
    size_t span_map_count;
} rpmalloc_config_t;

//! Initialize allocator with default configuration
RPMALLOC_EXPORT int
rpmalloc_initialize(void);

//! Initialize allocator with given configuration
RPMALLOC_EXPORT int
rpmalloc_initialize_config(const rpmalloc_config_t* config);

//! Get allocator configuration
RPMALLOC_EXPORT const rpmalloc_config_t*
rpmalloc_config(void);

//! Finalize allocator
RPMALLOC_EXPORT void
rpmalloc_finalize(void);

//! Initialize allocator for calling thread
RPMALLOC_EXPORT void
rpmalloc_thread_initialize(void);

//! Finalize allocator for calling thread
RPMALLOC_EXPORT void
rpmalloc_thread_finalize(int release_caches);

//! Query if allocator is initialized for calling thread
RPMALLOC_EXPORT int
rpmalloc_is_thread_initialized(void);

//! Allocate a memory block of at least the given size
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpmalloc(size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE(1);

//! Free the given memory block
RPMALLOC_EXPORT void
rpfree(void* ptr);

//! Allocate a memory block of at least the given size and zero initialize it
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpcalloc(size_t num, size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE2(1, 2);

//! Reallocate the given block to at least the given size
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rprealloc(void* ptr, size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE(2);

//! Reallocate the given block to at least the given size and alignment,
//  with optional control flags (see RPMALLOC_NO_PRESERVE).
//  Alignment must be a power of two and a multiple of sizeof(void*),
//  and should ideally be less than memory page size. A caveat of rpmalloc
//  internals is that this must also be strictly less than the span size (default 64KiB)
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpaligned_realloc(void* ptr, size_t alignment, size_t size, size_t oldsize, unsigned int flags) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE(3);

//! Allocate a memory block of at least the given size and alignment.
//  Alignment must be a power of two and a multiple of sizeof(void*),
//  and should ideally be less than memory page size. A caveat of rpmalloc
//  internals is that this must also be strictly less than the span size (default 64KiB)
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpaligned_alloc(size_t alignment, size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE(2);

//! Allocate a memory block of at least the given size and alignment, and zero initialize it.
//  Alignment must be a power of two and a multiple of sizeof(void*),
//  and should ideally be less than memory page size. A caveat of rpmalloc
//  internals is that this must also be strictly less than the span size (default 64KiB)
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpaligned_calloc(size_t alignment, size_t num, size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE2(2, 3);

//! Allocate a memory block of at least the given size and alignment.
//  Alignment must be a power of two and a multiple of sizeof(void*),
//  and should ideally be less than memory page size. A caveat of rpmalloc
//  internals is that this must also be strictly less than the span size (default 64KiB)
RPMALLOC_EXPORT RPMALLOC_ALLOCATOR void*
rpmemalign(size_t alignment, size_t size) RPMALLOC_ATTRIB_MALLOC RPMALLOC_ATTRIB_ALLOC_SIZE(2);

//! Allocate a memory block of at least the given size and alignment.
//  Alignment must be a power of two and a multiple of sizeof(void*),
//  and should ideally be less than memory page size. A caveat of rpmalloc
//  internals is that this must also be strictly less than the span size (default 64KiB)
RPMALLOC_EXPORT int
rpposix_memalign(void** memptr, size_t alignment, size_t size);

//! Query the usable size of the given memory block (from given pointer to the end of block)
RPMALLOC_EXPORT size_t
rpmalloc_usable_size(void* ptr);

#ifdef __cplusplus
}
#endif

#endif
