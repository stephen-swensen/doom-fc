/* Headless linuxdoom demo player: the sync oracle for doom-fc (see build.sh). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "doomdef.h"
#include "doomstat.h"
#include "d_event.h"
#include "m_argv.h"
#include "w_wad.h"
#include "z_zone.h"
#include "r_main.h"
#include "p_local.h"
#include "g_game.h"
#include "m_random.h"
#include "s_sound.h"
#include "d_main.h"
#include "i_system.h"
#include "st_stuff.h"
#include "hu_stuff.h"
#include "d_net.h"

extern int prndindex;
extern boolean singledemo;
int tictrace = 0;
void G_DeferedPlayDemo (char* name);

/* --- i_system --- */
ticcmd_t emptycmd;
ticcmd_t* I_BaseTiccmd(void) { return &emptycmd; }
int I_GetHeapSize (void) { return 64*1024*1024; }
byte* I_ZoneBase (int* size) { *size = 64*1024*1024; return malloc(*size); }
int I_GetTime (void) { return gametic; }
void I_Init (void) {}
void I_Quit (void) {
    player_t* p = &players[consoleplayer];
    if (p->mo)
        printf("DEMOEND gametic=%d map=E%dM%d health=%d kills=%d items=%d secrets=%d x=%d y=%d rnd=%d\n",
               gametic, gameepisode, gamemap, p->health, p->killcount, p->itemcount, p->secretcount, p->mo->x, p->mo->y, prndindex);
    exit(0);
}
void I_WaitVBL(int count) {}
byte* I_AllocLow(int length) { return calloc(1,length); }
void I_Tactile(int on, int off, int total) {}
void I_Error (char *error, ...) { va_list a; va_start(a,error); fprintf(stderr,"Error: "); vfprintf(stderr,error,a); fprintf(stderr,"\n"); va_end(a); exit(1); }
void I_BeginRead(void) {}
void I_EndRead(void) {}
void I_SetPalette (byte* palette) {}
void I_UpdateNoBlit (void) {}
void I_FinishUpdate (void) {}
void I_ReadScreen (byte* scr) {}
void I_StartFrame (void) {}
void I_StartTic (void) {}
/* --- sound --- */
void S_StartSound(void* origin, int sfx_id) {}
void S_StopSound(void* origin) {}
void S_Start(void) {}
void S_StartMusic(int m_id) {}
void S_ChangeMusic(int musicnum, int looping) {}
void S_PauseSound(void) {}
void S_ResumeSound(void) {}
void S_UpdateSounds(void* listener) {}
/* --- ui --- */
void ST_Start (void) {}
void ST_Ticker (void) {}
boolean ST_Responder (event_t* ev) { return false; }
void HU_Start(void) {}
void HU_Ticker(void) {}
boolean HU_Responder(event_t* ev) { return false; }
char HU_dequeueChatChar(void) { return 0; }
void AM_Stop (void) {}
void AM_Ticker (void) {}
boolean AM_Responder (event_t* ev) { return false; }
void WI_Start(wbstartstruct_t* wbstartstruct) {}
void WI_Ticker (void) {}
void F_StartFinale (void) {}
void F_Ticker (void) {}
boolean F_Responder (event_t* ev) { return false; }
void M_StartControlPanel (void) {}
void M_ScreenShot (void) {}
boolean M_WriteFile (char const* name, void* source, int length) { return false; }
int M_ReadFile (char const* name, byte** buffer) { return 0; }
void D_PageTicker (void) {}
void D_AdvanceDemo (void) { I_Quit(); }
void NetUpdate (void) {}
int mouseSensitivity, showMessages, detailLevel = 0, screenblocks = 10;
boolean inhelpscreens;
boolean menuactive;
boolean automapactive;
void R_ExecuteSetViewSize (void);

int main(int argc, char** argv)
{
    char* files[2];
    int i;
    myargc = argc; myargv = argv;
    files[0] = argv[1]; files[1] = NULL;
    tictrace = M_CheckParm("-tictrace");
    gamemode = retail;
    Z_Init();
    W_InitMultipleFiles(files);
    if (W_CheckNumForName("MAP01") >= 0) gamemode = commercial;
    R_Init();
    P_Init();
    playeringame[0] = true;
    singledemo = true;
    G_DeferedPlayDemo(argv[2]);
    for (;;) {
        G_Ticker();
        if (tictrace && players[consoleplayer].mo)
            printf("T %d %d %d %d %d\n", gametic, prndindex, players[consoleplayer].mo->x, players[consoleplayer].mo->y, players[consoleplayer].health);
        gametic++;
    }
}
boolean fastparm, nomonsters, respawnparm, singletics;
int maketic, ticdup = 1;
ticcmd_t netcmds[MAXPLAYERS][BACKUPTICS];
char* player_names[4] = {"Green: ", "Indigo: ", "Brown: ", "Red: "};
gamestate_t wipegamestate;
