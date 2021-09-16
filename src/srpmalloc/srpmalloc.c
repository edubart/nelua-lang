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

#include "srpmalloc.h"

////////////
///
/// Build time configurable limits
///
//////

#ifndef HEAP_ARRAY_SIZE
//! Size of heap hashmap
#define HEAP_ARRAY_SIZE           47
#endif
#ifndef ENABLE_ASSERTS
//! Enable asserts
#define ENABLE_ASSERTS            0
#endif
#ifndef DEFAULT_SPAN_MAP_COUNT
//! Default number of spans to map in call to map more virtual memory (default values yield 4MiB here)
#define DEFAULT_SPAN_MAP_COUNT    64
#endif
#ifndef GLOBAL_CACHE_MULTIPLIER
//! Multiplier for global cache
#define GLOBAL_CACHE_MULTIPLIER   8
#endif

#if defined(_WIN32) || defined(__WIN32__) || defined(_WIN64)
#  define PLATFORM_WINDOWS 1
#  define PLATFORM_POSIX 0
#else
#  define PLATFORM_WINDOWS 0
#  define PLATFORM_POSIX 1
#endif

/// Platform and arch specifics
#if PLATFORM_WINDOWS
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#else
#  include <unistd.h>
#  include <stdio.h>
#  include <stdlib.h>
#  include <time.h>
#  if defined(__APPLE__)
#    include <TargetConditionals.h>
#    if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
#    include <mach/mach_vm.h>
#    include <mach/vm_statistics.h>
#    endif
#  endif
#endif

#include <stdint.h>
#include <string.h>
#include <errno.h>

#if PLATFORM_POSIX
#  include <sys/mman.h>
#  include <sched.h>
#  ifndef MAP_UNINITIALIZED
#    define MAP_UNINITIALIZED 0
#  endif
#endif
#include <errno.h>

#if ENABLE_ASSERTS
#  undef NDEBUG
#  if defined(_MSC_VER) && !defined(_DEBUG)
#    define _DEBUG
#  endif
#  include <assert.h>
#define RPMALLOC_TOSTRING_M(x) #x
#define RPMALLOC_TOSTRING(x) RPMALLOC_TOSTRING_M(x)
#define rpmalloc_assert(truth, message)                                                                      \
    do {                                                                                                     \
        if (!(truth)) {                                                                                      \
            if (_memory_config.error_callback) {                                                             \
                _memory_config.error_callback(                                                               \
                    message " (" RPMALLOC_TOSTRING(truth) ") at " __FILE__ ":" RPMALLOC_TOSTRING(__LINE__)); \
            } else {                                                                                         \
                assert((truth) && message);                                                                  \
            }                                                                                                \
        }                                                                                                    \
    } while (0)
#else
#  define rpmalloc_assert(truth, message) do {} while(0)
#endif


#if defined(__GNUC__)
#define EXPECTED(x) __builtin_expect((x), 1)
#define UNEXPECTED(x) __builtin_expect((x), 0)
#else
#define EXPECTED(x) (x)
#define UNEXPECTED(x) (x)
#endif


///
/// Preconfigured limits and sizes
///

//! Granularity of a small allocation block (must be power of two)
#define SMALL_GRANULARITY         16
//! Small granularity shift count
#define SMALL_GRANULARITY_SHIFT   4
//! Number of small block size classes
#define SMALL_CLASS_COUNT         65
//! Maximum size of a small block
#define SMALL_SIZE_LIMIT          (SMALL_GRANULARITY * (SMALL_CLASS_COUNT - 1))
//! Granularity of a medium allocation block
#define MEDIUM_GRANULARITY        512
//! Medium granularity shift count
#define MEDIUM_GRANULARITY_SHIFT  9
//! Number of medium block size classes
#define MEDIUM_CLASS_COUNT        61
//! Total number of small + medium size classes
#define SIZE_CLASS_COUNT          (SMALL_CLASS_COUNT + MEDIUM_CLASS_COUNT)
//! Number of large block size classes
#define LARGE_CLASS_COUNT         63
//! Maximum size of a medium block
#define MEDIUM_SIZE_LIMIT         (SMALL_SIZE_LIMIT + (MEDIUM_GRANULARITY * MEDIUM_CLASS_COUNT))
//! Maximum size of a large block
#define LARGE_SIZE_LIMIT          ((LARGE_CLASS_COUNT * _memory_span_size) - SPAN_HEADER_SIZE)
//! Size of a span header (must be a multiple of SMALL_GRANULARITY and a power of two)
#define SPAN_HEADER_SIZE          128
//! Number of spans in thread cache
#define MAX_THREAD_SPAN_CACHE     400
//! Number of spans to transfer between thread and global cache
#define THREAD_SPAN_CACHE_TRANSFER 64
//! Number of spans in thread cache for large spans (must be greater than LARGE_CLASS_COUNT / 2)
#define MAX_THREAD_SPAN_LARGE_CACHE 100
//! Number of spans to transfer between thread and global cache for large spans
#define THREAD_SPAN_LARGE_CACHE_TRANSFER 6

#define pointer_offset(ptr, ofs) (void*)((char*)(ptr) + (ptrdiff_t)(ofs))
#define pointer_diff(first, second) (ptrdiff_t)((const char*)(first) - (const char*)(second))

#define SIZE_CLASS_LARGE SIZE_CLASS_COUNT
#define SIZE_CLASS_HUGE ((uint32_t)-1)

////////////
///
/// Data types
///
//////

//! A memory heap, per thread
typedef struct heap_t heap_t;
//! Span of memory pages
typedef struct span_t span_t;
//! Span list
typedef struct span_list_t span_list_t;
//! Span active data
typedef struct span_active_t span_active_t;
//! Size class definition
typedef struct size_class_t size_class_t;
//! Global cache
typedef struct global_cache_t global_cache_t;

//! Flag indicating span is the first (master) span of a split superspan
#define SPAN_FLAG_MASTER 1U
//! Flag indicating span is a secondary (sub) span of a split superspan
#define SPAN_FLAG_SUBSPAN 2U
//! Flag indicating span has blocks with increased alignment
#define SPAN_FLAG_ALIGNED_BLOCKS 4U
//! Flag indicating an unmapped master span
#define SPAN_FLAG_UNMAPPED_MASTER 8U

// A span can either represent a single span of memory pages with size declared by span_map_count configuration variable,
// or a set of spans in a continuous region, a super span. Any reference to the term "span" usually refers to both a single
// span or a super span. A super span can further be divided into multiple spans (or this, super spans), where the first
// (super)span is the master and subsequent (super)spans are subspans. The master span keeps track of how many subspans
// that are still alive and mapped in virtual memory, and once all subspans and master have been unmapped the entire
// superspan region is released and unmapped (on Windows for example, the entire superspan range has to be released
// in the same call to release the virtual memory range, but individual subranges can be decommitted individually
// to reduce physical memory use).
struct span_t {
    //! Free list
    void*       free_list;
    //! Total block count of size class
    uint32_t    block_count;
    //! Size class
    uint32_t    size_class;
    //! Index of last block initialized in free list
    uint32_t    free_list_limit;
    //! Number of used blocks remaining when in partial state
    uint32_t    used_count;
    //! Deferred free list
    void*       free_list_deferred;
    //! Size of deferred free list, or list of spans when part of a cache list
    uint32_t    list_size;
    //! Size of a block
    uint32_t    block_size;
    //! Flags and counters
    uint32_t    flags;
    //! Number of spans
    uint32_t    span_count;
    //! Total span counter for master spans
    uint32_t    total_spans;
    //! Offset from master span for subspans
    uint32_t    offset_from_master;
    //! Remaining span counter, for master spans
    int32_t  remaining_spans;
    //! Alignment offset
    uint32_t    align_offset;
    //! Owning heap
    heap_t*     heap;
    //! Next span
    span_t*     next;
    //! Previous span
    span_t*     prev;
};

struct span_cache_t {
    size_t       count;
    span_t*      span[MAX_THREAD_SPAN_CACHE];
};
typedef struct span_cache_t span_cache_t;

struct span_large_cache_t {
    size_t       count;
    span_t*      span[MAX_THREAD_SPAN_LARGE_CACHE];
};
typedef struct span_large_cache_t span_large_cache_t;

struct heap_size_class_t {
    //! Free list of active span
    void*        free_list;
    //! Double linked list of partially used spans with free blocks.
    //  Previous span pointer in head points to tail span of list.
    span_t*      partial_span;
    //! Early level cache of fully free spans
    span_t*      cache;
};
typedef struct heap_size_class_t heap_size_class_t;

// Control structure for a heap, either a thread heap or a first class heap if enabled
struct heap_t {
    //! Owning thread ID
    uintptr_t    owner_thread;
    //! Free lists for each size class
    heap_size_class_t size_class[SIZE_CLASS_COUNT];
    //! Arrays of fully freed spans, single span
    span_cache_t span_cache;
    //! List of deferred free spans (single linked list)
    void*        span_free_deferred;
    //! Number of full spans
    size_t       full_span_count;
    //! Mapped but unused spans
    span_t*      span_reserve;
    //! Master span for mapped but unused spans
    span_t*      span_reserve_master;
    //! Number of mapped but unused spans
    uint32_t     spans_reserved;
    //! Child count
    int32_t      child_count;
    //! Next heap in id list
    heap_t*      next_heap;
    //! Next heap in orphan list
    heap_t*      next_orphan;
    //! Heap ID
    int32_t      id;
    //! Finalization state flag
    int          finalize;
    //! Master heap owning the memory pages
    heap_t*      master_heap;
    //! Arrays of fully freed spans, large spans with > 1 span count
    span_large_cache_t span_large_cache[LARGE_CLASS_COUNT - 1];
};

