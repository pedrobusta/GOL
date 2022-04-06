; =============================================================================
; TITLE    : GRID MANAGEMENT
; AUTHOR   : ANTONI BURGUERA & PEDRO BUSTAMANTE
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : * THERE ARE TWO MATRICES (GRDMATR0 AND GRDMATR1) AND TWO POINTERS
;              TO THESE MATRICES (GRDSRC AND GRDDST).
;
;            * THE MATRIX TO BE PLOTTED IS ALWAYS THE ONE POINTED BY GRDDST.
;
;            * THE MATRIX TO BE UPDATED BY THE MOUSE (GRDMUPD) IS ALWAYS THE
;              ONE POINTED BY GRDDST.
;
;            * THE RULES-UPDATE (GRDRUPD) SWITCHES THE POINTERS AND THEN READS
;              THE NEW SOURCE MATRIX (GRDSRC) TO DETERMINE THE NUMBER OF
;              NEIGHBORS. THE RESULTING CELL VALUE IS WRITTEN TO THE DESTINA-
;              TION MATRIX, POINTED BY GRDDST.
; =============================================================================

; -----------------------------------------------------------------------------
GRDINIT
; INITIALIZE THE GRID AS FOLLOWS:
; * POINTS THE SOURCE GRID POINTER TO GRDMATR0.
; * POINTS THE DESTINATION GRID POINTER TO GRDMATR1.
; * RESETS THE COUNTERS (GRDNPLR1, GRDNPLR2, GRDNGEN).
; * FILLS THE TWO MATRICES (GRDMATR0 AND GRDMATR1) WITH ZEROS.
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L A0/D0,-(A7)
            MOVE.L  #GRDMATR0,(GRDSRC)
            MOVE.L  #GRDMATR1,(GRDDST)
            CLR.W   (GRDNPLR1)
            CLR.W   (GRDNPLR2)
            CLR.W   (GRDNGEN)
            LEA     GRDMATR0,A0
            MOVE.W  #GRDWIDTH*GRDHEIGH*2-1,D0
.LOOP       CLR.B   (A0)+
            DBRA.W  D0,.LOOP
            MOVEM.L (A7)+,A0/D0
            RTS
; -----------------------------------------------------------------------------
GRDMUPD
; GRID UPDATE USING MOUSE. THE INTERFACE IS AS FOLLOWS:
; * IF MOUSE IS NOT PRESSED OR IS OUTSIDE THE PLOTTED GRID, DOES NOTHING.
; * IF LEFT MOUSE BUTTON IS PRESSED INSIDE THE GRID:
;   - A PLAYER 1 (VALUE=1) CELL IS CREATED AT THE MOUSE POSITION IF THE MOUSE
;     IS ON THE LEFT HALF OF THE GRID.
;   - A PLAYER 2 (VALUE=2) CELL IS CREATED AT THE MOUSE POSITION IF THE MOUSE
;     IS ON THE RIGHT HALF OF THE GRID.
; * IF RIGHT MOUSE BUTTON IS PRESSED INSIDE THE GRID, THE CELL WHERE THE MOUSE
;   IS IS CLEARED (VALUE=0).
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0,-(A7)
          
            MOVE.L  (GRDDST), A0            ; A0 = POINTER TO GRDDST             
            BTST.B  #0,(MOUVAL)            
            BNE     PRESSED                 ; IF FIRST BIT OF MOUVAL IS 1 JUMP
            BTST.B  #1,(MOUVAL)
            BNE     PRESSED                 ; IF SECOND BIT OF MOUVAL IS 1 JUMP
            BRA     DONTHING
            
PRESSED     MOVE.W  (MOUX),D0               ; IN D0 = MOUX
            SUB.W   #GRDXOFF,D0             ; IF THE SUB IS > XLEFTGRID JUMP
            BPL     PLUSX0                 
            BRA     DONTHING
PLUSX0
            CMP.W   #GRDPXWID,D0            ; IF THE SUB < XRIGHTGRID JUMP
            BMI     XING                   
            BRA     DONTHING
            
                                            ; MOUX IS INSIDE THE GRID            
