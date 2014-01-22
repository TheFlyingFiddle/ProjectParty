module math.traits;

import math.vector;
template isVector(T)
{
    static if (is(T t == Vector!(num, U), int num, U)) {
        enum isVector = true;
    }
    else
        enum isVector = false;
}