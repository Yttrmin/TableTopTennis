; Table Top Tennis Simulator 2012

	processor 6502
	include vcs.h
	org $F000

;Constants
BGColor = $48
PFColor = $34
P0Color = $C6 ; Green
P1Color = $94 ; Blue
BallColor = $0E ; White
PF0Sprite = %00110000
PaddleOnSprite = %00011000
PaddleOffSprite = %00000000
BallOn = %00000010
BallOff = %00000000
PaddleHeight = 16
BallHeight = 2
MaxPaddleY = 186-PaddleHeight
MinPaddleY = 14
P1Goal = $33; 100% Correct. Looked at wrong var. ; One cycle before playfield goal.
P0Goal = $C2; 100% Correct. Looked at wrong var. ; One cycle before playfield goal.
BallStartX = $7A
BallStartY = 96
BallBaseTone = %00000001
BallXSpeedCap = 2 ; !Exceeding the paddle width can cause tunneling!
BallYSpeedCap = 3
BallYExVelMax = BallYSpeedCap+1
BallYExVelMin = 255-BallYSpeedCap
BallVolleyIncrement = 2
AITickRate = 2
ScoreLimit = 11
StartingWaitTime = 255
EndWaitTime = 80

;Variables
; 2600 has 128 bytes of RAM, so we get $80 to $FF.
YPosP0 = $80
YPosP1 = $81
YPosBall = $82
ScoreP0 = $83
ScoreP1 = $84
P0Sprite = $85 ; Written by the processing kernel, loaded and stored by the draw kernel.
P1Sprite = $86 ; Could probably be done just on the stack, but we got all this RAM!
BallEnabled = $87
YVelBall = $88
XVelBall = $89
XPosBall = $8A
P0Delta = $8B ; Either 1 or -1 to specify whether the player's paddle went up or down this frame.
P1Delta = $8C ; Exists just so we can do multiple things based on moving Up/Down without redoing the BIT test.
VolleyCount = $8D
ScoreP0MemLoc = $8E ; Helper variable to store the offset from Numbers of the byte to draw.
ScoreP1MemLoc = $8F ; Exists because A/X/Y are occupied and saves us from having to ASL(x4), ADC, and TAY every time.
AITicks = $90
VictoryTime = $91
WaitTime = $92
NewXVelBall = $93

Start
	SEI ; Disable interrupts.
	CLD ; Clear BCD math bit.
	LDX #$FF ; Reset stack pointer to FF.
	TXS
	LDA #0
ClearMem
	; Clear all memory from $FF to $00 with 0s.
	STA 0,X
	DEX
	BNE ClearMem
Initialize
	LDA #BGColor
	STA COLUBK
	LDA #PFColor
	STA COLUPF
	LDA #P0Color
	STA COLUP0
	LDA #P1Color
	STA COLUP1
	LDA %00001111
	STA AUDV0 ; Crank the volume up.
	STA AUDV1
	LDA %00000110
	STA AUDF1
PositionPaddles ; DO NOT TOUCH
	STA WSYNC
	; ~22 Machine cycles of horizontal blank.
	; First we do P0's paddle.
	NOP ; NOPs take 2 cycles.
	NOP
	NOP
	BIT ScoreP0 ; BIT takes 3, literally just a garbage statement to burn 3 cycles.
	NOP
	NOP
	NOP
	NOP ; Kill horizontal blank.
	NOP 
	NOP ; 21 Machine cycles here.
	STA RESP0 ; STA takes 3, so our paddle's set at the 24th cycle.
	NOP ; Now for P1's paddle...
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	BIT ScoreP0
	STA RESBL ; Unused. Kept just to maintain cycle count.
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP 
	STA RESP1 ; Now for more fine tuned adjustment...
	LDA #%01110000
	STA HMP1
	STA WSYNC
	STA HMOVE ; Shift it 7 to the left...
	LDA #%00010000
	STA HMP1
	STA WSYNC
	STA HMOVE ; And 1 more to the left and perfect!
	STA HMCLR
	; This could probably be cleaned up without HMOVE, but never touch it again.
	LDA #96
	STA YPosP0
	STA YPosP1
	STA YPosBall
	JSR ResetBall ; Setup ball.
	LDA #0
	STA XVelBall
	STA YVelBall
	LDA #StartingWaitTime
	STA WaitTime ; Give the player some breathing time to start.
	STA WSYNC
	STA WSYNC

