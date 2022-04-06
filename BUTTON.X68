; =============================================================================
; TITLE    : BUTTON MANAGEMENT
; AUTHOR   : ANTONI BURGUERA & PEDRO BUSTAMANTE
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : * A BUTTON IS DEFINED BY A STATIC DATA BLOCK (SDB), WHICH DOES NOT
;              CHANGE OVER TIME, AND A VARIABLE DATA BLOCK (VDB), THAT CAN
;              CHANGE OVER TIME. CHANGES IN THE VDB ARE PRODUCED WHEN CALLING
;              SUBROUTINE BTNUPD.
;
;            * THE BUTTON SDB (CAN BE IN ROM) HAS THE FOLLOWING FIELDS. THE
;              NUMBER DENOTES THE OFFSET WITH RESPECT TO THE SDB START:
;
;                +0  - WORD - YTOP COORDINATE (PIXELS)
;                +2  - WORD - XLEFT COORDINATE (PIXELS)
;                +4  - WORD - HEIGHT (PIXELS)
;                +6  - WORD - WIDTH (PIXELS)
;                +8  - LONG - CALLBACK POINTER
;                +12 - BYTE STRING - ZERO TERMINATED STRING. TEXT TO SHOW.
;
;            * THE BUTTON VDB (MUST BE IN RAM) IS:
;
;                +0 - LONG - POINTER TO THE STATIC DATABLOCK
;                +4 - BYTE - STATUS WITH FORMAT XXXXXCPI WHERE:
;                            - I (BIT 0) - 1=MOUSE INSIDE, 0=MOUSE OUTSIDE
;                            - P (BIT 1) - 1=MOUSE PRESSED INSIDE
;                                          0=MOUSE NOT PRESSED INSIDE
;                            - C (BIT 2) - 1=MOUSE CLICKED INSIDE
;                                          0=MOUSE NOT CLICKED INSIDE
;                            NOTE THAT IF I=0 THEN P=C=0, IF I=1 AND P=0
;                            THEN C=0.
; =============================================================================

; -----------------------------------------------------------------------------
BTNINIT
; INITIALIZES THE BUTTON BY:
;  * COPYING THE SDB POINTER INTO THE VDB.
;  * CLEARING THE STATUS BYTE.
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
;            A1 - POINTER TO THE STATIC DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L A0-A1,-(A7)
            
            MOVE.L  A1,(A0)                 ; A0 = SDB POINTER
            MOVE.B  #0,4(A0)                ; CLEAR THE STATUS BYTE
            
            MOVEM.L (A7)+,A0-A1
            RTS
; -----------------------------------------------------------------------------
BTNUPD
; UPDATES THE BUTTON VDB AND EXECUTES THE CALLBACK IF REQUIRED
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A2,-(A7)
            
            MOVE.L  (A0),A1                 ; A1 = POINTER TO THE SDB
            MOVE.W  (A1),D0                 ; D0 = YTOP
            MOVE.W  2(A1),D1                ; D1 = XLEFT
            MOVE.W  4(A1),D2                ; D2 = HEIGHT
            MOVE.W  6(A1),D3                ; D3 = WIDTH
            MOVE.W  (MOUY),D4               ; D4 = MOUY
            MOVE.W  (MOUX),D5               ; D5 = MOUX
            
            SUB.W   D0,D4                   ; IF MOUY > YTOP JUMP 
            BPL     YPLUS0
            BRA     MOUSEOUT                                                
YPLUS0                 
            CMP.W   D2,D4                   ; IF (YTOP-MOUY) < HEIGHT JUMP                                      
            BMI     YIN
            BRA MOUSEOUT
 
YIN         ;MOUY INSIDE THE BUTTON
            SUB.W   D1,D5                   ; IF MOUX > XLEFT JUMP                   
            BPL     XPLUS0 
            BRA MOUSEOUT                         
XPLUS0                  
            CMP.W   D3,D5                   ; IF (XRIGHT-MOUX) < WIDTH JUMP
            BMI     XIN
            BRA MOUSEOUT
                    
