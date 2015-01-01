module dbox.common.b2growablestack;

import core.stdc.float_;
import core.stdc.stdlib;
import core.stdc.string;

import dbox.common;
import dbox.common.b2math;

/*
 * Copyright (c) 2010 Erin Catto http://www.box2d.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 * claim that you wrote the original software. If you use this software
 * in a product, an acknowledgment in the product documentation would be
 * appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 * misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

// #ifndef B2_GROWABLE_STACK_H
// #define B2_GROWABLE_STACK_H
import dbox.common;

/// This is a growable LIFO stack with an initial capacity of N.
/// If the stack size exceeds the initial capacity, the heap is used
/// to increase the size of the stack.
struct b2GrowableStack(T, int32 N)
{
    @disable this();
    @disable this(this);

    this(int)
    {
        m_stack = m_array.ptr;
    }

    T* m_stack;

    ~this()
    {
        if (m_stack != m_array.ptr)
        {
            b2Free(m_stack);
            m_stack = null;
        }
    }

    void Push(T element)
    {
        if (m_count == m_capacity)
        {
            T* old = m_stack;
            m_capacity *= 2;

            static if (is(T == class))
                enum size = b2memSizeOf!T;
            else
                enum size = b2memSizeOf!T;

            m_stack = cast(T*)b2Alloc(m_capacity * size);
            memcpy(m_stack, old, m_count * size);

            if (old != m_array.ptr)
            {
                b2Free(old);
            }
        }

        m_stack[m_count] = element;
        ++m_count;
    }

    T Pop()
    {
        assert(m_count > 0);
        --m_count;
        return m_stack[m_count];
    }

    int32 GetCount()
    {
        return m_count;
    }

/* private */
    T[N] m_array;
    int32 m_count;
    int32 m_capacity = N;
}