EndInitialize
MainLoop
Synching
	LDA #%00000010
	STA VSYNC
	STA WSYNC ; Need to hold the VSync signal for at least 3 scanlines.
	STA WSYNC
	STA WSYNC
	; 2798 cycles to burn divided by 64 = 43. 
	; 64 is the number of cycles it takes for the timer to tick down.
	; It's best to use a timer here since otherwise you'll have to manually count
	; the cycles and WSYNC in the middle of your processing when appropriate.
	LDA  #43
	STA  TIM64T
	; Zero out VSync since it's over.
	LDA #0
	STA VSYNC ; Actually start at scanline 0 here.
	; There's actually some extra "visible" scanlines on the top and bottom that are unused due to
	; vertical blank/overscan, at least on Stella, but I assume that's just to avoid drawing on the
	; edges for real TVs, where what's visible can differ from one set to the other.
FinishSynch
BeginInput
	LDA #0
	STA AUDC0 ; Turn off any ricochet or scoring sound effects.
	STA P0Delta ; Reset paddle movement deltas.
	STA P1Delta
	LDA VictoryTime
	BNE EndInput
P0Up
	LDA #%00010000
	BIT SWCHA
	BNE P0Down
	INC YPosP0 ; Always increment/decrement paddle positions by 2. Only every other scanline changes the graphics registers,
			   ; so if we only move it by 1 the paddle will seem to shrink/grow as it moves up and down.
	INC YPosP0
	LDA #1 ; Regardless of the actual change in position though the delta is always set to 1 or -1.
	STA P0Delta
P0Down
	LDA #%00100000
	BIT SWCHA
	BNE P1Up
	DEC YPosP0
	DEC YPosP0
	LDA #-1
	STA P0Delta
P1Up
	LDA #%00000001
	BIT SWCHA
	BNE P1Down
	;INC YPosP1
	;INC YPosP1
	;LDA #1
	;STA P1Delta
P1Down
	LDA #%00000010
	BIT SWCHA
	BNE EndInput
	;DEC YPosP1
	;DEC YPosP1
	;LDA #-1
	;STA P1Delta
EndInput
BeginCollision
P0Playfield ; Test for Paddle-on-Playfield collisions so they don't move outside the bounds of the game.
	LDA #%10000000 ; CXP0FB (P0->PF)
	BIT CXP0FB
	BEQ P1Playfield
	PHA ; Push return value. Garbage value.
	LDA YPosP0
	PHA ; Push parameter.
	JSR CapToMinMax ; If we're touching the playfield, cap us!
	PLA ; Pop parameter off.
	PLA ; Pop return value into accumulator.
	STA YPosP0 ; Store to actual variable.
P1Playfield ; Repeat for P1.
	LDA #%10000000 ; CXP1FB (P1->PF)
	BIT CXP1FB
	BEQ PlayerBallCheck
	PHA
	LDA YPosP1
	PHA
	JSR CapToMinMax
	PLA
	PLA
	STA YPosP1
PlayerBallCheck ; Check if we need to bounce the ball off a paddle.
	LDA WaitTime
	BEQ SkipWaitCheck
	DEC WaitTime
	LDA WaitTime
	CMP #EndWaitTime
	BNE SkipBallPhysics
	JMP ClearWait
SkipBallPhysics
	JMP EndCollision
ClearWait
	LDA #0
	STA WaitTime
	JSR ResetBall
