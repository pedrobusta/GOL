; =============================================================================
; TITLE    : SYSTEM MANAGEMENT (SYSTEM CODE)
; AUTHOR   : ANTONI BURGUERA & PEDRO BUSTAMANTE
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : IT IS DIVIDED IN THREE BLOCKS:
;            - SYS : GENERIC.
;            - SCR : SCREEN MANAGEMENT.
;            - MOU : MOUSE MANAGEMENT
;            THE FORMAT OF MOUVAL AND MOUEDGE IS DESCRIBED IN SYSCONST.
; =============================================================================

; -----------------------------------------------------------------------------
SYSINIT
; INITIALIZES THE SYSTEM AS FOLLOWS:
; * DISABLES INTERRUPTS
; * CALLS SCRINIT
; * CALLS MOUINIT
; * ENABLES SIMULATOR EXCEPTION PROCESSING
; * SWITCHES TO USER
; INPUT    - NONE
; OUTPUT   - NONE
; MODIFIES - NONE
; NOTE     - NOTE THAT INTERRUPTS REMAIN DISABLED AFTER THIS SUBROUTINE
; -----------------------------------------------------------------------------                             
            OR.W   #$0700,SR                ; DISABLE INTERRUPTS 
            
            MOVE.W  SR,-(A7)                ; SAVE SR INTO STACK 
            MOVEM.L D0-D1,-(A7)               
            
            
            JSR     SCRINIT                 ; CALLS SCRINIT
            JSR     MOUINIT                 ; CALLS MOUINIT
            
            ;ENABLES SIMULATOR EXCEPTION PROCESSING 
            MOVE.B  #32,D0                 
            MOVE.B  #5,D1
            TRAP    #15
            
            MOVEM.L (A7)+,D0-D1
            
              
            AND.W  #$DFFF,(A7)              ; SWITCH TO USER

            RTE              
; =============================================================================
; MOUSE MANAGEMENT (SYSTEM CODE)
; =============================================================================

; -----------------------------------------------------------------------------
MOUINIT
; INITIALIZES MOUSE AS FOLLOWS:
; * STORES CURRENT MOUSE POSITION AND BUTTON STATUS INTO MOUY, MOUX AND MOUVAL
; * CLEARS MOUEDGE
; * INSTALLS MOUREAD INTO TRAP #MOUTRAP
; INPUT    - NONE
; OUTPUT   - NONE
; MODIFIES - ALL REGISTERS CAN BE MODIFIED
; -----------------------------------------------------------------------------            
            
            MOVE.B  #61,D0                  ; GET MOUSE POSITION
            CLR.B   D1
            TRAP    #15
            
            MOVE.L  D1,(MOUY)               ; STORE IT INTO MOUY,MOUX                      
                         
            MOVE.B  D0,(MOUVAL)             ; STORE IT INTO MOUVAL

            CLR.B   MOUEDGE
   
            MOVE.L  #MOUREAD,($80+MOUTRAP*4) ; INSTALL MOUREAD INTO TRAP                                       
                         
            RTS 
   
; -----------------------------------------------------------------------------
MOUREAD
; MOUSE READING TRAP SERVICE ROUTINE. IT DOES THE FOLLOWING:
; * STORES CURRENT MOUSE POSITION INTO MOUY AND MOUX.
; * STORES CURRENT BUTTON STATUS INTO MOUVAL
; * COMPUTES AND STORES MOUEDGE
; INPUT    - NONE
; OUTPUT   - NONE
; MODIFIES - NONE
; -----------------------------------------------------------------------------

            MOVEM.L D0-D2,-(A7)                          
            
            AND.B   #00000111,(MOUVAL)      ; IN MOUVAL = t-1  
            MOVE.B  (MOUVAL),D2             ; D2 = NOT(t-1)                                                         
            NOT.B   D2                      
            
            MOVE.B  #61,D0                  ; GET CURRENT STATUS AND 
            CLR.B   D1                      ; AND CURRENT MOUSE POSITION
            TRAP    #15
            
            MOVE.L  D1,(MOUY)               ; STORE MOUSE POSITION INTO MOUY,MOUX                                      
            MOVE.B  D0,(MOUVAL)             ; STORE CURRENT STATUS INTO MOUVAL
 
            AND.W   D0,D2                   ; (t)*NOT(t-1) = MOUEDGE
            MOVE.B  D2,(MOUEDGE)
            
            MOVEM.L (A7)+,D0-D2            
            
            RTE

; =============================================================================
; SCREEN MANAGEMENT (SYSTEM CODE)
; =============================================================================

; -----------------------------------------------------------------------------
SCRINIT
; INITIALIZES THE SCREEN, SCREEN-RELATED INTERRUPT AND VARS AS FOLLOWS:
; * INSTALLS SCRUPD INTO TRAP #SCRTRAP
; * SETS OUTPUT RESOLUTION TO SCRWIDTH*SCRHEIGH
; * SETS OUTPUT TO WINDOWED MODE
; * ENABLES DOUBLE BUFFER AND CLEARS BOTH SCREEN BUFFERS
; INPUT    - NONE
; OUTPUT   - NONE
; MODIFIES - ALL REGISTERS CAN BE MODIFIED
; -----------------------------------------------------------------------------
            MOVE.L  #SCRUPD,($80+SCRTRAP*4) ; INSTALL TRAP
            MOVE.L  #SCRWIDTH<<16|SCRHEIGH,D1 ; SET RESOLUTION
            MOVE.B  #33,D0
            TRAP    #15
            MOVE.L  #1,D1                   ; SET WINDOWED MODE
            TRAP    #15
            MOVE.W  #$FF00,D1               ; CLEAR VISIBLE BUFFER
            MOVE.B  #11,D0
            TRAP    #15
            MOVE.B  #17,D1                  ; ENABLE DOUBLE BUFFER
            MOVE.B  #92,D0
            TRAP    #15
            MOVE.W  #$FF00,D1               ; CLEAR HIDDEN BUFFER
            MOVE.B  #11,D0
            TRAP    #15
            RTS

; -----------------------------------------------------------------------------
SCRUPD
; TRAP SERVICE ROUTINE IN CHARGE OF VISUALIZING CURRENT FRAME AND CLEARING
; BUFFER FOR THE NEXT ONE. PERFORMS TWO TASKS:
; * CLEARS ACTIVE (HIDDEN) GRAPHICS BUFFER
; * SWITCHES ACTIVE AND VISIBLE GRAPHICS BUFFER
; INPUT    - NONE
; OUTPUT   - NONE
; MODIFIES - NONE
; -----------------------------------------------------------------------------
            MOVEM.W D0-D1,-(A7)
            MOVE.B  #94,D0                  ; UPDATE DOUBLE BUFFER
            TRAP    #15
            MOVE.W  #$FF00,D1               ; CLEAR HIDDEN BUFFER
            MOVE.B  #11,D0
            TRAP    #15
            MOVEM.W (A7)+,D0-D1
            RTE



























*~Font name~Fixedsys~
*~Font size~18~
*~Tab type~0~
*~Tab size~4~