XIN         ;MOUSE INSIDE
            MOVE.B  (MOUVAL),D4             ; IF NOT PRESSED JUMP
            BTST    #0,D4                    
            BEQ     MOUNOTP 
            MOVE.B  (MOUEDGE),D4            ; IF PRESSED BUT NOT CLICKED JUMP
            BTST    #0,D4
            BEQ     MOUPNOTC 
            MOVE.B  #%00000111,4(A0)        ; CLICKED AND PRESSED
 
            MOVE.L  8(A1),A2                ; DO THE CALLBACK
            JSR     (A2)
            BRA END
    
MOUPNOTC    ;MOUSE PRESSED
            MOVE.B   #%00000110,4(A0)
            BRA END                  
MOUNOTP     ;MOUSE NOT PRESSED
            MOVE.B   #%00000100,4(A0)
            BRA END
            
            
MOUSEOUT    ;MOUSE OUT OF BUTTON
            MOVE.B   #%00000000,4(A0)
END         
            MOVEM.L  (A7)+,D0-D7/A2
            
            RTS                                   
; -----------------------------------------------------------------------------
BTNPLOT
; PLOTS THE BUTTON. A RECTANGLE IS DRAWN WITH THICKNESS BTNPENWD. THE CONTOUR
; COLOR IS BTNPENCL. THE FILL COLOR IS BLACK IF THE MOUSE IS NOT INSIDE,
; BTNSELCL IF THE MOUSE IS INSIDE BUT THE MOUSE BUTTON IS NOT PRESSED AND
; BTNPRSCL IF THE MOUSE BUTTON IS PRESSED INSIDE.
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A1,-(A7)
 
            ;SET PEN COLOR
            MOVE.B  #80,D0
            MOVE.L  #BTNPENCL,D1
            TRAP    #15
            ;SET PEN WIDTH
            MOVE.B  #93,D0
            MOVE.B  #BTNPENWD,D1
            TRAP    #15
            
            MOVE.B  #81,D0                  ; PREPARE TASK NUMBER
            MOVE.B  4(A0),D2                ; MOVE TO D2 BUTTON STATUS
            CMP.B   #%00000100,D2           ; MASK IF THE MOUSE INSIDE BUT NOT PRESSED 
            BEQ     FILLSLCL
            CMP.B   #%00000110,D2           ; MASK IF THE MOUSE INSIDE AND PRESSED 
            BEQ     FILLPRSC
            CMP.B   #%00000000,D2           ; MASK IF MOUSE NOT INSIDE          

FILLBLCK    ;SETCOLOR
            MOVE.L  #CLRBLACK,D1
            TRAP    #15
            BRA DRAWRECT                        
FILLSLCL    ;SETCOLOR
            MOVE.L  #BTNSELCL,D1
            TRAP    #15
            BRA DRAWRECT    
FILLPRSC    ;SETCOLOR           
            MOVE.L  #BTNPRSCL,D1
            TRAP    #15 
            BRA DRAWRECT                         
                        
            ;DRAW RECTANGLE
DRAWRECT            
            MOVE.L  (A0),A1                 ; A1 = POINTS TO THE SDB
            MOVE.W  2(A1),D1                ; D1 = XLEFT
            MOVE.W  (A1),D2                 ; D2 = YTOP
            MOVE.W  6(A1),D3                ; D3 = RIGHT X
            ADD.W   D1,D3                   ; D4 = LOWER Y                   
            MOVE.W  4(A1),D4
            ADD.W   D2,D4                   
            MOVE.B  #87,D0  
            TRAP    #15

            ;DISPLAY THE STRING
            MOVE.W  6(A1),D3
            MOVE.W  4(A1),D4
            
            ; COMPUTES SIZE OF STRING
            LEA     12(A1),A1     
            JSR     UTLSTRLN                ; D0 = LENGTH OF THE STRING
            
            LSL.W   #CHRSHWID,D0  
            SUB.W   D0,D3
            LSR.W   #1,D3
            ADD.W   D3,D1                   ; D1 = COORD X
            
            SUB.W   #CHRHEIGH,D4
            LSR.W   #1,D4
            ADD.W   D4,D2                   ; D2 = COORD Y

                   
            MOVE.B  #95,D0
            TRAP    #15                     
            
            
            MOVEM.L  (A7)+,D0-D7/A0-A1
            RTS
            













*~Font name~Fixedsys~
*~Font size~18~
*~Tab type~0~
*~Tab size~4~