SkipWaitCheck
	LDA P0Delta
	PHA ; Push P0's delta onto the stack.
	LDA #%01000000 ; CXP0FB (P0->BL)
	BIT CXP0FB
	BNE PlayerBallConfirmed ; If there's a hit between P0 and the PF, branch with P0's delta still on the stack.
	PLA ; Else, pop it off and put P1's delta in its place.
	LDA P1Delta
	PHA
	LDA #%01000000
	BIT CXP1FB
	BNE PlayerBallConfirmed ; If there's a hit between P1 and the PF, branch with P1's delta on the stack.
	PLA ; Else there were no hits, pop it off stack so we don't overflow and JMP to the next collision test.
	JMP BallPlayfield
PlayerBallConfirmed ; Only executed if any of the paddles hit the ball.
	INC VolleyCount
	LDA VolleyCount
	CMP #BallVolleyIncrement
	BNE BallVelChanges
BallVelChanges
	LDA XVelBall
	CLC
	EOR #$FF
	ADC #1
	STA XVelBall ; Here's where that stack variable comes into play. The delta of whoever hit the ball is on the stack, although
	PLA			 ; we don't actually know which player it was at this point. It doesn't matter though, we pop the delta off,
	CLC			 ; clear the carry, and add it to the YVelocity. This could either slow or speed up the ball's Y speed.
	ADC YVelBall ; This is how applying "spin" to the ball is done. If you move while hitting the ball, all this happens.
	CMP #BallYExVelMax
	BEQ CapBallToUpper
	CMP #BallYExVelMin
	BEQ CapBallToLower

	CMP #0
	JMP BallZeroYCheck
CapBallToUpper
	LDA #BallYExVelMax-1
	STA YVelBall
	JMP PRSound
CapBallToLower
	LDA #BallYExVelMin+1
	STA YVelBall
	JMP PRSound
BallZeroYCheck
	BNE PRSound ; We don't want a YVel of 0 (ball going horizontally straight). If it ever happens, just make it 1.
	LDA #1		; Partially because it makes the AI look dumb.
	JMP PRSound
PRSound ;PlayRicochetSound.
	STA YVelBall
	LDA #BallBaseTone
	STA AUDC0
	; TODO, adjust frequency based on speed?
BallPlayfield ; Ball-on-Playfield tests. Could mean it either hit a wall or hit a goal.
	LDA #%10000000
	BIT CXBLPF
	BEQ EndCollision
	; Collision with the playfield, here we go.
	; The test is basically: If XPosBall < P0Goal, we're in P0's goal. Else If XPosBall > P1Goal, we're in P0's goal.
	; Else we hit a wall.
TestBallP0
	LDA XPosBall
	CMP #P0Goal
	BCC TestBallP1
	; We're in P0's Goal!
	LDA #1 ; P1 scored.
	PHA ; Push it onto the stack as a parameter for OnScore.
	JSR OnScore
	PLA
	JMP EndCollision
TestBallP1 ; Repeat for P1. Could these be combined into 1
	CMP #P1Goal
	BCS BallRicochet
	; We're in P1's Goal!
	LDA #-1 ; P0 scored.
	PHA
	JSR OnScore
	PLA
	JMP EndCollision
BallRicochet ; Didn't hit a player, guess we hit a wall.
	LDA YVelBall
	CLC
	EOR #$FF ; Just flip the value and play a sound.
	ADC #1
	STA YVelBall
	LDA #BallBaseTone
	STA AUDC0