// Size class for defining a block size bucket
struct size_class_t {
    //! Size of blocks in this class
    uint32_t block_size;
    //! Number of blocks in each chunk
    uint16_t block_count;
    //! Class index this class is merged with
    uint16_t class_idx;
};

struct global_cache_t {
    //! Cache lock
    int32_t lock;
    //! Cache count
    uint32_t count;
    //! Cached spans
    span_t* span[GLOBAL_CACHE_MULTIPLIER * MAX_THREAD_SPAN_CACHE];
    //! Unlimited cache overflow
    span_t* overflow;
};

////////////
///
/// Global data
///
//////

//! Default span size (64KiB)
#define _memory_default_span_size (64 * 1024)
#define _memory_default_span_size_shift 16
#define _memory_default_span_mask (~((uintptr_t)(_memory_span_size - 1)))

//! Initialized flag
static int _rpmalloc_initialized;
//! Configuration
static rpmalloc_config_t _memory_config;
//! Memory page size
static size_t _memory_page_size;
//! Shift to divide by page size
static size_t _memory_page_size_shift;
//! Granularity at which memory pages are mapped by OS
static size_t _memory_map_granularity;
//! Hardwired span size
#define _memory_span_size _memory_default_span_size
#define _memory_span_size_shift _memory_default_span_size_shift
#define _memory_span_mask _memory_default_span_mask
//! Number of spans to map in each map call
static size_t _memory_span_map_count;
//! Number of spans to keep reserved in each heap
static size_t _memory_heap_reserve_count;
//! Global size classes
static size_class_t _memory_size_class[SIZE_CLASS_COUNT];
//! Run-time size limit of medium blocks
static size_t _memory_medium_size_limit;
//! Heap ID counter
static int32_t _memory_heap_id;
//! Global reserved spans
static span_t* _memory_global_reserve;
//! Global reserved count
static size_t _memory_global_reserve_count;
//! Global reserved master
static span_t* _memory_global_reserve_master;
//! All heaps
static heap_t* _memory_heaps[HEAP_ARRAY_SIZE];
//! Orphaned heaps
static heap_t* _memory_orphan_heaps;

////////////
///
/// Thread local heap and ID
///
//////

//! Current thread heap
static heap_t* _memory_thread_heap;

//! Set the current thread heap
static void
set_thread_heap(heap_t* heap) {
    _memory_thread_heap = heap;
    if (heap)
        heap->owner_thread = 0;
}

////////////
///
/// Low level memory map/unmap
///
//////

//! Map more virtual memory
//  size is number of bytes to map
//  offset receives the offset in bytes from start of mapped region
//  returns address to start of mapped region to use
static void*
_rpmalloc_mmap(size_t size, size_t* offset) {
    rpmalloc_assert(!(size % _memory_page_size), "Invalid mmap size");
    rpmalloc_assert(size >= _memory_page_size, "Invalid mmap size");
    return _memory_config.memory_map(size, offset);
}

//! Unmap virtual memory
//  address is the memory address to unmap, as returned from _memory_map
//  size is the number of bytes to unmap, which might be less than full region for a partial unmap
//  offset is the offset in bytes to the actual mapped region, as set by _memory_map
//  release is set to 0 for partial unmap, or size of entire range for a full unmap
static void
_rpmalloc_unmap(void* address, size_t size, size_t offset, size_t release) {
    rpmalloc_assert(!release || (release >= size), "Invalid unmap size");
    rpmalloc_assert(!release || (release >= _memory_page_size), "Invalid unmap size");
    if (release) {
        rpmalloc_assert(!(release % _memory_page_size), "Invalid unmap size");
    }
    _memory_config.memory_unmap(address, size, offset, release);
}

