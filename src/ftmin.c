/* Minimal FreeType init: register ONLY the modules needed to render the one
 * embedded TrueType font (builtin_font.ttf), antialiased.
 *
 * WHY THIS FILE EXISTS (it is a size lever, not a feature):
 * fntsys.cpp's FT_Init_FreeType call is the ONLY thing that pulls
 * libfreetype.a(ftinit.c.obj) into the link. ftinit's FT_Add_Default_Modules
 * names every driver class FreeType ships, so the linker then drags in bdf,
 * pcf, pfr, type1, type1cid, type42, winfnt, cff, sdf, svg, autofit, raster,
 * psaux and pshinter -- for a program that renders exactly one .ttf. Defining
 * these two symbols here means ftinit.c.obj is never pulled, and with it goes
 * every driver we do not use. Measured: ~353KB off the unpacked ELF, ~124KB off
 * the shipped (packed) ELF, ~33% of all EE code.
 *
 * FT_Done_FreeType lives in ftinit.c too, so BOTH must be defined here or the
 * linker pulls the member (and every driver) straight back in.
 *
 * This changes only WHICH archive members enter the link. It is not a code-gen
 * change and touches no USB/BDM code, so it is not in the risk class of the -Os
 * revert (see the note at the bottom of the Makefile).
 *
 * If a future font ever needs a dropped driver (e.g. a .otf/CFF font, or
 * autofit hinting for an unhinted face), add its class here; do not restore
 * ftinit.
 */
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MODULE_H

/* Internal, but globally visible, symbols from ftsystem.c / ftobjs.c. Declared
 * by hand: ps2dev's libfreetype ships the archive but not the internal headers
 * (ftobjs.h) that declare these. Verified present in the stock
 * ps2sdk/ports/lib/libfreetype.a with nm. */
extern FT_Memory FT_New_Memory(void);
extern void      FT_Done_Memory(FT_Memory memory);

/* Module classes we keep. Every FT_*_ClassRec begins with an FT_Module_Class,
 * so &x is a valid FT_Module_Class*. */
extern const FT_Module_Class tt_driver_class;          /* TrueType driver       */
extern const FT_Module_Class sfnt_module_class;        /* SFNT table loader     */
extern const FT_Module_Class psnames_module_class;     /* glyph name -> unicode */
extern const FT_Module_Class ft_smooth_renderer_class; /* antialiased rasterizer*/

/* Remember the allocator so FT_Done_FreeType can release it WITHOUT reaching
 * into FT_LibraryRec_. Reading library->memory would mean hardcoding that
 * `memory` is the first struct member, an undocumented ABI assumption that
 * would silently read a garbage pointer (and free it) if the layout ever moved.
 * The app creates exactly one FT_Library (fntsys.cpp), so a single static is
 * sufficient and exact. */
static FT_Memory ftmin_memory = 0;

FT_Error FT_Init_FreeType(FT_Library *alibrary)
{
    FT_Memory memory;
    FT_Error  error;

    if (!alibrary)
        return FT_Err_Invalid_Argument;

    memory = FT_New_Memory();
    if (!memory)
        return FT_Err_Cannot_Open_Resource;

    error = FT_New_Library(memory, alibrary);
    if (error) {
        FT_Done_Memory(memory);
        return error;
    }

    FT_Add_Module(*alibrary, &sfnt_module_class);
    FT_Add_Module(*alibrary, &psnames_module_class);
    FT_Add_Module(*alibrary, &tt_driver_class);
    FT_Add_Module(*alibrary, &ft_smooth_renderer_class);

    ftmin_memory = memory;
    return FT_Err_Ok;
}

FT_Error FT_Done_FreeType(FT_Library library)
{
    if (!library)
        return FT_Err_Invalid_Library_Handle;

    FT_Done_Library(library);

    if (ftmin_memory) {
        FT_Done_Memory(ftmin_memory);
        ftmin_memory = 0;
    }
    return FT_Err_Ok;
}