EndCollision
	STA CXCLR ; Clear the collision registers.
	LDA YPosBall
	CLC
	ADC YVelBall
	STA YPosBall ; Add velocity to position and store it as the new position.
	LDA XVelBall ; Set the ball's horizontal speed to XVelBall.
	STA HMBL
	STA WSYNC ; Always sync before an HMOVE!
	STA HMOVE
	; Now to calculate the new X position of the ball.
	; Need to perform 4 arithmetic shifts right since XVel 1) Only uses the left nibble and 2) could be negative.
	; But the 6502 doesn't have that! So first CMP it to %10000000 to copy the sign bit into the carry bit.
	; Then rotate right, which replaces the leftmost-bit with the carry bit.
	CMP #$80
	ROR
	CMP #$80
	ROR
	CMP #$80
	ROR
	CMP #$80
	ROR
	ADC XPosBall ; Now add that velocity to the position and we get our new position.
	STA XPosBall
	LDA #$00
	STA COLUBK ; Reset background color.
	LDA %00000001 ; Turn off Player coloring and go back to mirroring the playfield.
	STA CTRLPF
	LDX #0
	LDA ScoreP0
	; Wow it makes a lot more sense to do this here. Who'd a thunk.
	ASL ; Each number graphic is made up of 8 bytes, so multiply our score by 8 to get the memory address of the number we want.
	ASL
	ASL
	STA ScoreP0MemLoc ; And store it so we can just INC it instead of doing all this again.
	LDA ScoreP1
	ASL
	ASL
	ASL
	STA ScoreP1MemLoc
	LDA YPosBall ; Locks the paddles to the ball so they never miss. For testing.
	;STA YPosP0
	;STA YPosP1
ScoreCheck
	LDA VictoryTime
	BNE StillWinning
	LDA ScoreP0
	CMP #ScoreLimit
	BEQ P0Won
	LDA ScoreP1
	CMP #ScoreLimit
	BEQ P1Won
	JMP AICheck
P0Won
	INC ScoreP0
	LDA #255
	STA VictoryTime
	JMP StillWinning
P1Won
	INC ScoreP1
	LDA #255
	STA VictoryTime
	JMP StillWinning
StillWinning
	JSR OnWin
	LDA VictoryTime
	BNE WaitForVBlankEnd
	LDA #0
	STA AUDC1
	JMP Start
AICheck
	LDA AITicks
	CMP #AITickRate
	BEQ AIStart
	JMP AIEnd
AIStart
	LDA #0
	STA AITicks
	LDA YPosP1
	CMP YPosBall
	BEQ AIEnd
	BCS AIDown
	INC YPosP1
	INC YPosP1
	JMP AIEnd
AIDown
	DEC YPosP1
	DEC YPosP1
AIEnd
	INC AITicks
; Kill whatever time might be left.
WaitForVBlankEnd
	LDA INTIM
	BNE WaitForVBlankEnd
	STA WSYNC ; WSYNC so we don't enable drawing mid-way into the line.
	STA VBLANK
	LDY #192 ; Note we only actually loop 182 times, but we're counting down from 192.
ScanLoop
	; Important: For the 182 lines there are two separate kernels.
	; On even numbered scanlines, there's the "processing" kernel.
	; This performs all the calculations for determining if the paddles/ball are visible on this line and need to be drawn.
	; It writes these values to several global variables.
	; On odd numbered scanlines, there's the "draw" kernel.
	; It simply loads in those variables and saves them to the graphics registeres. It sounds weird and roundabout, but there's
	; far far far too little time to perform both kernels' functions on one scanline.
	; The fact that the graphics registers are only updated on odd scanlines has a lot of implications!
	STA WSYNC
ProcessingLine
	TYA
	SEC ; Have to set carry because SBC uses the not of the carry.
		; Meaning you otherwise get things like $60 - $60 = $FF
		; This causes a weird bug where paddles can shift the other around by 1 line.
	SBC YPosP0
	BMI DisableP0 ; Basically: if (CurrentScanline - YPosP0) < 0 : Turn off paddle
	CMP #PaddleHeight ; else if (CurrentScanline - YPosP0) >= PaddleHeight : Turn off paddle.
	BCS DisableP0	  ; else : Enable paddle.
	LDA #PaddleOnSprite
	STA P0Sprite
	JMP P1Check
DisableP0
	LDA #PaddleOffSprite
	STA P0Sprite
P1Check ; Repeat for P1...
	TYA
	SEC
	SBC YPosP1
	BMI DisableP1
	CMP #PaddleHeight
	BCS DisableP1
	LDA #PaddleOnSprite
	STA P1Sprite
	JMP BallCheck
DisableP1
	LDA #PaddleOffSprite
	STA P1Sprite
