/*
 * Copyright 2014 Onat Turkcuoglu. All rights reserved.
 * License: http://www.opensource.org/licenses/BSD-2-Clause
 */

#include <bx/timer.h>

#include <SDL2/SDL.h>
#undef main

#include <bgfx.h>
#include <bgfxplatform.h>

#include "core_xforms.h"

#include "nanovg/nanovg.h"

#define BLENDISH_IMPLEMENTATION
#include "blendish.h"
#include "ui_xforms.h"

static char stdout_msg[2048] = {0};
static bool quit = false;

int main(int _argc, char** _argv)
{
    uint32_t width = 1280;
    uint32_t height = 720;
    uint32_t debug = BGFX_DEBUG_TEXT;
    uint32_t reset = BGFX_RESET_VSYNC;

	SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* wnd = SDL_CreateWindow("luminos"
                    , SDL_WINDOWPOS_UNDEFINED
                    , SDL_WINDOWPOS_UNDEFINED
                    , width
                    , height
                    , SDL_WINDOW_SHOWN
                    | SDL_WINDOW_RESIZABLE
                    );

    bgfx::sdlSetWindow(wnd);

    bgfx::init();
    bgfx::reset(width, height);

    NVGcontext* nvg = nvgCreate(512, 512, 1, 0);
	bgfx::setViewSeq(0, true);

	bndSetFont(nvgCreateFont(nvg, "droidsans", "font/droidsans.ttf"));
	bndSetIconImage(nvgCreateImage(nvg, "images/blender_icons16.png"));

    // Enable debug text.
    bgfx::setDebug(debug);

    // Set view 0 clear state.
    bgfx::setViewClear(0
        , BGFX_CLEAR_COLOR_BIT|BGFX_CLEAR_DEPTH_BIT
        , 0x303030ff
        , 1.0f
        , 0
        );
	int64_t timeOffset = bx::getHPCounter();

    // Setup Lua
    core_init();
    ui_init();
    ui_setNVGContext(nvg);

    core_initGlobals();
    cmd_compile("scripts/program.lua", s_statusMsg, s_errorMsg);

	//SDL_Event event;
    //while (!entry::processEvents(width, height, debug, reset, &mouse_state) )
    while (!quit)
    {
        SDL_PumpEvents();
        quit = ui_frameStart();

		int64_t now = bx::getHPCounter();
		const double freq = double(bx::getHPFrequency() );
		float time = (float)( (now-timeOffset)/freq);

        // Set view 0 default viewport.
        bgfx::setViewRect(0, 0, 0, width, height);

        // This dummy draw call is here to make sure that view 0 is cleared
        // if no other draw calls are submitted to view 0.
        bgfx::submit(0);

		core_updateGlobals(time);
        port_programStart("portProgramStart", stdout_msg);

        bgfx::dbgTextPrintf(0, 3, 0x6f, stdout_msg);

        nvgBeginFrame(nvg, width, height, 1.0f, NVG_STRAIGHT_ALPHA);
        for (int i = 0; i < 3; i++)
        {
			float k  =(float)i;
            bndNodePort(nvg, 640 + k * 50, 100 + k * 90, (BNDwidgetState)i, nvgRGBA(255, 50, 100, 255));
            bndNodeWire(nvg, 640 + k * 50, 100 + k * 90, 800 + k * 50, 400 + k * 90, (BNDwidgetState)i, BNDwidgetState::BND_DEFAULT);
            bndNodeBackground(nvg, 300 + k * 300, 400, 200, 100, (BNDwidgetState)i, BND_ICONID(5, 11), "Node Background", nvgRGBA(255, 50, 100, 255));
        }
		nvgEndFrame(nvg);

        // Advance to next frame. Rendering thread will be kicked to
        // process submitted rendering primitives.
        bgfx::frame();

        ui_frameEnd();
    }

    // Shutdown bgfx.
    bgfx::shutdown();
	core_shutdown();

    SDL_DestroyWindow(wnd);
    SDL_Quit();
    return 0;
}