XING        MOVE.W  (MOUY),D1               ; IN D1 = MOUY
            SUB.W   #GRDYOFF,D1             ; IF THE SUB IS > YTOPGRID JUMP
            BPL     PLUSY0                  
            BRA     DONTHING
PLUSY0                  
            CMP.W   #GRDPXHEI,D1            ; IF THE SUB < YBOTGRID JUMP
            BMI     YING                   
            BRA     DONTHING
YING
                                            ; THE MOUSE IS INSIDE THE GRID
            MOVE.W  (MOUX),D0
            SUB.W   #GRDXOFF,D0  
            DIVU.W  #GRDSZCEL,D0            ; D0 = COL CLICKED OR PRESSED           
                
            MOVE.W  (MOUY),D1
            SUB.W   #GRDYOFF,D1
            DIVU.W  #GRDSZCEL,D1            ; D1 = ROW CLICKED OR PRESSED
            
            MOVE.W  #GRDWIDTH,D3
            MULU.W  D1,D3
            ADD.W   D0,D3                   ; D3 = OFFSET OF THE GRDDST VECTOR
                                      
            MOVE.W  #GRDSZCEL*GRDWIDTH+GRDXOFF,D4 
            ADD.W   #GRDSZCEL,D4          
            LSR.W   #1,D4                   ; D4 = CENTER OF THE GRID, X COORD
            ADD.W   #1,D4
            CMP.W   (MOUX),D4               ; IF MOUX > CENTER JUMP, LEFT SIDE
            BPL     LEFT                    ; IF NOT RIGHT SIDE  
RIGHT
            BTST.B  #1,(MOUVAL)
            BNE     RPRESSED                ; IF RIGHT PRESSED JUMP               
            MOVE.B  #2,(A0,D3)              ; IF NOT PUT 2 IN THE GRDDST VECTOR
            BRA     DONTHING              
RPRESSED
            CLR.B   (A0,D3)                 ; PUT 0 IN THE GRDDST VECTOR  
            BRA     DONTHING                        
LEFT
            BTST.B  #1,(MOUVAL)             ; IF RIGHT PRESSED  JUMP
            BNE     RPRESSED                ; IF NOT PUT 1 IN THE GRDDST VECTOR
            MOVE.B  #1,(A0,D3)              
DONTHING
            MOVEM.L (A7)+,D0-D7/A0
            RTS            
           
; -----------------------------------------------------------------------------
GRDRUPD
; UPDATES THE GRID ACCORDING TO 2-PLAYER GAME OF LIFE RULES AS FOLLOWS:
; * ADDS 1 TO THE NUMBER OF GENERATIONS (GRDNGEN)
; * SWITCHES THE MATRIX POINTERS (GRDDST AND GRDSRC).
; * CHECKS THE NEIGHBORS USING THE NEW SOURCE MATRIX (POINTER BY GRDDRC)
; * THE RESULTS OF APPLYING THE RULES ARE WRITTEN INTO THE NEW DESTINATION
;   MATRIX (POINTED BY GRDDST).
; * THE RULES ARE THE FOLLOWING, WHERE P1 AND P2 ARE 1 AND 2 RESPECTIVELY,
;   DEAD CELLS ARE REPRESENTED BY 0 AND NP1 AND NP2 DENOTE THE NUMBER OF
;   PLAYER 1 AND PLAYER 2 NEIGHBORS RESPECTIVELY:
;   + SURVIVAL RULES
;     - IF CELL IS P1 AND NP1-NP2 IS 2 OR 3 -> NEW VALUE IS P1
;     - IF CELL IS P1 AND NP1-NP2 IS 1 AND NP1>=2 -> NEW VALUE IS P1
;     - OTHERWISE -> NEW VALUE IS 0
;     - IF CELL IS P2 AND NP2-NP1 IS 2 OR 3 -> NEW VALUE IS P2
;     - IF CELL IS P2 AND NP2-NP1 IS 1 AND NP2>=2 -> NEW VALUE IS P2
;     - OTHERWISE -> NEW VALUE IS 0
;   + BIRTH RULES
;     - THE CELL HAS EXACTLY THREE P1 NEIGHBOURS AND THE NUMBER
;       OF P2 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
;       P1 TOKEN IS BORN IN THE CELL.
;     - THE CELL HAS EXACTLY THREE P2 NEIGHBOURS AND THE NUMBER
;       OF P1 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
;       P2 TOKEN IS BORN IN THE CELL.
;     - THE CELL HAS EXACTLY THREE WHITE AND THREE BLACK NEIGHBOURS.
;       IN THIS CASE AN UNBIASED COIN DETERMINES WHETHER A WHITE OR
;       BLACK TOKEN IS BORN IN THE CELL.
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A1,-(A7)

            ADD.W   #1,(GRDNGEN)            ; ADD 1 TO GEN COUNTER
            
            MOVE.L  (GRDDST), A0            ; A0 = POINTER TO GRDDST
            MOVE.L  (GRDSRC), A1            ; A1 = POINTER TO GRDSRC
            
                                            ; SWITCH MATRIX POINTERS
            MOVE.L  A0,(GRDSRC)             ; GRDSRC = A0 
            MOVE.L  A1,(GRDDST)             ; GRDST = A1
                      
            CLR.W   D0                      ; D0 = ROW COUNTER
            CLR.W   D1                      ; D1 = COL COUNTER
            MOVE.W  #GRDHEIGH*GRDWIDTH-1,D2 ; D2 = TO LOOP OVER THE GRID
