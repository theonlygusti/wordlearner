@include "include/Utils"

BEGIN {
    START_TEST("Utils.awk")

    T("GawkVersion", 1)
    {
        initGawk()
        assertTrue(GawkVersion ~ "^4.")
    }

    T("Rlwrap", 1)
    {
        initRlwrap()
        assertEqual(Rlwrap, "rlwrap")
    }

    T("Emacs", 1)
    {
        initEmacs()
        assertEqual(Emacs, "emacs")
    }

    T("newerVersion()", 5)
    {
        assertTrue(newerVersion("0.9", "0.8"))
        assertTrue(newerVersion("0.9.0.1", "0.9.0"))
        assertTrue(newerVersion("1.0", "0.9.9999"))
        assertTrue(newerVersion("1.9.9999", "1.9.10"))
        assertTrue(newerVersion("2", "1.9.9999"))
    }

    T("dump()", 3)
    {
        delete group
        assertEqual(dump("a", group), 1)

        delete group
        assertEqual(dump("Århus", group), 6)

        delete group
        assertEqual(dump("안녕하세요 세계", group), 22)
    }

    END_TEST()
}