BallCheck ; And the ball...
	LDA VictoryTime
	BNE DisableBall
	TYA
	SEC
	SBC YPosBall
	BMI DisableBall
	CMP #BallHeight
	BCS DisableBall
	LDA #BallOn
	STA BallEnabled
	JMP EndLineChecks
DisableBall
	LDA #BallOff
	STA BallEnabled
EndLineChecks 
EndProcessingLine
DrawLine ; All we pretty much do here is load in the processing kernel's results and store them in the graphics registers.
	DEY  ; We don't just do this in the processing kernel because then the graphics would change mid-scanline.
		 ; We also adjust the playfield graphics here.
	STA WSYNC ; Sync to draw kernel line.
	LDA Playfield0,Y ; Save some horizontal blank time.
	STA COLUPF ; The color of the playfield is just PF0's current graphic. Yeah.
	STA PF0
	LDA Playfield1,Y
	STA PF1
	STA PF2
	LDA P0Sprite
	STA GRP0
	LDA BallEnabled
	STA ENABL ; Have to do it before PF1/2 or there isn't enough time.
	LDA P1Sprite
	STA GRP1
	; Subtract 1 off our line counter.
	DEY
	CPY #10
	; Loop for the next scanline.
	BNE ScanLoop ; All finished within the horizontal blank.
ScoreDrawLine ; Starts on the 10th remaining visible scanline. Draws the score for each player.
	LDA #0
	STA WSYNC
	LDA Playfield0,Y
	STA COLUBK ; Set the background color to the color of playfield so we can free it up to be used for the numbers.
	LDA #0
	STA GRP0 ; Turn off alllllll graphics, including the playfield since the background now takes its place.
	STA GRP1
	STA ENABL
	STA PF0
	STA PF2
	STA PF1
	STA WSYNC
	LDA %00000010
	STA CTRLPF ; Turn on score coloring and duplication of the left half of the playfield (instead of mirroring).
	LDX #8
ScoreLoop ; The actual number drawing loop. X counts from 0 to 8 and branches on 9.
	STA WSYNC
	LDA ScoreP0MemLoc
	TAY
	LDA Numbers,Y
	STA PF1
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	LDA ScoreP1MemLoc
	TAY
	LDA Numbers,Y
	STA PF1
	INC ScoreP0MemLoc
	INC ScoreP1MemLoc
	DEX
	BEQ EndScore
	JMP ScoreLoop
EndScore
	LDA #0
	STA WSYNC
	STA PF1
	STA PF0
	STA PF2
	; Get ready to set D1 bit for VBlank.
	LDA #2
	; Wait for final line to finish first though.
	STA WSYNC
	; Turn off drawing for overscan.
	STA VBLANK
;************************************************************
	; We get 30 lines of overscan.
	; Why not use a timer like the vertical blank?
	LDY #29
; Y=$08 is first scanline of bottom border.
; Y=$07 is first scanline of brown part of it.
OverScanWait
	; Wait for line to finish...
	STA WSYNC
	; Decrement and loop.
	DEY
	BNE OverScanWait
	; Back to main.
	JMP MainLoop
; < Return Address > -> ToCap -> Min -> Max -> RetVal
; int CapToMinMax(byte ToCap)
ToCap = $03
CapRetVal = $04
CapToMinMax
	TSX
	LDA #96 ; We've collided, so figure out if we're at min or max.
	CMP ToCap,X ; If C is set, YPosP0 < 96
	BCS CapMin
	JMP CapMax
CapMin
	LDA #MinPaddleY
	CMP ToCap,X
	BCC CapReturn
	STA ToCap,X
	JMP CapReturn
CapMax
	LDA #MaxPaddleY
	CMP ToCap,X
	BCS CapReturn
	STA ToCap,X
CapReturn
	LDA ToCap,X
	STA CapRetVal,X
	RTS
; Increments score for player and resets ball. Plays sound as well?
; Ball should shoot towards which player?
; void OnScore(byte PlayerWhoScored)
PlayerWhoScored = $03
OnScore
	TSX
	LDA PlayerWhoScored,X
	CMP #-1
	BEQ P0Scored