FOR
            CLR.W   D5                      ; D5 = NP1 
            CLR.W   D6                      ; D6 = NP2 
            CLR.W   D7                      ; D7 = CURRENT CELL VALUE
            
            JSR     COUNTN                  ; COUNT NEIGHBOURS
            CMP.W   #1,D7                   ; D7 == 1 JUMP TO COMPP1
            BNE     .CONT                   ; D7 == 2 JUMP TO COMPP2    
            JSR     COMPP1                  ; D7 == 0 JUMP TO COMPBR
            BRA     .CONT3                       
.CONT       CMP.W   #2,D7
            BNE     .CONT2
            JSR     COMPP2
            BRA     .CONT3
.CONT2      CMP.W   #0,D7
            BNE     .CONT3
            JSR     COMPBR     
.CONT3      ADD.W   #1,D1                   ; ADD 1 TO COL COUNTER
            CMP.W   #GRDWIDTH,D1            ; IF COL COUNTER REACH MAX
            BEQ     RESETU                  ; RESET               
NEXTN       DBRA    D2,FOR
             
            MOVEM.L (A7)+,D0-D7/A0-A1
            RTS
RESETU
            CLR.W   D1                      ; RESET COL COUNTER
            ADD.W   #1,D0                   ; ADD 1 TO ROW COUNTER
            BRA     NEXTN                   ; NEXT ROW (R+1,0) 
           
; -----------------------------------------------------------------------------            
COMPBR
; COMPUTES DEPENDING OF NEIGHBOURS IF IT HAS TO BORN A CELL
; * The changes will take effect in the new GRDDST vector
; INPUT     : D5 NP1, D6 NP2, D4 Offset of the grid vector 
; OUTPUT    : NONE
; MODIFIES  : NONE
; -----------------------------------------------------------------------------   
            MOVEM.L D0-D7,-(A7)
      
            CMP.W   #3,D5
            BEQ     .EXACT3P1
            CMP.W   #3,D6
            BEQ     .EXACT3P2
            BRA     .DEAD
.EXACT3P2         
            CMP.W   #3,D5                   
            BNE     .BORNP2
            BEQ     .COIN                 
            BRA     .DEAD             
.EXACT3P1 
            CMP.W   #3,D6                   
            BNE     .BORNP1
            BEQ     .COIN                 
            BRA     .DEAD
.BORNP1
            MOVE.B  #1,(A1,D4)              ; BORN P1 CELL IF D5 = 3 AND
            BRA     .END                    ; D6 != 3
