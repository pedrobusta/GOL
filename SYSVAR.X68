; =============================================================================
; TITLE    : SYSTEM VARS
; AUTHOR   : ANTONI BURGUERA & PEDRO BUSTAMANTE
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : * ALL THESE VARS ARE USED TO SHARE DATA FROM SYSTEM TO USER. THUS
;              THEY MUST NOT BE IN PROTECTED MEMORY.
;
;            * SINCE SOME SUBROUTINES TAKE ADVANTAGE OF THE ORDER IN WHICH
;              THE VARIABLES ARE IN MEMORY, THEIR ORDER SHOULD NOT BE ALTERED.
; =============================================================================

; --- MOUSE RELATED VARIABLES -------------------------------------------------

MOUY        DS.W    1                       ; MOUSE Y COORDINATE
MOUX        DS.W    1                       ; MOUSE X COORDINATE
MOUVAL      DS.B    1                       ; CURRENT MOUSE BUTTON STATUS
MOUEDGE     DS.B    1                       ; RISING EDGES IN MOUVAL
            DS.W    0
*~Font name~Fixedsys~
*~Font size~18~
*~Tab type~0~
*~Tab size~4~