P1Scored
	INC ScoreP1
	JMP PostScored
P0Scored
	INC ScoreP0
PostScored
	; Subtract one from PlayerWhoScored ASL and set as HM?
	JSR ResetBall
	LDA #0
	STA XVelBall
	STA YVelBall
	TSX
	LDA PlayerWhoScored,X
	ASL
	ASL
	ASL
	ASL
	STA XVelBall
	STA NewXVelBall
	LDA #%00001000
	STA AUDC0
	LDA #StartingWaitTime
	STA WaitTime
	LDA #0
	STA XVelBall
	STA YVelBall
	RTS
ResetBall
	LDA ScoreP0
	STA WSYNC
	NOP ; NOPs take 2 cycles.
	NOP
	NOP
	BIT ScoreP0 ; BIT takes 3, literally just a garbage statement to burn 3 cycles.
	NOP
	NOP
	NOP
	NOP ; Kill horizontal blank.
	NOP 
	NOP ; 21 Machine cycles here.
	STA ScoreP0 ; STA takes 3, so our paddle's set at the 24th cycle.
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	BIT ScoreP0
	STA RESBL ; 1 EXTRA CYCLE AH?!
	LDA #BallStartX
	STA XPosBall
	LDA #BallStartY
	STA YPosBall
	LDA ScoreP0
	CLC
	ADC ScoreP1
	TAY
	LDA StartingYVelTable,Y
	STA YVelBall
	LDA NewXVelBall
	BNE SkipResetXVel
	LDA #%00010000
SkipResetXVel
	STA XVelBall
	LDA #0
	STA VolleyCount
	RTS
; void OnWin()
OnWin
	LDA #%00001000
	STA AUDC1
	DEC VictoryTime
	BNE OnWinReturn
	LDA #0
	STA AUDC1
OnWinReturn
	RTS
Playfield0
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %00110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
	.byte %11110000
Playfield1
Playfield2
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
Numbers
Zero
	.byte %00000111
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000111
One
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
Two
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000010
	.byte %00000010
	.byte %00000100
	.byte %00000100
	.byte %00000111
Three
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000111
Four
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
Five
	.byte %00000111
	.byte %00000100
	.byte %00000100
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000111
Six
	.byte %00000100
	.byte %00000100
	.byte %00000100
	.byte %00000100
	.byte %00000111
	.byte %00000101
	.byte %00000101
	.byte %00000111
Seven
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
Eight
	.byte %00000111
	.byte %00000101
	.byte %00000101
	.byte %00000111
	.byte %00000101
	.byte %00000101
	.byte %00000101
	.byte %00000111
Nine
	.byte %00000111
	.byte %00000101
	.byte %00000101
	.byte %00000111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
Ten
	.byte %00010111
	.byte %00010101
	.byte %00010101
	.byte %00010101
	.byte %00010101
	.byte %00010101
	.byte %00010101
	.byte %00010111
Eleven
	.byte %00010100
	.byte %00010100
	.byte %00010100
	.byte %00010100
	.byte %00010100
	.byte %00010100
	.byte %00010100
	.byte %00010100
Win
	.byte %10101001
	.byte %10101010
	.byte %10101010
	.byte %10101010
	.byte %10101010
	.byte %10101010
	.byte %10101010
	.byte %01001001
StartingYVelTable ; Picks a "random" Y direction for the ball.
	.byte %00000001
	.byte %11111111
	.byte %11111111
	.byte %00000000
	.byte %00000001
	.byte %00000001
	.byte %11111111
	.byte %11111111
	.byte %00000001
	.byte %11111111
	.byte %00000000
	.byte %00000001
	.byte %11111111
	.byte %00000001
	.byte %11111111
	.byte %00000000
	.byte %00000001
	.byte %00000000
	.byte %00000001
	.byte %11111111
;************************************************************   
; Special memory locations. Tells the 6502 where to go.
	org $FFFC
	.word Start
	.word Start