.BORNP2
            MOVE.B  #2,(A1,D4)              ; BORN P2 CELL IF D6 = 3 AND
            BRA     .END                    ; D5 != 3
.COIN
            JSR     UTLRAND                 ; BORN RANDOM CELL IF D5 = D6 = 3
            MOVE.B  D1,(A1,D4)           
            BRA     .END            
.DEAD
            MOVE.B  #0,(A1,D4)              ; THE CELL CONTINUES WITH THE
                                            ; SAME VALUE 0
.END        MOVEM.L (A7)+,D0-D7
            RTS
            
; -----------------------------------------------------------------------------
COMPP2
; COMPUTES DEPENDING OF NEIGHBOURS IF A P2 CELL SURVIVE
; * The changes will take effect in the new GRDDST vector
; INPUT     : D5 NP1, D6 NP2, D4 Offset of the grid vector 
; OUTPUT    : NONE
; MODIFIES  : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7,-(A7)
            
            MOVE.W  D6,D0                   ; COPY D6 IN D0 FOR NOT LOOSING
            SUB.W   D5,D6           
            CMP.W   #2,D6                   ; NP2-NP1 == 2?
            BEQ     .VALP2
            CMP.W   #3,D6                   ; NP2-NP1 == 3?
            BEQ     .VALP2
            CMP.W   #1,D6                   ; NP2-NP1 == 1?
            BEQ     .NP2M1
            BRA     .DEADCL
.NP2M1
            CMP.W   #2,D0                   ; NP2 >= 2?
            BPL     .VALP2
            BEQ     .VALP2
.DEADCL
            MOVE.B  #0,(A1,D4)              ; THE P2 CELL DIES
            BRA     .END               
.VALP2      
            MOVE.B  #2,(A1,D4)              ; THE P2 CELL SURVIVE                       

.END        MOVEM.L (A7)+,D0-D7
            RTS  
         
; -----------------------------------------------------------------------------
COMPP1
; COMPUTES DEPENDING OF NEIGHBOURS IF A P1 CELL SURVIVE
; * The changes will take effect in the new GRDDST vector
; INPUT     : D5 NP1, D6 NP2, D4 Offset of the grid vector 
; OUTPUT    : NONE
; MODIFIES  : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7,-(A7)
            
            MOVE.W  D5,D0                   ; COPY D5 IN D0 FOR NOT LOOSING
            SUB.W   D6,D5            
            CMP.W   #2,D5                   ; NP1-NP2 == 2?
            BEQ     .VALP1
            CMP.W   #3,D5                   ; NP1-NP2 == 3?
            BEQ     .VALP1
            CMP.W   #1,D5                   ; NP1-NP2 == 1?
            BEQ     .NP1M2
            BRA     .DEADCL
.NP1M2
            CMP.W   #2,D0                   ; NP1 >= 2?
            BPL     .VALP1
            BEQ     .VALP1
.DEADCL
            MOVE.B  #0,(A1,D4)              ; THE P1 CELL DIES
            BRA     .END               
.VALP1
            MOVE.B  #1,(A1,D4)              ; THE P1 CELL SURVIVE                       

.END        MOVEM.L (A7)+,D0-D7
            RTS
            
; -----------------------------------------------------------------------------
COUNTN
; COUNT ALL THE NEIGHBOURS OF A CELL
; * COUNTN diferenciates if it's a P1 neighbour or a P2 neighbour
; INPUT     : D0 current row, D1 current column       
; OUTPUT    : D4 offset current cell, D5 NP1, D6 NP2, D7 cell value
; MODIFIES  : D4, D5, D6, D7
; -----------------------------------------------------------------------------            
            MOVEM.L D0-D3/A2-A3,-(A7)
            
            MOVE.W  #7,D3                   ; D3 = TO LOOP OVER NEIGHBOURS
            LEA     OR,A3                   ; A3 = OFFSET CURRENT ROW VECTOR 
            LEA     OC,A2                   ; A2 = OFFSET CURRENT COL VECTOR
