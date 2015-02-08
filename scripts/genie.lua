-- Edited from bgfx by Branimir Karadzic
--
-- Copyright 2015 Onat Turkcuoglu. All rights reserved.
-- License: http://www.opensource.org/licenses/BSD-2-Clause

LUMINOS_DIR = path.getabsolute("./../") .. "/"
LUA_DIR = LUMINOS_DIR .. "../luajit-2.0"
SDL2_DIR = LUMINOS_DIR .. "../SDL"

solution "luminos"
	configurations {
		"Debug",
		"Release",
	}

    language "C++"

	platforms {
		"x32",
		"x64",
--		"Xbox360",
		"Native", -- for targets where bitness is not specified
	}

local LUMINOS_BUILD_DIR = (LUMINOS_DIR .. "/.build/")
local LUMINOS_THIRD_PARTY_DIR = (LUMINOS_DIR .. "/3rdparty/")

dofile "toolchain.lua"

toolchain(LUMINOS_BUILD_DIR, LUMINOS_THIRD_PARTY_DIR)

project "luminos"
uuid (os.uuid(_name))
kind "WindowedApp"

configuration {}
defines { "UNICODE" }

debugdir (LUMINOS_DIR .. "/runtime/")

location (LUMINOS_BUILD_DIR .. "/projects/" .. _ACTION)

includedirs {
    LUMINOS_DIR .. "/3rdparty",
    LUA_DIR .. "/src",
}

-- Required for FFI
linkoptions { "-rdynamic" }

files {
    LUMINOS_DIR .. "/src/**.cpp",
    LUMINOS_DIR .. "/src/**.c",
    LUMINOS_DIR .. "/src/**.h",
    LUMINOS_DIR .. "/3rdparty/nanovg/*.c",
    LUMINOS_DIR .. "/3rdparty/imgui/*.cpp",
}

links {
    "luajit-5.1",
    "SDL2",
}

libdirs {
    LUA_DIR .. "/src",
}

configuration { "x32", "windows*" }
libdirs {
}
configuration { "x64", "windows*" }
libdirs {
}

configuration { "x32", "linux" }
libdirs {
}
configuration { "x64", "linux" }
libdirs {
}

configuration { "x32", "windows" }
    libdirs { SDL2_DIR .. "lib/x86" }

configuration { "x64", "windows" }
    libdirs { SDL2_DIR .. "lib/x64" }

configuration { "vs*" }
    linkoptions {
        "/ignore:4199", -- LNK4199: /DELAYLOAD:*.dll ignored; no imports found from *.dll
    }

configuration { "vs201*" }
    linkoptions { -- this is needed only for testing with GLES2/3 on Windows with VS201x
        "/DELAYLOAD:\"libEGL.dll\"",
        "/DELAYLOAD:\"libGLESv2.dll\"",
    }

configuration { "windows" }
    links {
        "gdi32",
        "psapi",
    }

configuration { "linux-*" }
    links {
        "X11",
        "GL",
        "pthread",
	"m",
    }

configuration {}
