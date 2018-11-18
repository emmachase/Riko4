#include "sequence.h"

Sequence::Sequence(lua_State *L, int arg) {
    TableInterface interface(L, arg);

    size = interface.getSize();
    data = new int[size];

    try {
        for (size_t i = 0; i < size; i++) {
            data[i] = interface.getNextInteger();
        }

        int loopAt = interface.getInteger("loop", 0) - 1;
        if (loopAt != -1) {
            if (loopAt < 0 || loopAt >= size) {
                interface.throwError("loop must be between 0 and the size of the sequence");
            }

            loop = true;
            loopPoint = static_cast<size_t>(loopAt);
        }
    } catch (const LuaError &e) {
        delete[] data;

        throw e;
    }
}

Sequence::~Sequence() {
    delete[] data;
}