.LOOP 
            ADD.B   (A3),D0                 ; ADD OFSET TO THE CURRENT ROW
            ADD.B   (A2),D1                 ; ADD OFFSET TO THE CURRENT COL
            JSR     GETOFFS                 ; D4 = OFFSET
            JSR     GETCELL                 ; D7 = CURRENT CELL VALUE
            CMP.W   #1,D7                   ; P1?
            BEQ     .ADDP1
            CMP.W   #2,D7                   ; P2?
            BEQ     .ADDP2            
.NEXT       SUB.B   (A3)+,D0                ; RESTORE THE OFFSET  
            SUB.B   (A2)+,D1               
            DBRA    D3,.LOOP 
            BRA     .END
.ADDP1
            ADD.W   #1,D5                   ; ADDS 1 TO NP1
            BRA     .NEXT            
.ADDP2
            ADD.W   #1,D6                   ; ADDS 1 TO NP2
            BRA     .NEXT           
            
.END        MOVEM.L (A7)+,D0-D3/A2-A3
            JSR     GETOFFS                 ; GET OFFSET CURRENT CELL
            JSR     GETCELL                 ; GET VALUE CURRENT CELL
            RTS 
     
; ----------------------------------------------------------------------------- 
GETOFFS
; COMPUTES OFFSET GIVEN ROW AND COLUMN
; * The formula to achieve the offset is = R&(H-1)*W + C&(W-1)
; INPUT     : D0 row, D1 column
; OUTPUT    : D4 offset of the grid vector
; MODIFIES  : D4 
; -----------------------------------------------------------------------------  
            MOVEM.L D0-D3,-(A7)
                 
            AND.W   #GRDHEIGH-1,D0          ; D0 = R&(H-1)    
            LSL.W   #GRDSHWID,D0            ; D0 = R&(H-1)*W
            AND.W   #GRDWIDTH-1,D1          ; D1 = C&(W-1)
            ADD.L   D1,D0      
            MOVE.L  D0,D4                   ; D4 = D1 + D0
      
            MOVEM.L (A7)+,D0-D3
            RTS  
        
; -----------------------------------------------------------------------------                               
GETCELL
; GETS THE VALUE OF A CELL
; INPUT     : D4 offset, A0 pointer to a grid vector 
; OUTPUT    : D7 value of the cell
; MODIFIES  : D7
; -----------------------------------------------------------------------------
            MOVE.B  (A0,D4),D7
            RTS
            
; -----------------------------------------------------------------------------                        
;DEFINE OR AND OC VECTORS
OR          DC.B    -1,-1,-1,0,0,1,1,1     
OC          DC.B    -1,0,1,-1,1,-1,0,1       
             
; -----------------------------------------------------------------------------
GRDSAVE
; SAVES THE GRID INTO A FILE IN CSV FORMAT
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            MOVE.L  #1,D1                   ; DISPLAY SAVE DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #52,D0                  ; CREATE NEW FILE
            TRAP    #15
            TST.W   D0                      ; CHECK CREATION ERROR
            BNE     .END                    ; DO NOTHING MORE IF ERROR
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; A0: POINTER TO THE DATA TO WRITE
            MOVE.W  #GRDHEIGH-1,D3          ; D3: NUMBER OF ROWS - 1
.LOOPY      MOVE.W  #GRDWIDTH-1,D2          ; D2: NUMBER OF COLUMNS - 1
.LOOP       MOVE.B  #'0',D0                 ; ADD CHAR '0' AND THE CELL VALUE
            ADD.B   (A0)+,D0
            MOVE.B  D0, (A6)+               ; STORE IT IN THE BUFFER
            MOVE.B  #',',(A6)+              ; NOW PUT THE COMMA
            DBRA.W  D2,.LOOP
            MOVE.B  #$0D,-1(A6)             ; STORE CARRIAGE RETURN (REMOVE ',')
            MOVE.B  #$0A,(A6)               ; STORE LINE FEED
            MOVE.B  #54,D0                  ; WRITE TO FILE TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO WRITE
            TRAP    #15                     ; WRITE (A1 IS ALREADY THERE)
            MOVE.L  A1,A6                   ; GO BACK TO THE BUFFER START
            DBRA.W  D3,.LOOPY
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO SAVE',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