//! Default implementation to map new pages to virtual memory
static void*
_rpmalloc_mmap_os(size_t size, size_t* offset) {
    //Either size is a heap (a single page) or a (multiple) span - we only need to align spans, and only if larger than map granularity
    size_t padding = ((size >= _memory_span_size) && (_memory_span_size > _memory_map_granularity)) ? _memory_span_size : 0;
    rpmalloc_assert(size >= _memory_page_size, "Invalid mmap size");
#if PLATFORM_WINDOWS
    //Ok to MEM_COMMIT - according to MSDN, "actual physical pages are not allocated unless/until the virtual addresses are actually accessed"
    void* ptr = VirtualAlloc(0, size + padding, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (!ptr) {
        if (_memory_config.map_fail_callback) {
            if (_memory_config.map_fail_callback(size + padding))
                return _rpmalloc_mmap_os(size, offset);
        } else {
            rpmalloc_assert(ptr, "Failed to map virtual memory block");
        }
        return 0;
    }
#else
    int flags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_UNINITIALIZED;
#  if defined(__APPLE__) && !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    int fd = (int)VM_MAKE_TAG(240U);
    void* ptr = mmap(0, size + padding, PROT_READ | PROT_WRITE, flags, fd, 0);
#  else
    void* ptr = mmap(0, size + padding, PROT_READ | PROT_WRITE, flags, -1, 0);
#  endif
    if ((ptr == MAP_FAILED) || !ptr) {
        if (_memory_config.map_fail_callback) {
            if (_memory_config.map_fail_callback(size + padding))
                return _rpmalloc_mmap_os(size, offset);
        } else if (errno != ENOMEM) {
            rpmalloc_assert((ptr != MAP_FAILED) && ptr, "Failed to map virtual memory block");
        }
        return 0;
    }
#endif
    if (padding) {
        size_t final_padding = padding - ((uintptr_t)ptr & ~_memory_span_mask);
        rpmalloc_assert(final_padding <= _memory_span_size, "Internal failure in padding");
        rpmalloc_assert(final_padding <= padding, "Internal failure in padding");
        rpmalloc_assert(!(final_padding % 8), "Internal failure in padding");
        ptr = pointer_offset(ptr, final_padding);
        *offset = final_padding >> 3;
    }
    rpmalloc_assert((size < _memory_span_size) || !((uintptr_t)ptr & ~_memory_span_mask), "Internal failure in padding");
    return ptr;
}

//! Default implementation to unmap pages from virtual memory
static void
_rpmalloc_unmap_os(void* address, size_t size, size_t offset, size_t release) {
    rpmalloc_assert(release || (offset == 0), "Invalid unmap size");
    rpmalloc_assert(!release || (release >= _memory_page_size), "Invalid unmap size");
    rpmalloc_assert(size >= _memory_page_size, "Invalid unmap size");
    if (release && offset) {
        offset <<= 3;
        address = pointer_offset(address, -(int32_t)offset);
        if ((release >= _memory_span_size) && (_memory_span_size > _memory_map_granularity)) {
            //Padding is always one span size
            release += _memory_span_size;
        }
    }
#if PLATFORM_WINDOWS
    if (!VirtualFree(address, release ? 0 : size, release ? MEM_RELEASE : MEM_DECOMMIT)) {
        rpmalloc_assert(0, "Failed to unmap virtual memory block");
    }
#else
    if (release) {
        if (munmap(address, release)) {
            rpmalloc_assert(0, "Failed to unmap virtual memory block");
        }
    } else {
#if defined(MADV_FREE_REUSABLE)
        int ret;
        while ((ret = madvise(address, size, MADV_FREE_REUSABLE)) == -1 && (errno == EAGAIN))
            errno = 0;
        if ((ret == -1) && (errno != 0)) {
#elif defined(MADV_DONTNEED)
        if (madvise(address, size, MADV_DONTNEED)) {
#elif defined(MADV_PAGEOUT)
        if (madvise(address, size, MADV_PAGEOUT)) {
#elif defined(MADV_FREE)
        if (madvise(address, size, MADV_FREE)) {
#else
        if (posix_madvise(address, size, POSIX_MADV_DONTNEED)) {
#endif
            rpmalloc_assert(0, "Failed to madvise virtual memory block as free");
        }
    }
#endif
}

static void
_rpmalloc_span_mark_as_subspan_unless_master(span_t* master, span_t* subspan, size_t span_count);

//! Use global reserved spans to fulfill a memory map request (reserve size must be checked by caller)
static span_t*
_rpmalloc_global_get_reserved_spans(size_t span_count) {
    span_t* span = _memory_global_reserve;
    _rpmalloc_span_mark_as_subspan_unless_master(_memory_global_reserve_master, span, span_count);
    _memory_global_reserve_count -= span_count;
    if (_memory_global_reserve_count)
        _memory_global_reserve = (span_t*)pointer_offset(span, span_count << _memory_span_size_shift);
    else
        _memory_global_reserve = 0;
    return span;
}

//! Store the given spans as global reserve (must only be called from within new heap allocation, not thread safe)
static void
_rpmalloc_global_set_reserved_spans(span_t* master, span_t* reserve, size_t reserve_span_count) {
    _memory_global_reserve_master = master;
    _memory_global_reserve_count = reserve_span_count;
    _memory_global_reserve = reserve;
}


////////////
///
/// Span linked list management
///
//////

//! Add a span to double linked list at the head
static void
_rpmalloc_span_double_link_list_add(span_t** head, span_t* span) {
    if (*head)
        (*head)->prev = span;
    span->next = *head;
    *head = span;
}

//! Pop head span from double linked list
static void
_rpmalloc_span_double_link_list_pop_head(span_t** head, span_t* span) {
    rpmalloc_assert(*head == span, "Linked list corrupted");
    span = *head;
    *head = span->next;
}

//! Remove a span from double linked list
static void
_rpmalloc_span_double_link_list_remove(span_t** head, span_t* span) {
    rpmalloc_assert(*head, "Linked list corrupted");
    if (*head == span) {
        *head = span->next;
    } else {
        span_t* next_span = span->next;
        span_t* prev_span = span->prev;
        prev_span->next = next_span;
        if (EXPECTED(next_span != 0))
            next_span->prev = prev_span;
    }
}


////////////
///
/// Span control
///
//////

static void
_rpmalloc_heap_cache_insert(heap_t* heap, span_t* span);

static void
_rpmalloc_heap_finalize(heap_t* heap);

static void
_rpmalloc_heap_set_reserved_spans(heap_t* heap, span_t* master, span_t* reserve, size_t reserve_span_count);

//! Declare the span to be a subspan and store distance from master span and span count
static void
_rpmalloc_span_mark_as_subspan_unless_master(span_t* master, span_t* subspan, size_t span_count) {
    rpmalloc_assert((subspan != master) || (subspan->flags & SPAN_FLAG_MASTER), "Span master pointer and/or flag mismatch");
    if (subspan != master) {
        subspan->flags = SPAN_FLAG_SUBSPAN;
        subspan->offset_from_master = (uint32_t)((uintptr_t)pointer_diff(subspan, master) >> _memory_span_size_shift);
        subspan->align_offset = 0;
    }
    subspan->span_count = (uint32_t)span_count;
}

//! Use reserved spans to fulfill a memory map request (reserve size must be checked by caller)
static span_t*
_rpmalloc_span_map_from_reserve(heap_t* heap, size_t span_count) {
    //Update the heap span reserve
    span_t* span = heap->span_reserve;
    heap->span_reserve = (span_t*)pointer_offset(span, span_count * _memory_span_size);
    heap->spans_reserved -= (uint32_t)span_count;

    _rpmalloc_span_mark_as_subspan_unless_master(heap->span_reserve_master, span, span_count);
    return span;
}

//! Get the aligned number of spans to map in based on wanted count, configured mapping granularity and the page size
static size_t
_rpmalloc_span_align_count(size_t span_count) {
    size_t request_count = (span_count > _memory_span_map_count) ? span_count : _memory_span_map_count;
    if ((_memory_page_size > _memory_span_size) && ((request_count * _memory_span_size) % _memory_page_size))
        request_count += _memory_span_map_count - (request_count % _memory_span_map_count);
    return request_count;
}

//! Setup a newly mapped span
static void
_rpmalloc_span_initialize(span_t* span, size_t total_span_count, size_t span_count, size_t align_offset) {
    span->total_spans = (uint32_t)total_span_count;
    span->span_count = (uint32_t)span_count;
    span->align_offset = (uint32_t)align_offset;
    span->flags = SPAN_FLAG_MASTER;
    span->remaining_spans = (int32_t)total_span_count;
}

static void
_rpmalloc_span_unmap(span_t* span);

//! Map an aligned set of spans, taking configured mapping granularity and the page size into account
static span_t*
_rpmalloc_span_map_aligned_count(heap_t* heap, size_t span_count) {
    //If we already have some, but not enough, reserved spans, release those to heap cache and map a new
    //full set of spans. Otherwise we would waste memory if page size > span size (huge pages)
    size_t aligned_span_count = _rpmalloc_span_align_count(span_count);
    size_t align_offset = 0;
    span_t* span = (span_t*)_rpmalloc_mmap(aligned_span_count * _memory_span_size, &align_offset);
    if (!span)
        return 0;
    _rpmalloc_span_initialize(span, aligned_span_count, span_count, align_offset);
    if (aligned_span_count > span_count) {
        span_t* reserved_spans = (span_t*)pointer_offset(span, span_count * _memory_span_size);
        size_t reserved_count = aligned_span_count - span_count;
        if (heap->spans_reserved) {
            _rpmalloc_span_mark_as_subspan_unless_master(heap->span_reserve_master, heap->span_reserve, heap->spans_reserved);
            _rpmalloc_heap_cache_insert(heap, heap->span_reserve);
        }
        if (reserved_count > _memory_heap_reserve_count) {
            size_t remain_count = reserved_count - _memory_heap_reserve_count;
            reserved_count = _memory_heap_reserve_count;
            span_t* remain_span = (span_t*)pointer_offset(reserved_spans, reserved_count * _memory_span_size);
            if (_memory_global_reserve) {
                _rpmalloc_span_mark_as_subspan_unless_master(_memory_global_reserve_master, _memory_global_reserve, _memory_global_reserve_count);
                _rpmalloc_span_unmap(_memory_global_reserve);
            }
            _rpmalloc_global_set_reserved_spans(span, remain_span, remain_count);
        }
        _rpmalloc_heap_set_reserved_spans(heap, span, reserved_spans, reserved_count);
    }
    return span;
}

//! Map in memory pages for the given number of spans (or use previously reserved pages)
static span_t*
_rpmalloc_span_map(heap_t* heap, size_t span_count) {
    if (span_count <= heap->spans_reserved)
        return _rpmalloc_span_map_from_reserve(heap, span_count);
    span_t* span = 0;
    int use_global_reserve = (_memory_page_size > _memory_span_size) || (_memory_span_map_count > _memory_heap_reserve_count);
    if (use_global_reserve) {
        if (_memory_global_reserve_count >= span_count) {
            size_t reserve_count = (!heap->spans_reserved ? _memory_heap_reserve_count : span_count);
            if (_memory_global_reserve_count < reserve_count)
                reserve_count = _memory_global_reserve_count;
            span = _rpmalloc_global_get_reserved_spans(reserve_count);
            if (span) {
                if (reserve_count > span_count) {
                    span_t* reserved_span = (span_t*)pointer_offset(span, span_count << _memory_span_size_shift);
                    _rpmalloc_heap_set_reserved_spans(heap, _memory_global_reserve_master, reserved_span, reserve_count - span_count);
                }
                // Already marked as subspan in _rpmalloc_global_get_reserved_spans
                span->span_count = (uint32_t)span_count;
            }
        }
    }
    if (!span)
        span = _rpmalloc_span_map_aligned_count(heap, span_count);
    return span;
}

//! Unmap memory pages for the given number of spans (or mark as unused if no partial unmappings)
static void
_rpmalloc_span_unmap(span_t* span) {
    rpmalloc_assert((span->flags & SPAN_FLAG_MASTER) || (span->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");
    rpmalloc_assert(!(span->flags & SPAN_FLAG_MASTER) || !(span->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");

    int is_master = !!(span->flags & SPAN_FLAG_MASTER);
    span_t* master = is_master ? span : ((span_t*)pointer_offset(span, -(intptr_t)((uintptr_t)span->offset_from_master * _memory_span_size)));
    rpmalloc_assert(is_master || (span->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");
    rpmalloc_assert(master->flags & SPAN_FLAG_MASTER, "Span flag corrupted");

    size_t span_count = span->span_count;
    if (!is_master) {
        //Directly unmap subspans (unless huge pages, in which case we defer and unmap entire page range with master)
        rpmalloc_assert(span->align_offset == 0, "Span align offset corrupted");
        if (_memory_span_size >= _memory_page_size)
            _rpmalloc_unmap(span, span_count * _memory_span_size, 0, 0);
    } else {
        //Special double flag to denote an unmapped master
        //It must be kept in memory since span header must be used
        span->flags |= SPAN_FLAG_MASTER | SPAN_FLAG_SUBSPAN | SPAN_FLAG_UNMAPPED_MASTER;
    }

    master->remaining_spans -= (int32_t)span_count;
    if (master->remaining_spans <= 0) {
        //Everything unmapped, unmap the master span with release flag to unmap the entire range of the super span
        rpmalloc_assert(!!(master->flags & SPAN_FLAG_MASTER) && !!(master->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");
        size_t unmap_count = master->span_count;
        if (_memory_span_size < _memory_page_size)
            unmap_count = master->total_spans;
        _rpmalloc_unmap(master, unmap_count * _memory_span_size, master->align_offset, (size_t)master->total_spans * _memory_span_size);
    }
}

//! Move the span (used for small or medium allocations) to the heap thread cache
static void
_rpmalloc_span_release_to_cache(heap_t* heap, span_t* span) {
    rpmalloc_assert(heap == span->heap, "Span heap pointer corrupted");
    rpmalloc_assert(span->size_class < SIZE_CLASS_COUNT, "Invalid span size class");
    rpmalloc_assert(span->span_count == 1, "Invalid span count");
    if (!heap->finalize) {
        if (heap->size_class[span->size_class].cache)
            _rpmalloc_heap_cache_insert(heap, heap->size_class[span->size_class].cache);
        heap->size_class[span->size_class].cache = span;
    } else {
        _rpmalloc_span_unmap(span);
    }
}

//! Initialize a (partial) free list up to next system memory page, while reserving the first block
//! as allocated, returning number of blocks in list
static uint32_t
free_list_partial_init(void** list, void** first_block, void* page_start, void* block_start, uint32_t block_count, uint32_t block_size) {
    rpmalloc_assert(block_count, "Internal failure");
    *first_block = block_start;
    if (block_count > 1) {
        void* free_block = pointer_offset(block_start, block_size);
        void* block_end = pointer_offset(block_start, (size_t)block_size * block_count);
        //If block size is less than half a memory page, bound init to next memory page boundary
        if (block_size < (_memory_page_size >> 1)) {
            void* page_end = pointer_offset(page_start, _memory_page_size);
            if (page_end < block_end)
                block_end = page_end;
        }
        *list = free_block;
        block_count = 2;
        void* next_block = pointer_offset(free_block, block_size);
        while (next_block < block_end) {
            *((void**)free_block) = next_block;
            free_block = next_block;
            ++block_count;
            next_block = pointer_offset(next_block, block_size);
        }
        *((void**)free_block) = 0;
    } else {
        *list = 0;
    }
    return block_count;
}

//! Initialize an unused span (from cache or mapped) to be new active span, putting the initial free list in heap class free list
static void*
_rpmalloc_span_initialize_new(heap_t* heap, heap_size_class_t* heap_size_class, span_t* span, uint32_t class_idx) {
    rpmalloc_assert(span->span_count == 1, "Internal failure");
    size_class_t* size_class = _memory_size_class + class_idx;
    span->size_class = class_idx;
    span->heap = heap;
    span->flags &= ~SPAN_FLAG_ALIGNED_BLOCKS;
    span->block_size = size_class->block_size;
    span->block_count = size_class->block_count;
    span->free_list = 0;
    span->list_size = 0;
    span->free_list_deferred = 0;

    //Setup free list. Only initialize one system page worth of free blocks in list
    void* block;
    span->free_list_limit = free_list_partial_init(&heap_size_class->free_list, &block,
        span, pointer_offset(span, SPAN_HEADER_SIZE), size_class->block_count, size_class->block_size);
    //Link span as partial if there remains blocks to be initialized as free list, or full if fully initialized
    if (span->free_list_limit < span->block_count) {
        _rpmalloc_span_double_link_list_add(&heap_size_class->partial_span, span);
        span->used_count = span->free_list_limit;
    } else {
        ++heap->full_span_count;
        span->used_count = span->block_count;
    }
    return block;
}

static void
_rpmalloc_span_extract_free_list_deferred(span_t* span) {
    // We need acquire semantics on the CAS operation since we are interested in the list size
    // Refer to _rpmalloc_deallocate_defer_small_or_medium for further comments on this dependency
    span->free_list = span->free_list_deferred;
    span->used_count -= span->list_size;
    span->list_size = 0;
    span->free_list_deferred = 0;
}

static int
_rpmalloc_span_is_fully_utilized(span_t* span) {
    rpmalloc_assert(span->free_list_limit <= span->block_count, "Span free list corrupted");
    return !span->free_list && (span->free_list_limit >= span->block_count);
}

static int
_rpmalloc_span_finalize(heap_t* heap, size_t iclass, span_t* span, span_t** list_head) {
    void* free_list = heap->size_class[iclass].free_list;
    span_t* class_span = (span_t*)((uintptr_t)free_list & _memory_span_mask);
    if (span == class_span) {
        // Adopt the heap class free list back into the span free list
        void* block = span->free_list;
        void* last_block = 0;
        while (block) {
            last_block = block;
            block = *((void**)block);
        }
        uint32_t free_count = 0;
        block = free_list;
        while (block) {
            ++free_count;
            block = *((void**)block);
        }
        if (last_block) {
            *((void**)last_block) = free_list;
        } else {
            span->free_list = free_list;
        }
        heap->size_class[iclass].free_list = 0;
        span->used_count -= free_count;
    }
    //If this assert triggers you have memory leaks
    rpmalloc_assert(span->list_size == span->used_count, "Memory leak detected");
    if (span->list_size == span->used_count) {
        // This function only used for spans in double linked lists
        if (list_head)
            _rpmalloc_span_double_link_list_remove(list_head, span);
        _rpmalloc_span_unmap(span);
        return 1;
    }
    return 0;
}


////////////
///
/// Heap control
///
//////

static void
_rpmalloc_deallocate_huge(span_t*);

//! Store the given spans as reserve in the given heap
static void
_rpmalloc_heap_set_reserved_spans(heap_t* heap, span_t* master, span_t* reserve, size_t reserve_span_count) {
    heap->span_reserve_master = master;
    heap->span_reserve = reserve;
    heap->spans_reserved = (uint32_t)reserve_span_count;
}

//! Adopt the deferred span cache list, optionally extracting the first single span for immediate re-use
static void
_rpmalloc_heap_cache_adopt_deferred(heap_t* heap, span_t** single_span) {
    span_t* span = (span_t*)((void*)heap->span_free_deferred);
    while (span) {
        span_t* next_span = (span_t*)span->free_list;
        rpmalloc_assert(span->heap == heap, "Span heap pointer corrupted");
        if (EXPECTED(span->size_class < SIZE_CLASS_COUNT)) {
            rpmalloc_assert(heap->full_span_count, "Heap span counter corrupted");
            --heap->full_span_count;
            if (single_span && !*single_span)
                *single_span = span;
            else
                _rpmalloc_heap_cache_insert(heap, span);
        } else {
            if (span->size_class == SIZE_CLASS_HUGE) {
                _rpmalloc_deallocate_huge(span);
            } else {
                rpmalloc_assert(span->size_class == SIZE_CLASS_LARGE, "Span size class invalid");
                rpmalloc_assert(heap->full_span_count, "Heap span counter corrupted");
                --heap->full_span_count;
                uint32_t idx = span->span_count - 1;
                if (!idx && single_span && !*single_span)
                    *single_span = span;
                else
                    _rpmalloc_heap_cache_insert(heap, span);
            }
        }
        span = next_span;
    }
}

static void
_rpmalloc_heap_unmap(heap_t* heap) {
    if (!heap->master_heap) {
        if ((heap->finalize > 1) && !heap->child_count) {
            span_t* span = (span_t*)((uintptr_t)heap & _memory_span_mask);
            _rpmalloc_span_unmap(span);
        }
    } else {
        heap->master_heap->child_count -= 1;
        if (heap->master_heap->child_count == 0) {
            _rpmalloc_heap_unmap(heap->master_heap);
        }
    }
}

static void
_rpmalloc_heap_global_finalize(heap_t* heap) {
    if (heap->finalize++ > 1) {
        --heap->finalize;
        return;
    }

    _rpmalloc_heap_finalize(heap);

    for (size_t iclass = 0; iclass < LARGE_CLASS_COUNT; ++iclass) {
        span_cache_t* span_cache;
        if (!iclass)
            span_cache = &heap->span_cache;
        else
            span_cache = (span_cache_t*)(heap->span_large_cache + (iclass - 1));
        for (size_t ispan = 0; ispan < span_cache->count; ++ispan)
            _rpmalloc_span_unmap(span_cache->span[ispan]);
        span_cache->count = 0;
    }

    if (heap->full_span_count) {
        --heap->finalize;
        return;
    }

    for (size_t iclass = 0; iclass < SIZE_CLASS_COUNT; ++iclass) {
        if (heap->size_class[iclass].free_list || heap->size_class[iclass].partial_span) {
            --heap->finalize;
            return;
        }
    }
    //Heap is now completely free, unmap and remove from heap list
    size_t list_idx = (size_t)heap->id % HEAP_ARRAY_SIZE;
    heap_t* list_heap = _memory_heaps[list_idx];
    if (list_heap == heap) {
        _memory_heaps[list_idx] = heap->next_heap;
    } else {
        while (list_heap->next_heap != heap)
            list_heap = list_heap->next_heap;
        list_heap->next_heap = heap->next_heap;
    }

    _rpmalloc_heap_unmap(heap);
}

//! Insert a single span into thread heap cache, releasing to global cache if overflow
static void
_rpmalloc_heap_cache_insert(heap_t* heap, span_t* span) {
    if (UNEXPECTED(heap->finalize != 0)) {
        _rpmalloc_span_unmap(span);
        _rpmalloc_heap_global_finalize(heap);
        return;
    }
    size_t span_count = span->span_count;
    if (span_count == 1) {
        span_cache_t* span_cache = &heap->span_cache;
        span_cache->span[span_cache->count++] = span;
        if (span_cache->count == MAX_THREAD_SPAN_CACHE) {
            const size_t remain_count = MAX_THREAD_SPAN_CACHE - THREAD_SPAN_CACHE_TRANSFER;
            for (size_t ispan = 0; ispan < THREAD_SPAN_CACHE_TRANSFER; ++ispan)
                _rpmalloc_span_unmap(span_cache->span[remain_count + ispan]);
            span_cache->count = remain_count;
        }
    } else {
        size_t cache_idx = span_count - 2;
        span_large_cache_t* span_cache = heap->span_large_cache + cache_idx;
        span_cache->span[span_cache->count++] = span;
        const size_t cache_limit = (MAX_THREAD_SPAN_LARGE_CACHE - (span_count >> 1));
        if (span_cache->count == cache_limit) {
            const size_t transfer_limit = 2 + (cache_limit >> 2);
            const size_t transfer_count = (THREAD_SPAN_LARGE_CACHE_TRANSFER <= transfer_limit ? THREAD_SPAN_LARGE_CACHE_TRANSFER : transfer_limit);
            const size_t remain_count = cache_limit - transfer_count;
            for (size_t ispan = 0; ispan < transfer_count; ++ispan)
                _rpmalloc_span_unmap(span_cache->span[remain_count + ispan]);
            span_cache->count = remain_count;
        }
    }
}

//! Extract the given number of spans from the different cache levels
static span_t*
_rpmalloc_heap_thread_cache_extract(heap_t* heap, size_t span_count) {
    span_t* span = 0;
    span_cache_t* span_cache;
    if (span_count == 1)
        span_cache = &heap->span_cache;
    else
        span_cache = (span_cache_t*)(heap->span_large_cache + (span_count - 2));
    if (span_cache->count) {
        return span_cache->span[--span_cache->count];
    }
    return span;
}

static span_t*
_rpmalloc_heap_thread_cache_deferred_extract(heap_t* heap, size_t span_count) {
    span_t* span = 0;
    if (span_count == 1) {
        _rpmalloc_heap_cache_adopt_deferred(heap, &span);
    } else {
        _rpmalloc_heap_cache_adopt_deferred(heap, 0);
        span = _rpmalloc_heap_thread_cache_extract(heap, span_count);
    }
    return span;
}

static span_t*
_rpmalloc_heap_reserved_extract(heap_t* heap, size_t span_count) {
    if (heap->spans_reserved >= span_count)
        return _rpmalloc_span_map(heap, span_count);
    return 0;
}

//! Extract a span from the global cache
static span_t*
_rpmalloc_heap_global_cache_extract(heap_t* heap, size_t span_count) {
    (void)sizeof(heap);
    (void)sizeof(span_count);
    return 0;
}

static void
_rpmalloc_inc_span_statistics(heap_t* heap, size_t span_count, uint32_t class_idx) {
    (void)sizeof(heap);
    (void)sizeof(span_count);
    (void)sizeof(class_idx);
}

//! Get a span from one of the cache levels (thread cache, reserved, global cache) or fallback to mapping more memory
static span_t*
_rpmalloc_heap_extract_new_span(heap_t* heap, heap_size_class_t* heap_size_class, size_t span_count, uint32_t class_idx) {
    span_t* span;
    if (heap_size_class && heap_size_class->cache) {
        span = heap_size_class->cache;
        heap_size_class->cache = (heap->span_cache.count ? heap->span_cache.span[--heap->span_cache.count] : 0);
        _rpmalloc_inc_span_statistics(heap, span_count, class_idx);
        return span;
    }
    (void)sizeof(class_idx);
    // Allow 50% overhead to increase cache hits
    size_t base_span_count = span_count;
    size_t limit_span_count = (span_count > 2) ? (span_count + (span_count >> 1)) : span_count;
    if (limit_span_count > LARGE_CLASS_COUNT)
        limit_span_count = LARGE_CLASS_COUNT;
    do {
        span = _rpmalloc_heap_thread_cache_extract(heap, span_count);
        if (EXPECTED(span != 0)) {
            _rpmalloc_inc_span_statistics(heap, span_count, class_idx);
            return span;
        }
        span = _rpmalloc_heap_thread_cache_deferred_extract(heap, span_count);
        if (EXPECTED(span != 0)) {
            _rpmalloc_inc_span_statistics(heap, span_count, class_idx);
            return span;
        }
        span = _rpmalloc_heap_reserved_extract(heap, span_count);
        if (EXPECTED(span != 0)) {
            _rpmalloc_inc_span_statistics(heap, span_count, class_idx);
            return span;
        }
        span = _rpmalloc_heap_global_cache_extract(heap, span_count);
        if (EXPECTED(span != 0)) {
            _rpmalloc_inc_span_statistics(heap, span_count, class_idx);
            return span;
        }
        ++span_count;
    } while (span_count <= limit_span_count);
    //Final fallback, map in more virtual memory
    span = _rpmalloc_span_map(heap, base_span_count);
    _rpmalloc_inc_span_statistics(heap, base_span_count, class_idx);
    return span;
}

static void
_rpmalloc_heap_initialize(heap_t* heap) {
    memset(heap, 0, sizeof(heap_t));
    //Get a new heap ID
    _memory_heap_id += 1;
    heap->id = _memory_heap_id + 1;

    //Link in heap in heap ID map
    size_t list_idx = (size_t)heap->id % HEAP_ARRAY_SIZE;
    heap->next_heap = _memory_heaps[list_idx];
    _memory_heaps[list_idx] = heap;
}

static void
_rpmalloc_heap_orphan(heap_t* heap, int first_class) {
    heap->owner_thread = (uintptr_t)-1;
    (void)sizeof(first_class);
    heap_t** heap_list = &_memory_orphan_heaps;
    heap->next_orphan = *heap_list;
    *heap_list = heap;
}

//! Allocate a new heap from newly mapped memory pages
static heap_t*
_rpmalloc_heap_allocate_new(void) {
    // Map in pages for a 16 heaps. If page size is greater than required size for this, map a page and
    // use first part for heaps and remaining part for spans for allocations. Adds a lot of complexity,
    // but saves a lot of memory on systems where page size > 64 spans (4MiB)
    size_t heap_size = sizeof(heap_t);
    size_t aligned_heap_size = 16 * ((heap_size + 15) / 16);
    size_t request_heap_count = 16;
    size_t heap_span_count = ((aligned_heap_size * request_heap_count) + sizeof(span_t) + _memory_span_size - 1) / _memory_span_size;
    size_t block_size = _memory_span_size * heap_span_count;
    size_t span_count = heap_span_count;
    span_t* span = 0;
    // If there are global reserved spans, use these first
    if (_memory_global_reserve_count >= heap_span_count) {
        span = _rpmalloc_global_get_reserved_spans(heap_span_count);
    }
    if (!span) {
        if (_memory_page_size > block_size) {
            span_count = _memory_page_size / _memory_span_size;
            block_size = _memory_page_size;
            // If using huge pages, make sure to grab enough heaps to avoid reallocating a huge page just to serve new heaps
            size_t possible_heap_count = (block_size - sizeof(span_t)) / aligned_heap_size;
            if (possible_heap_count >= (request_heap_count * 16))
                request_heap_count *= 16;
            else if (possible_heap_count < request_heap_count)
                request_heap_count = possible_heap_count;
            heap_span_count = ((aligned_heap_size * request_heap_count) + sizeof(span_t) + _memory_span_size - 1) / _memory_span_size;
        }

        size_t align_offset = 0;
        span = (span_t*)_rpmalloc_mmap(block_size, &align_offset);
        if (!span)
            return 0;

        // Master span will contain the heaps
        _rpmalloc_span_initialize(span, span_count, heap_span_count, align_offset);
    }

    size_t remain_size = _memory_span_size - sizeof(span_t);
    heap_t* heap = (heap_t*)pointer_offset(span, sizeof(span_t));
    _rpmalloc_heap_initialize(heap);

    // Put extra heaps as orphans
    size_t num_heaps = remain_size / aligned_heap_size;
    if (num_heaps < request_heap_count)
        num_heaps = request_heap_count;
    heap->child_count = (int32_t)num_heaps - 1;
    heap_t* extra_heap = (heap_t*)pointer_offset(heap, aligned_heap_size);
    while (num_heaps > 1) {
        _rpmalloc_heap_initialize(extra_heap);
        extra_heap->master_heap = heap;
        _rpmalloc_heap_orphan(extra_heap, 1);
        extra_heap = (heap_t*)pointer_offset(extra_heap, aligned_heap_size);
        --num_heaps;
    }

    if (span_count > heap_span_count) {
        // Cap reserved spans
        size_t remain_count = span_count - heap_span_count;
        size_t reserve_count = (remain_count > _memory_heap_reserve_count ? _memory_heap_reserve_count : remain_count);
        span_t* remain_span = (span_t*)pointer_offset(span, heap_span_count * _memory_span_size);
        _rpmalloc_heap_set_reserved_spans(heap, span, remain_span, reserve_count);

        if (remain_count > reserve_count) {
            // Set to global reserved spans
            remain_span = (span_t*)pointer_offset(remain_span, reserve_count * _memory_span_size);
            reserve_count = remain_count - reserve_count;
            _rpmalloc_global_set_reserved_spans(span, remain_span, reserve_count);
        }
    }

    return heap;
}

static heap_t*
_rpmalloc_heap_extract_orphan(heap_t** heap_list) {
    heap_t* heap = *heap_list;
    *heap_list = (heap ? heap->next_orphan : 0);
    return heap;
}

//! Allocate a new heap, potentially reusing a previously orphaned heap
static heap_t*
_rpmalloc_heap_allocate(int first_class) {
    heap_t* heap = 0;
    if (first_class == 0)
        heap = _rpmalloc_heap_extract_orphan(&_memory_orphan_heaps);
    if (!heap)
        heap = _rpmalloc_heap_allocate_new();
    _rpmalloc_heap_cache_adopt_deferred(heap, 0);
    return heap;
}

static void
_rpmalloc_heap_release(void* heapptr, int first_class, int release_cache) {
    heap_t* heap = (heap_t*)heapptr;
    if (!heap)
        return;
    //Release thread cache spans back to global cache
    _rpmalloc_heap_cache_adopt_deferred(heap, 0);
    if (release_cache  || heap->finalize) {
        for (size_t iclass = 0; iclass < LARGE_CLASS_COUNT; ++iclass) {
            span_cache_t* span_cache;
            if (!iclass)
                span_cache = &heap->span_cache;
            else
                span_cache = (span_cache_t*)(heap->span_large_cache + (iclass - 1));
            if (!span_cache->count)
                continue;
            for (size_t ispan = 0; ispan < span_cache->count; ++ispan)
                _rpmalloc_span_unmap(span_cache->span[ispan]);
            span_cache->count = 0;
        }
    }

    if (_memory_thread_heap == heap)
        set_thread_heap(0);

    _rpmalloc_heap_orphan(heap, first_class);
}

static void
_rpmalloc_heap_release_raw(void* heapptr, int release_cache) {
    _rpmalloc_heap_release(heapptr, 0, release_cache);
}

static void
_rpmalloc_heap_finalize(heap_t* heap) {
    if (heap->spans_reserved) {
        span_t* span = _rpmalloc_span_map(heap, heap->spans_reserved);
        _rpmalloc_span_unmap(span);
        heap->spans_reserved = 0;
    }

    _rpmalloc_heap_cache_adopt_deferred(heap, 0);

    for (size_t iclass = 0; iclass < SIZE_CLASS_COUNT; ++iclass) {
        if (heap->size_class[iclass].cache)
            _rpmalloc_span_unmap(heap->size_class[iclass].cache);
        heap->size_class[iclass].cache = 0;
        span_t* span = heap->size_class[iclass].partial_span;
        while (span) {
            span_t* next = span->next;
            _rpmalloc_span_finalize(heap, iclass, span, &heap->size_class[iclass].partial_span);
            span = next;
        }
        // If class still has a free list it must be a full span
        if (heap->size_class[iclass].free_list) {
            span_t* class_span = (span_t*)((uintptr_t)heap->size_class[iclass].free_list & _memory_span_mask);
            span_t** list = 0;
            --heap->full_span_count;
            if (!_rpmalloc_span_finalize(heap, iclass, class_span, list)) {
                if (list)
                    _rpmalloc_span_double_link_list_remove(list, class_span);
                _rpmalloc_span_double_link_list_add(&heap->size_class[iclass].partial_span, class_span);
            }
        }
    }

    for (size_t iclass = 0; iclass < LARGE_CLASS_COUNT; ++iclass) {
        span_cache_t* span_cache;
        if (!iclass)
            span_cache = &heap->span_cache;
        else
            span_cache = (span_cache_t*)(heap->span_large_cache + (iclass - 1));
        for (size_t ispan = 0; ispan < span_cache->count; ++ispan)
            _rpmalloc_span_unmap(span_cache->span[ispan]);
        span_cache->count = 0;
    }
    rpmalloc_assert(!heap->span_free_deferred, "Heaps still active during finalization");
}


////////////
///
/// Allocation entry points
///
//////

//! Pop first block from a free list
static void*
free_list_pop(void** list) {
    void* block = *list;
    *list = *((void**)block);
    return block;
}

//! Allocate a small/medium sized memory block from the given heap
static void*
_rpmalloc_allocate_from_heap_fallback(heap_t* heap, heap_size_class_t* heap_size_class, uint32_t class_idx) {
    span_t* span = heap_size_class->partial_span;
    if (EXPECTED(span != 0)) {
        rpmalloc_assert(span->block_count == _memory_size_class[span->size_class].block_count, "Span block count corrupted");
        rpmalloc_assert(!_rpmalloc_span_is_fully_utilized(span), "Internal failure");
        void* block;
        if (span->free_list) {
            //Span local free list is not empty, swap to size class free list
            block = free_list_pop(&span->free_list);
            heap_size_class->free_list = span->free_list;
            span->free_list = 0;
        } else {
            //If the span did not fully initialize free list, link up another page worth of blocks
            void* block_start = pointer_offset(span, SPAN_HEADER_SIZE + ((size_t)span->free_list_limit * span->block_size));
            span->free_list_limit += free_list_partial_init(&heap_size_class->free_list, &block,
                (void*)((uintptr_t)block_start & ~(_memory_page_size - 1)), block_start,
                span->block_count - span->free_list_limit, span->block_size);
        }
        rpmalloc_assert(span->free_list_limit <= span->block_count, "Span block count corrupted");
        span->used_count = span->free_list_limit;

        //Swap in deferred free list if present
        if (span->free_list_deferred)
            _rpmalloc_span_extract_free_list_deferred(span);

        //If span is still not fully utilized keep it in partial list and early return block
        if (!_rpmalloc_span_is_fully_utilized(span))
            return block;

        //The span is fully utilized, unlink from partial list and add to fully utilized list
        _rpmalloc_span_double_link_list_pop_head(&heap_size_class->partial_span, span);
        ++heap->full_span_count;
        return block;
    }

    //Find a span in one of the cache levels
    span = _rpmalloc_heap_extract_new_span(heap, heap_size_class, 1, class_idx);
    if (EXPECTED(span != 0)) {
        //Mark span as owned by this heap and set base data, return first block
        return _rpmalloc_span_initialize_new(heap, heap_size_class, span, class_idx);
    }

    return 0;
}

//! Allocate a small sized memory block from the given heap
static void*
_rpmalloc_allocate_small(heap_t* heap, size_t size) {
    rpmalloc_assert(heap, "No thread heap");
    //Small sizes have unique size classes
    const uint32_t class_idx = (uint32_t)((size + (SMALL_GRANULARITY - 1)) >> SMALL_GRANULARITY_SHIFT);
    heap_size_class_t* heap_size_class = heap->size_class + class_idx;
    if (EXPECTED(heap_size_class->free_list != 0))
        return free_list_pop(&heap_size_class->free_list);
    return _rpmalloc_allocate_from_heap_fallback(heap, heap_size_class, class_idx);
}

//! Allocate a medium sized memory block from the given heap
static void*
_rpmalloc_allocate_medium(heap_t* heap, size_t size) {
    rpmalloc_assert(heap, "No thread heap");
    //Calculate the size class index and do a dependent lookup of the final class index (in case of merged classes)
    const uint32_t base_idx = (uint32_t)(SMALL_CLASS_COUNT + ((size - (SMALL_SIZE_LIMIT + 1)) >> MEDIUM_GRANULARITY_SHIFT));
    const uint32_t class_idx = _memory_size_class[base_idx].class_idx;
    heap_size_class_t* heap_size_class = heap->size_class + class_idx;
    if (EXPECTED(heap_size_class->free_list != 0))
        return free_list_pop(&heap_size_class->free_list);
    return _rpmalloc_allocate_from_heap_fallback(heap, heap_size_class, class_idx);
}

//! Allocate a large sized memory block from the given heap
static void*
_rpmalloc_allocate_large(heap_t* heap, size_t size) {
    rpmalloc_assert(heap, "No thread heap");
    //Calculate number of needed max sized spans (including header)
    //Since this function is never called if size > LARGE_SIZE_LIMIT
    //the span_count is guaranteed to be <= LARGE_CLASS_COUNT
    size += SPAN_HEADER_SIZE;
    size_t span_count = size >> _memory_span_size_shift;
    if (size & (_memory_span_size - 1))
        ++span_count;

    //Find a span in one of the cache levels
    span_t* span = _rpmalloc_heap_extract_new_span(heap, 0, span_count, SIZE_CLASS_LARGE);
    if (!span)
        return span;

    //Mark span as owned by this heap and set base data
    rpmalloc_assert(span->span_count >= span_count, "Internal failure");
    span->size_class = SIZE_CLASS_LARGE;
    span->heap = heap;
    ++heap->full_span_count;

    return pointer_offset(span, SPAN_HEADER_SIZE);
}

//! Allocate a huge block by mapping memory pages directly
static void*
_rpmalloc_allocate_huge(heap_t* heap, size_t size) {
    rpmalloc_assert(heap, "No thread heap");
    _rpmalloc_heap_cache_adopt_deferred(heap, 0);
    size += SPAN_HEADER_SIZE;
    size_t num_pages = size >> _memory_page_size_shift;
    if (size & (_memory_page_size - 1))
        ++num_pages;
    size_t align_offset = 0;
    span_t* span = (span_t*)_rpmalloc_mmap(num_pages * _memory_page_size, &align_offset);
    if (!span)
        return span;

    //Store page count in span_count
    span->size_class = SIZE_CLASS_HUGE;
    span->span_count = (uint32_t)num_pages;
    span->align_offset = (uint32_t)align_offset;
    span->heap = heap;
    ++heap->full_span_count;

    return pointer_offset(span, SPAN_HEADER_SIZE);
}

//! Allocate a block of the given size
static void*
_rpmalloc_allocate(heap_t* heap, size_t size) {
    if (EXPECTED(size <= SMALL_SIZE_LIMIT))
        return _rpmalloc_allocate_small(heap, size);
    else if (size <= _memory_medium_size_limit)
        return _rpmalloc_allocate_medium(heap, size);
    else if (size <= LARGE_SIZE_LIMIT)
        return _rpmalloc_allocate_large(heap, size);
    return _rpmalloc_allocate_huge(heap, size);
}

static void*
_rpmalloc_aligned_allocate(heap_t* heap, size_t alignment, size_t size) {
    if (alignment <= SMALL_GRANULARITY)
        return _rpmalloc_allocate(heap, size);

    if ((alignment <= SPAN_HEADER_SIZE) && (size < _memory_medium_size_limit)) {
        // If alignment is less or equal to span header size (which is power of two),
        // and size aligned to span header size multiples is less than size + alignment,
        // then use natural alignment of blocks to provide alignment
        size_t multiple_size = size ? (size + (SPAN_HEADER_SIZE - 1)) & ~(uintptr_t)(SPAN_HEADER_SIZE - 1) : SPAN_HEADER_SIZE;
        rpmalloc_assert(!(multiple_size % SPAN_HEADER_SIZE), "Failed alignment calculation");
        if (multiple_size <= (size + alignment))
            return _rpmalloc_allocate(heap, multiple_size);
    }

    void* ptr = 0;
    size_t align_mask = alignment - 1;
    if (alignment <= _memory_page_size) {
        ptr = _rpmalloc_allocate(heap, size + alignment);
        if ((uintptr_t)ptr & align_mask) {
            ptr = (void*)(((uintptr_t)ptr & ~(uintptr_t)align_mask) + alignment);
            //Mark as having aligned blocks
            span_t* span = (span_t*)((uintptr_t)ptr & _memory_span_mask);
            span->flags |= SPAN_FLAG_ALIGNED_BLOCKS;
        }
        return ptr;
    }

    // Fallback to mapping new pages for this request. Since pointers passed
    // to rpfree must be able to reach the start of the span by bitmasking of
    // the address with the span size, the returned aligned pointer from this
    // function must be with a span size of the start of the mapped area.
    // In worst case this requires us to loop and map pages until we get a
    // suitable memory address. It also means we can never align to span size
    // or greater, since the span header will push alignment more than one
    // span size away from span start (thus causing pointer mask to give us
    // an invalid span start on free)
    if (alignment & align_mask) {
        errno = EINVAL;
        return 0;
    }
    if (alignment >= _memory_span_size) {
        errno = EINVAL;
        return 0;
    }

    size_t extra_pages = alignment / _memory_page_size;

    // Since each span has a header, we will at least need one extra memory page
    size_t num_pages = 1 + (size / _memory_page_size);
    if (size & (_memory_page_size - 1))
        ++num_pages;

    if (extra_pages > num_pages)
        num_pages = 1 + extra_pages;

    size_t original_pages = num_pages;
    size_t limit_pages = (_memory_span_size / _memory_page_size) * 2;
    if (limit_pages < (original_pages * 2))
        limit_pages = original_pages * 2;

    size_t mapped_size, align_offset;
    span_t* span;

retry:
    align_offset = 0;
    mapped_size = num_pages * _memory_page_size;

    span = (span_t*)_rpmalloc_mmap(mapped_size, &align_offset);
    if (!span) {
        errno = ENOMEM;
        return 0;
    }
    ptr = pointer_offset(span, SPAN_HEADER_SIZE);

    if ((uintptr_t)ptr & align_mask)
        ptr = (void*)(((uintptr_t)ptr & ~(uintptr_t)align_mask) + alignment);

    if (((size_t)pointer_diff(ptr, span) >= _memory_span_size) ||
        (pointer_offset(ptr, size) > pointer_offset(span, mapped_size)) ||
        (((uintptr_t)ptr & _memory_span_mask) != (uintptr_t)span)) {
        _rpmalloc_unmap(span, mapped_size, align_offset, mapped_size);
        ++num_pages;
        if (num_pages > limit_pages) {
            errno = EINVAL;
            return 0;
        }
        goto retry;
    }

    //Store page count in span_count
    span->size_class = SIZE_CLASS_HUGE;
    span->span_count = (uint32_t)num_pages;
    span->align_offset = (uint32_t)align_offset;
    span->heap = heap;
    ++heap->full_span_count;

    return ptr;
}


////////////
///
/// Deallocation entry points
///
//////

//! Deallocate the given small/medium memory block in the current thread local heap
static void
_rpmalloc_deallocate_direct_small_or_medium(span_t* span, void* block) {
    heap_t* heap = span->heap;
    //Add block to free list
    if (UNEXPECTED(_rpmalloc_span_is_fully_utilized(span))) {
        span->used_count = span->block_count;
        _rpmalloc_span_double_link_list_add(&heap->size_class[span->size_class].partial_span, span);
        --heap->full_span_count;
    }
    *((void**)block) = span->free_list;
    --span->used_count;
    span->free_list = block;
    if (UNEXPECTED(span->used_count == span->list_size)) {
        _rpmalloc_span_double_link_list_remove(&heap->size_class[span->size_class].partial_span, span);
        _rpmalloc_span_release_to_cache(heap, span);
    }
}

static void
_rpmalloc_deallocate_small_or_medium(span_t* span, void* p) {
    if (span->flags & SPAN_FLAG_ALIGNED_BLOCKS) {
        //Realign pointer to block start
        void* blocks_start = pointer_offset(span, SPAN_HEADER_SIZE);
        uint32_t block_offset = (uint32_t)pointer_diff(p, blocks_start);
        p = pointer_offset(p, -(int32_t)(block_offset % span->block_size));
    }
    _rpmalloc_deallocate_direct_small_or_medium(span, p);
}

//! Deallocate the given large memory block to the current heap
static void
_rpmalloc_deallocate_large(span_t* span) {
    rpmalloc_assert(span->size_class == SIZE_CLASS_LARGE, "Bad span size class");
    rpmalloc_assert(!(span->flags & SPAN_FLAG_MASTER) || !(span->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");
    rpmalloc_assert((span->flags & SPAN_FLAG_MASTER) || (span->flags & SPAN_FLAG_SUBSPAN), "Span flag corrupted");
    rpmalloc_assert(span->heap->full_span_count, "Heap span counter corrupted");
    --span->heap->full_span_count;
    heap_t* heap = span->heap;
    rpmalloc_assert(heap, "No thread heap");
    const int set_as_reserved = ((span->span_count > 1) && (heap->span_cache.count == 0) && !heap->finalize && !heap->spans_reserved);
    if (set_as_reserved) {
        heap->span_reserve = span;
        heap->spans_reserved = span->span_count;
        if (span->flags & SPAN_FLAG_MASTER) {
            heap->span_reserve_master = span;
        } else { //SPAN_FLAG_SUBSPAN
            span_t* master = (span_t*)pointer_offset(span, -(intptr_t)((size_t)span->offset_from_master * _memory_span_size));
            heap->span_reserve_master = master;
            rpmalloc_assert(master->flags & SPAN_FLAG_MASTER, "Span flag corrupted");
            rpmalloc_assert(master->remaining_spans >= (int32_t)span->span_count, "Master span count corrupted");
        }
    } else {
        //Insert into cache list
        _rpmalloc_heap_cache_insert(heap, span);
    }
}

//! Deallocate the given huge span
static void
_rpmalloc_deallocate_huge(span_t* span) {
    rpmalloc_assert(span->heap, "No span heap");
    rpmalloc_assert(span->heap->full_span_count, "Heap span counter corrupted");
    --span->heap->full_span_count;

    //Oversized allocation, page count is stored in span_count
    size_t num_pages = span->span_count;
    _rpmalloc_unmap(span, num_pages * _memory_page_size, span->align_offset, num_pages * _memory_page_size);
}

//! Deallocate the given block
static void
_rpmalloc_deallocate(void* p) {
    //Grab the span (always at start of span, using span alignment)
    span_t* span = (span_t*)((uintptr_t)p & _memory_span_mask);
    if (UNEXPECTED(!span))
        return;
    if (EXPECTED(span->size_class < SIZE_CLASS_COUNT))
        _rpmalloc_deallocate_small_or_medium(span, p);
    else if (span->size_class == SIZE_CLASS_LARGE)
        _rpmalloc_deallocate_large(span);
    else
        _rpmalloc_deallocate_huge(span);
}

////////////
///
/// Reallocation entry points
///
//////

static size_t
_rpmalloc_usable_size(void* p);

//! Reallocate the given block to the given size
static void*
_rpmalloc_reallocate(heap_t* heap, void* p, size_t size, size_t oldsize, unsigned int flags) {
    if (p) {
        //Grab the span using guaranteed span alignment
        span_t* span = (span_t*)((uintptr_t)p & _memory_span_mask);
        if (EXPECTED(span->size_class < SIZE_CLASS_COUNT)) {
            //Small/medium sized block
            rpmalloc_assert(span->span_count == 1, "Span counter corrupted");
            void* blocks_start = pointer_offset(span, SPAN_HEADER_SIZE);
            uint32_t block_offset = (uint32_t)pointer_diff(p, blocks_start);
            uint32_t block_idx = block_offset / span->block_size;
            void* block = pointer_offset(blocks_start, (size_t)block_idx * span->block_size);
            if (!oldsize)
                oldsize = (size_t)((ptrdiff_t)span->block_size - pointer_diff(p, block));
            if ((size_t)span->block_size >= size) {
                //Still fits in block, never mind trying to save memory, but preserve data if alignment changed
                if ((p != block) && !(flags & RPMALLOC_NO_PRESERVE))
                    memmove(block, p, oldsize);
                return block;
            }
        } else if (span->size_class == SIZE_CLASS_LARGE) {
            //Large block
            size_t total_size = size + SPAN_HEADER_SIZE;
            size_t num_spans = total_size >> _memory_span_size_shift;
            if (total_size & (_memory_span_mask - 1))
                ++num_spans;
            size_t current_spans = span->span_count;
            void* block = pointer_offset(span, SPAN_HEADER_SIZE);
            if (!oldsize)
                oldsize = (current_spans * _memory_span_size) - (size_t)pointer_diff(p, block) - SPAN_HEADER_SIZE;
            if ((current_spans >= num_spans) && (total_size >= (oldsize / 2))) {
                //Still fits in block, never mind trying to save memory, but preserve data if alignment changed
                if ((p != block) && !(flags & RPMALLOC_NO_PRESERVE))
                    memmove(block, p, oldsize);
                return block;
            }
        } else {
            //Oversized block
            size_t total_size = size + SPAN_HEADER_SIZE;
            size_t num_pages = total_size >> _memory_page_size_shift;
            if (total_size & (_memory_page_size - 1))
                ++num_pages;
            //Page count is stored in span_count
            size_t current_pages = span->span_count;
            void* block = pointer_offset(span, SPAN_HEADER_SIZE);
            if (!oldsize)
                oldsize = (current_pages * _memory_page_size) - (size_t)pointer_diff(p, block) - SPAN_HEADER_SIZE;
            if ((current_pages >= num_pages) && (num_pages >= (current_pages / 2))) {
                //Still fits in block, never mind trying to save memory, but preserve data if alignment changed
                if ((p != block) && !(flags & RPMALLOC_NO_PRESERVE))
                    memmove(block, p, oldsize);
                return block;
            }
        }
    } else {
        oldsize = 0;
    }

    if (!!(flags & RPMALLOC_GROW_OR_FAIL))
        return 0;

    //Size is greater than block size, need to allocate a new block and deallocate the old
    //Avoid hysteresis by overallocating if increase is small (below 37%)
    size_t lower_bound = oldsize + (oldsize >> 2) + (oldsize >> 3);
    size_t new_size = (size > lower_bound) ? size : ((size > oldsize) ? lower_bound : size);
    void* block = _rpmalloc_allocate(heap, new_size);
    if (p && block) {
        if (!(flags & RPMALLOC_NO_PRESERVE))
            memcpy(block, p, oldsize < new_size ? oldsize : new_size);
        _rpmalloc_deallocate(p);
    }

    return block;
}

static void*
_rpmalloc_aligned_reallocate(heap_t* heap, void* ptr, size_t alignment, size_t size, size_t oldsize,
                           unsigned int flags) {
    if (alignment <= SMALL_GRANULARITY)
        return _rpmalloc_reallocate(heap, ptr, size, oldsize, flags);

    int no_alloc = !!(flags & RPMALLOC_GROW_OR_FAIL);
    size_t usablesize = (ptr ? _rpmalloc_usable_size(ptr) : 0);
    if ((usablesize >= size) && !((uintptr_t)ptr & (alignment - 1))) {
        if (no_alloc || (size >= (usablesize / 2)))
            return ptr;
    }
    // Aligned alloc marks span as having aligned blocks
    void* block = (!no_alloc ? _rpmalloc_aligned_allocate(heap, alignment, size) : 0);
    if (EXPECTED(block != 0)) {
        if (!(flags & RPMALLOC_NO_PRESERVE) && ptr) {
            if (!oldsize)
                oldsize = usablesize;
            memcpy(block, ptr, oldsize < size ? oldsize : size);
        }
        _rpmalloc_deallocate(ptr);
    }
    return block;
}


////////////
///
/// Initialization, finalization and utility
///
//////

//! Get the usable size of the given block
static size_t
_rpmalloc_usable_size(void* p) {
    //Grab the span using guaranteed span alignment
    span_t* span = (span_t*)((uintptr_t)p & _memory_span_mask);
    if (span->size_class < SIZE_CLASS_COUNT) {
        //Small/medium block
        void* blocks_start = pointer_offset(span, SPAN_HEADER_SIZE);
        return span->block_size - ((size_t)pointer_diff(p, blocks_start) % span->block_size);
    }
    if (span->size_class == SIZE_CLASS_LARGE) {
        //Large block
        size_t current_spans = span->span_count;
        return (current_spans * _memory_span_size) - (size_t)pointer_diff(p, span);
    }
    //Oversized block, page count is stored in span_count
    size_t current_pages = span->span_count;
    return (current_pages * _memory_page_size) - (size_t)pointer_diff(p, span);
}

//! Adjust and optimize the size class properties for the given class
static void
_rpmalloc_adjust_size_class(size_t iclass) {
    size_t block_size = _memory_size_class[iclass].block_size;
    size_t block_count = (_memory_span_size - SPAN_HEADER_SIZE) / block_size;

    _memory_size_class[iclass].block_count = (uint16_t)block_count;
    _memory_size_class[iclass].class_idx = (uint16_t)iclass;

    //Check if previous size classes can be merged
    if (iclass >= SMALL_CLASS_COUNT) {
        size_t prevclass = iclass;
        while (prevclass > 0) {
            --prevclass;
            //A class can be merged if number of pages and number of blocks are equal
            if (_memory_size_class[prevclass].block_count == _memory_size_class[iclass].block_count)
                memcpy(_memory_size_class + prevclass, _memory_size_class + iclass, sizeof(_memory_size_class[iclass]));
            else
                break;
        }
    }
}

//! Initialize the allocator and setup global data
int
rpmalloc_initialize(void) {
    if (_rpmalloc_initialized) {
        rpmalloc_thread_initialize();
        return 0;
    }
    return rpmalloc_initialize_config(0);
}

int
rpmalloc_initialize_config(const rpmalloc_config_t* config) {
    if (_rpmalloc_initialized) {
        rpmalloc_thread_initialize();
        return 0;
    }
    _rpmalloc_initialized = 1;

    if (config)
        memcpy(&_memory_config, config, sizeof(rpmalloc_config_t));
    else
        memset(&_memory_config, 0, sizeof(rpmalloc_config_t));

    if (!_memory_config.memory_map || !_memory_config.memory_unmap) {
        _memory_config.memory_map = _rpmalloc_mmap_os;
        _memory_config.memory_unmap = _rpmalloc_unmap_os;
    }

#if PLATFORM_WINDOWS
    SYSTEM_INFO system_info;
    memset(&system_info, 0, sizeof(system_info));
    GetSystemInfo(&system_info);
    _memory_map_granularity = system_info.dwAllocationGranularity;
#else
    _memory_map_granularity = (size_t)sysconf(_SC_PAGESIZE);
#endif

    _memory_page_size = 0;
    if (!_memory_page_size) {
#if PLATFORM_WINDOWS
        _memory_page_size = system_info.dwPageSize;
#else
        _memory_page_size = _memory_map_granularity;
#endif
    }

    size_t min_span_size = 256;
    size_t max_page_size;
#if UINTPTR_MAX > 0xFFFFFFFF
    max_page_size = 4096ULL * 1024ULL * 1024ULL;
#else
    max_page_size = 4 * 1024 * 1024;
#endif
    if (_memory_page_size < min_span_size)
        _memory_page_size = min_span_size;
    if (_memory_page_size > max_page_size)
        _memory_page_size = max_page_size;
    _memory_page_size_shift = 0;
    size_t page_size_bit = _memory_page_size;
    while (page_size_bit != 1) {
        ++_memory_page_size_shift;
        page_size_bit >>= 1;
    }
    _memory_page_size = ((size_t)1 << _memory_page_size_shift);

    _memory_span_map_count = ( _memory_config.span_map_count ? _memory_config.span_map_count : DEFAULT_SPAN_MAP_COUNT);
    if ((_memory_span_size * _memory_span_map_count) < _memory_page_size)
        _memory_span_map_count = (_memory_page_size / _memory_span_size);
    if ((_memory_page_size >= _memory_span_size) && ((_memory_span_map_count * _memory_span_size) % _memory_page_size))
        _memory_span_map_count = (_memory_page_size / _memory_span_size);
    _memory_heap_reserve_count = (_memory_span_map_count > DEFAULT_SPAN_MAP_COUNT) ? DEFAULT_SPAN_MAP_COUNT : _memory_span_map_count;

    _memory_config.span_map_count = _memory_span_map_count;

    //Setup all small and medium size classes
    size_t iclass = 0;
    _memory_size_class[iclass].block_size = SMALL_GRANULARITY;
    _rpmalloc_adjust_size_class(iclass);
    for (iclass = 1; iclass < SMALL_CLASS_COUNT; ++iclass) {
        size_t size = iclass * SMALL_GRANULARITY;
        _memory_size_class[iclass].block_size = (uint32_t)size;
        _rpmalloc_adjust_size_class(iclass);
    }
    //At least two blocks per span, then fall back to large allocations
    _memory_medium_size_limit = (_memory_span_size - SPAN_HEADER_SIZE) >> 1;
    if (_memory_medium_size_limit > MEDIUM_SIZE_LIMIT)
        _memory_medium_size_limit = MEDIUM_SIZE_LIMIT;
    for (iclass = 0; iclass < MEDIUM_CLASS_COUNT; ++iclass) {
        size_t size = SMALL_SIZE_LIMIT + ((iclass + 1) * MEDIUM_GRANULARITY);
        if (size > _memory_medium_size_limit)
            break;
        _memory_size_class[SMALL_CLASS_COUNT + iclass].block_size = (uint32_t)size;
        _rpmalloc_adjust_size_class(SMALL_CLASS_COUNT + iclass);
    }

    _memory_orphan_heaps = 0;
    memset(_memory_heaps, 0, sizeof(_memory_heaps));

    //Initialize this thread
    rpmalloc_thread_initialize();
    return 0;
}

//! Finalize the allocator
void
rpmalloc_finalize(void) {
    rpmalloc_thread_finalize(1);

    if (_memory_global_reserve) {
        _memory_global_reserve_master->remaining_spans -= (int32_t)_memory_global_reserve_count;
        _memory_global_reserve_master = 0;
        _memory_global_reserve_count = 0;
        _memory_global_reserve = 0;
    }

    //Free all thread caches and fully free spans
    for (size_t list_idx = 0; list_idx < HEAP_ARRAY_SIZE; ++list_idx) {
        heap_t* heap = _memory_heaps[list_idx];
        while (heap) {
            heap_t* next_heap = heap->next_heap;
            heap->finalize = 1;
            _rpmalloc_heap_global_finalize(heap);
            heap = next_heap;
        }
    }

    _rpmalloc_initialized = 0;
}

//! Initialize thread, assign heap
void
rpmalloc_thread_initialize(void) {
    if (!_memory_thread_heap) {
        heap_t* heap = _rpmalloc_heap_allocate(0);
        if (heap) {
            set_thread_heap(heap);
        }
    }
}

//! Finalize thread, orphan heap
void
rpmalloc_thread_finalize(int release_caches) {
    heap_t* heap = _memory_thread_heap;
    if (heap)
        _rpmalloc_heap_release_raw(heap, release_caches);
    set_thread_heap(0);
}

int
rpmalloc_is_thread_initialized(void) {
    return (_memory_thread_heap != 0) ? 1 : 0;
}

const rpmalloc_config_t*
rpmalloc_config(void) {
    return &_memory_config;
}

// Extern interface

RPMALLOC_ALLOCATOR void*
rpmalloc(size_t size) {
    return _rpmalloc_allocate(_memory_thread_heap, size);
}

void
rpfree(void* ptr) {
    _rpmalloc_deallocate(ptr);
}

RPMALLOC_ALLOCATOR void*
rpcalloc(size_t num, size_t size) {
    size_t total;
    total = num * size;
    void* block = _rpmalloc_allocate(_memory_thread_heap, total);
    if (block)
        memset(block, 0, total);
    return block;
}

RPMALLOC_ALLOCATOR void*
rprealloc(void* ptr, size_t size) {
    return _rpmalloc_reallocate(_memory_thread_heap, ptr, size, 0, 0);
}

RPMALLOC_ALLOCATOR void*
rpaligned_realloc(void* ptr, size_t alignment, size_t size, size_t oldsize,
                  unsigned int flags) {
    return _rpmalloc_aligned_reallocate(_memory_thread_heap, ptr, alignment, size, oldsize, flags);
}

RPMALLOC_ALLOCATOR void*
rpaligned_alloc(size_t alignment, size_t size) {
    return _rpmalloc_aligned_allocate(_memory_thread_heap, alignment, size);
}

RPMALLOC_ALLOCATOR void*
rpaligned_calloc(size_t alignment, size_t num, size_t size) {
    size_t total;
    total = num * size;
    void* block = rpaligned_alloc(alignment, total);
    if (block)
        memset(block, 0, total);
    return block;
}

RPMALLOC_ALLOCATOR void*
rpmemalign(size_t alignment, size_t size) {
    return rpaligned_alloc(alignment, size);
}

int
rpposix_memalign(void **memptr, size_t alignment, size_t size) {
    if (memptr)
        *memptr = rpaligned_alloc(alignment, size);
    else
        return EINVAL;
    return *memptr ? 0 : ENOMEM;
}

size_t
rpmalloc_usable_size(void* ptr) {
    return (ptr ? _rpmalloc_usable_size(ptr) : 0);
}
