#ifndef NATIVE_COLLECTIONS_ARRAYLIST_H
#define NATIVE_COLLECTIONS_ARRAYLIST_H

#include <stdint.h>
#include <stdbool.h>

#pragma pack(push, 4)
typedef struct ArrayList
{
    uint64_t* array;
    uint32_t size;
    uint32_t allocatedMemory;   //in bytes
} ArrayList;
#pragma pack(pop)

extern ArrayList* ArrayListDefault();
extern ArrayList* ArrayListCopy(ArrayList*);
extern ArrayList* ArrayListCapacity(uint32_t initialCapacity);

extern void AL_trimToSize(ArrayList*);
extern void AL_ensureCapacity(ArrayList*, uint32_t minCapacity);

extern bool AL_isEmpty(ArrayList*);
extern bool AL_contains(ArrayList*, uint64_t);
extern uint32_t AL_indexOf(ArrayList*, uint64_t);
extern uint32_t AL_lastIndexOf(ArrayList*, uint64_t);

extern ArrayList* AL_clone(ArrayList*);
extern uint64_t* AL_toArray(ArrayList*);

extern uint64_t AL_get(ArrayList*, uint32_t index);
extern uint64_t AL_set(ArrayList*, uint32_t index, uint64_t element);
extern bool AL_add(ArrayList*, uint64_t);
extern void AL_addInside(ArrayList*, uint32_t index, uint64_t element);

extern uint64_t AL_remove(ArrayList*, uint32_t index);
extern bool AL_removeElement(ArrayList*, uint64_t);
extern void AL_clear(ArrayList*);
extern void AL_free(ArrayList*);

#endif //NATIVE_COLLECTIONS_ARRAYLIST_H