; -----------------------------------------------------------------------------
GRDLOAD
; LOADS THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            MOVE.W  #GRDHEIGH-1,D3
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #GRDWIDTH-1,D2
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            MOVE.B  D0,(A0)+                ; STORE DATA
            ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

; -----------------------------------------------------------------------------
GRDLLEFT
; LOADS THE LEFT PART OF THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; NOTE     : ALL THE ACTIVE CELLS ARE STORED AS PLAYER 1 INDEPENDLY OF THEIR
;            ACTUAL VALUE.
; -----------------------------------------------------------------------------

            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            
            MOVE.W  #GRDHEIGH-1,D3
            
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #GRDWIDTH-1,D2
            LSR.W   #1,D2                   ; ONLY HALF OF ITERATIONS
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.W   #0,D0
            BEQ     .ZERO
            MOVE.B  #1,(A0)+                ; ONLY P1 STORE DATA
            BRA     .CONT
.ZERO       MOVE.B  D0,(A0)+            
.CONT       ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            LEA     32(A0),A0               ; SKIP RIGHT SIDE OF THE WRITE GRID
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0
         
; -----------------------------------------------------------------------------
GRDLRGT
; LOADS THE RIGHT PART OF THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; NOTE     : ALL THE ACTIVE CELLS ARE STORED AS PLAYER 2 INDEPENDLY OF THEIR
;            ACTUAL VALUE.
; -----------------------------------------------------------------------------

            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            
            MOVE.W  #GRDHEIGH-1,D3
            
            
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #GRDWIDTH-1,D2
            LSR.W   #1,D2                   ; ITERACIONES MITAD GRID COLUMNAS
            LEA     64(A1),A1               ; SKIP LEFT SIDE OF THE READ GRID
            LEA     32(A0),A0               ; SKIP LEFT SIDE OF THE WRITE GRID  
.COPY             
            MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.W   #0,D0
            BEQ     .ZERO
            MOVE.B  #2,(A0)+
            BRA     .CONT                        
.ZERO       MOVE.B  D0,(A0)+                ; STORE DATA
.CONT       ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0
; -----------------------------------------------------------------------------
GRDPLOT
; PLOTS THE GRID
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0,-(A7)
            MOVE.W  #GRDWIDTH,D5            ; D5 = COLUMNS
            MOVE.W  #GRDHEIGH,D6            ; D6 = ROWS
           
            ;DRAW HORIZONTALS
            ;SET COLOR
            MOVE.B  #80,D0
            MOVE.L  #CLRDKGRN,D1
            TRAP    #15
            ;SET PEN WIDTH    
            MOVE.B  #93,D0
            MOVE.B  #1,D1
            TRAP    #15
            ;DRAW HORIZONTAL LINES
            MOVE.W  #GRDYOFF,D2             ; D1 = XLEFT
            MOVE.W  #GRDYOFF,D4             ; D2 = YLEFT
.HOR        MOVE.B  #84,D0                  ; D3 = XRIGHT
            MOVE.W  #GRDXOFF,D1             ; D4 = YRIGHT                                
            MOVE.W  #GRDXOFF+GRDPXWID,D3                                   
            TRAP    #15
            ADD.W   #GRDSZCEL,D2            ; NEXT HORIZONTAL LINE            
            ADD.W   #GRDSZCEL,D4              
            DBRA    D6,.HOR
            
            ;DRAW VERTICAL LINES
            MOVE.W  #GRDXOFF,D1             ; D1 = XTOP
            MOVE.W  #GRDXOFF,D3             ; D2 = YTOP
