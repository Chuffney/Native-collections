#ifndef JNI_HASHMAP_H
#define JNI_HASHMAP_H

#include <stdint.h>
#include <stdbool.h>

typedef uint64_t (*hashingFunction)(uint64_t);
typedef bool (*equalityFunction) (uint64_t, uint64_t);

#pragma pack(push, 4)
typedef struct HashMap
{
    void* nodes;
    void* buckets;
    hashingFunction hf;
    equalityFunction ef;
    uint32_t size;
    uint32_t nextResize;
    uint32_t allocatedMemory;
} HashMap;
#pragma pack(pop)

extern const hashingFunction HM_defaultHash;
extern const equalityFunction HM_defaultEquals;

extern HashMap* HashMapDefault(hashingFunction, equalityFunction);
extern HashMap* HashMapCapacity(hashingFunction, equalityFunction, uint32_t initialCapacity);
extern HashMap* HashMapCapLF(hashingFunction, equalityFunction, uint32_t initialCapacity, float loadFactor);

extern void HM_clear(HashMap*);
extern bool HM_containsKey(HashMap*, uint64_t key);
extern bool HM_containsValue(HashMap*, uint64_t value);

extern void HM_forEach(HashMap*, void *loopBody(uint64_t value));
extern uint64_t HM_get(HashMap*, uint64_t key);
extern uint64_t HM_getOrDefault(HashMap*, uint64_t key, uint64_t defaultValue);

extern bool HM_isEmpty(HashMap*);
extern uint64_t HM_put(HashMap*, uint64_t key, uint64_t value);
extern uint64_t HM_putIfAbsent(HashMap*, uint64_t key, uint64_t value);

extern uint64_t HM_remove(HashMap*, uint64_t key);
extern uint64_t HM_removeKV(HashMap*, uint64_t key, uint64_t value);

extern uint32_t HM_size(HashMap*);
extern void HM_free(HashMap*);

#endif //JNI_HASHMAP_H