.VERT       MOVE.B  #84,D0                  ; D3 = XBOT
            MOVE.W  #GRDYOFF,D2             ; D4 = YBOT                                
            MOVE.W  #GRDYOFF+GRDPXHEI,D4                                   
            TRAP    #15
            ADD.W   #GRDSZCEL,D1            ; NEXT VERTICAL LINE           
            ADD.W   #GRDSZCEL,D3           
            DBRA    D5,.VERT
                        
            ;DRAW CELLS
            ;SET PEN WIDTH
            MOVE.B   #93,D0
            MOVE.B   #0,D1
            TRAP     #15
            ;PREPARE COORD
            MOVE.L  #GRDDST,A0              ; A0 = POINTING TO THE GRID
            MOVE.L  (A0),A0                 ; THAT IT HAS TO BE PLOTTED
            MOVE.W  #GRDHEIGH*GRDWIDTH-1,D6 ; D6 = TO LOOP OVER THE GRID
            MOVE.W  #GRDXOFF+1,D1           ; D1 = XLEFT
            MOVE.W  #GRDYOFF+1,D2           ; D2 = YTOP
            MOVE.W  #GRDXOFF+GRDSZCEL-1,D3  ; D3 = XRIGHT
            MOVE.W  #GRDYOFF+GRDSZCEL-1,D4  ; D4 = YBOT


LOOPCL
            CMP.B   #1,(A0)                 ; (A0) == 1 -> DRAWP1
            BEQ     DRAWP1                  ; (A0) == 2 -> DRAWP2                                    
            CMP.B   #2,(A0)                 ; (A0) == 0 -> DRAWDEAD
            BEQ     DRAWP2
            CMP.B   #0,(A0)
            BEQ     DRAWDED
NEXTCL      CMP.W   #GRDPXWID+GRDXOFF,D3    ; IF XRIGHTCELL > XRIGHTGRD
            BPL     RESETC                  ; THEN RESETC 
            MOVE.B  (A0)+,D7                ; NEXT CELL     
            DBRA    D6,LOOPCL
            BRA     DRAWCONT            

DRAWP1
            ;SET FILL COLOR
            MOVE.W  D1,-(A7)
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            ;SET PEN COLOR
            MOVE.B  #80,D0
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            MOVE.W  (A7)+,D1
            ;DRAW CELL
            MOVE.B  #87,D0
            TRAP    #15
            ADD.W   #GRDSZCEL,D1            ; NEXT CELL IN X AXIS
            ADD.W   #GRDSZCEL,D3            
            BRA     NEXTCL                   
            
DRAWP2
            ;SET FILL COLOR
            MOVE.W  D1,-(A7)
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            ;SET PEN COLOR
            MOVE.B  #80,D0
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            MOVE.W  (A7)+,D1
            ;DRAW CELL
            MOVE.B  #87,D0
            TRAP    #15
            ADD.W   #GRDSZCEL,D1            ; NEXT CELL IN X AXIS
            ADD.W   #GRDSZCEL,D3
            BRA     NEXTCL      

DRAWDED 
            ADD.W   #GRDSZCEL,D1            ; NEXT CELL IN X AXIS
            ADD.W   #GRDSZCEL,D3
            BRA     NEXTCL

RESETC
            MOVE.W  #GRDXOFF+1,D1           ; D1 = XLEFT, RESET
            ADD.W   #GRDSZCEL,D2            ; D2 = YTOP, NEXT ROW
            MOVE.W  #GRDXOFF+GRDSZCEL-1,D3  ; D3 = XRIGHT, RESET                        
            ADD.W   #GRDSZCEL,D4            ; D4 = YBOT, NEXT ROW
            BRA     NEXTCL
DRAWCONT
            CLR.L   D5                      ; D5 = P1 TOTAL CELLS COUNTER
            CLR.L   D6                      ; D6 = P2 TOTAL CELLS COUNTER
            MOVE.W   #GRDHEIGH*GRDWIDTH-1,D4 ; D4 = TO LOOP OVER THE GRID
            MOVE.L  #GRDDST,A0              ; A0 = POINTING TO THE GRID
            MOVE.L  (A0),A0                 ; THAT IT HAS TO BE PLOTTED
            
            
.LOOP       CMP.B   #1,(A0)                 ; (A0) == 1 -> ADDP1
            BEQ     .ADDP1                  ; (A0) == 2 -> ADDP2
            CMP.B   #2,(A0)
            BEQ     .ADDP2                   
.NEXT       MOVE.B  (A0)+,D7       
            DBRA    D4,.LOOP
            BRA     PLOTCOUN
.ADDP1
            ADD.B   #1,D5                   ; ADDS 1 TO THE P1 COUNTER
            BRA     .NEXT                  
.ADDP2
            ADD.B   #1,D6                   ; ADDS 1 TO THE P2 COUNTER
            BRA     .NEXT
            
PLOTCOUN    
            ;PLOT PLAYER 1 COUNTER
            MOVE.W  D5,(GRDNPLR1)           ; MOVE TO GRDNPLR1 THE P1 RECOUNT             
            ;SET PEN COLOR
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            ;SET COORD            
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP1X<<8|GRDSCP1Y,D1
            TRAP    #15
            ;PLOT COUNTER            
            MOVE.B  #20,D0
            MOVE.W  (GRDNPLR1),D1
            MOVE.B  #5,D2
            TRAP    #15
                              
            
            ;PLOT PLAYER 2 COUNTER
            MOVE.W  D6,(GRDNPLR2)           ; MOVE TO GRDNPLR2 THE P2 RECOUNT 
            ;SET PEN COLOR
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            ;SET COORD
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP2X<<8|GRDSCP2Y,D1
            TRAP    #15
            ;PLOT COUNTER 
            MOVE.B  #20,D0
            MOVE.W  (GRDNPLR2),D1
            MOVE.B  #5,D2
            TRAP    #15
            
            ;PLOT '*'            
            SUB.W   D5,D6
            BEQ     .ASTPP                  ; P1C == P2C -> ASTPP               
            BPL     .ASTP2                  ; P2C > P1C -> ASTP2                                                           
.ASTP1                                      ; P1C > P2C -> ASTP1
            ;SET PEN COLOR                                                  
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            ;SET COORD            
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP1X<<8|GRDSCP1Y-1,D1
            TRAP    #15 
            ;PLOT '*'            
            MOVE.B  #6,D0
            MOVE.B  #42,D1
            TRAP    #15 
            BNE     .GEN
            
.ASTPP      ;PLOT 2 '*'
            ;SET PEN COLOR P1
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            ;SET COORD P1
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP1X<<8|GRDSCP1Y-1,D1
            TRAP    #15 
            ;PLOT '*' P1
            MOVE.B  #6,D0
            MOVE.B  #42,D1
            TRAP    #15 
            ;SET PEN COLOR P2
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            ;SET COORD P2
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP2X<<8|GRDSCP2Y-1,D1
            TRAP    #15 
            ;PLOT '*' P2
            MOVE.B  #6,D0
            MOVE.B  #42,D1
            TRAP    #15
            BRA     .GEN            
             
            
.ASTP2 
            ;SET PEN COLOR     
            MOVE.B  #81,D0
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            ;SET COORD
            MOVE.B  #11,D0
            MOVE.L  #GRDSCP2X<<8|GRDSCP2Y-1,D1
            TRAP    #15 
            ;PLOT '*'            
            MOVE.B  #6,D0
            MOVE.B  #42,D1
            TRAP    #15
            
.GEN        ;GENERATIONS COUNTER
            ;SET PEN COLOR
            MOVE.B  #81,D0
            MOVE.L  #CLRLTGRN,D1
            TRAP    #15
            ;SET COORDS            
            MOVE.B  #11,D0
            MOVE.L  #GRDSCNGX<<8|GRDSCNGY,D1
            TRAP    #15
            ;PLOT            
            MOVE.B  #20,D0
            CLR.L   D1
            MOVE.W  (GRDNGEN),D1
            MOVE.B  #5,D2
            TRAP    #15
            
            MOVEM.L (A7)+,D0-D7/A0
            RTS











































*~Font name~Fixedsys~
*~Font size~18~
*~Tab type~0~
*~Tab size~4~
