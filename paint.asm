
; the file to store in begin
%define 	BOARD_FILE		'board.txt'

; represent stuff
%define		WALL_CHAR '#'
%define     PLAYER_CHAR '.'
%define		PRINT_ONE '@'
%define		PRINT_TWO '+'
%define		PRINT_THREE '$'
%define		PRINT_FOUR '*'
%define		PRINT_FIVE '~'
%define		EMPTY_CHAR ' '


; the size of screen
%define		HEIGHT		30
%define		WIDTH		50

; start position
%define		STARTX 1
%define		STARTY 1

; key to do stuff
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define	CHANGECOLORCHAR 'j'
%define CHANGESIGNCHAR 'k'
%define	PRINTIT 'o'
%define DELETEIT 'p'

segment .data

	; used to fopen() board file
	board_file			db BOARD_FILE,0

	; use to change the terminal mode
	mode_r db "r",0
	raw_mode_on_cmd db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; beginning print
	help_str1		db		13,10, "Controls Button : ", 13, 10,0


	help_str2		db		13,10, "[ " , \
							UPCHAR, " = UP ] - [ ",  \
							LEFTCHAR, " = LEFT ] - [ ", \
							DOWNCHAR, " = DOWN ] - [ ", \
							RIGHTCHAR, " = RIGHT ]", \
							13, 10, 0

	help_str3		db		13,10, "[ ",  CHANGECOLORCHAR, " = CHANGE COLOR ] - [ ", \
							CHANGESIGNCHAR, " = CHANGE SIGN ] - [ ", \
							PRINTIT, " = PRINT CHAR ] - [ ", \
							DELETEIT, " = DELETE CHAR ] - [ ", \
							EXITCHAR, " = EXIT ]", \
							13, 10 , 10 , 0


	currentstate_str1 	db		13, "Current Color = [ %s  ,  %s  ,  %s  ,  %s  ,  %s  ,  %s  ,  %s  ]  =  %s", 13,10,10, 0

	currentstate_str2	db		13, "Current Sign = [ ", \
								PRINT_ONE, "  ,  ", \
								PRINT_TWO, "  ,  ", \
								PRINT_THREE, "  ,  ", \
								PRINT_FOUR, "  ,  ", \
								PRINT_FIVE, "  ]  ", \
								"= %c", 13,10,10,0

	printwhite	db		0x1b,"[0;37m","WHITE",0x1b,"[0m",0
	printred	db		0x1b,"[0;31m","RED",0x1b,"[0m",0
	printgreen	db		0x1b,"[0;32m","GREEN",0x1b,"[0m",0
	printyellow	db		0x1b,"[0;33m","YELLOW",0x1b,"[0m",0
	printblue	db		0x1b,"[0;34m","BLUE",0x1b,"[0m",0
	printmagenta db		0x1b,"[0;35m","MAGENTA",0x1b,"[0m",0
	printcyan	db		0x1b,"[0;36m","CYAN",0x1b,"[0m",0


	normal 		db 0x1b,"[0m",0
	white 		db 0x1b,"[0;37m",0
	red 		db 0x1b,"[0;31m",0
	green 		db 0x1b,"[0;32m",0
	yellow 		db 0x1b,"[0;33m",0
	blue		db	0x1b,"[0;34m",0
	magenta		db	0x1b,"[0;35m",0
	cyan		db	0x1b,"[0;36m",0

segment .bss

	; store current size of board
	board		resb		(HEIGHT * WIDTH)

	; current position
	xpos		resd		1
	ypos		resd		1

	; store color and sign
	ccolor		resd		1
	csign		resd		1

	; store color at position
	boardcolor	resd		(HEIGHT * WIDTH)
	tempx		resd		1
	tempy		resd		1
segment .text
	global  asm_main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose


main:
	push	ebp
	mov		ebp, esp
	; ********** CODE STARTS HERE **********

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	call	init_board

	; set start position
	mov		DWORD [xpos], STARTX
	mov		DWORD [ypos], STARTY

	; set start color, sign
	mov		DWORD[ccolor], printwhite
	mov		DWORD [csign], PRINT_ONE


	; initialize all the color to white
        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [tempy], 0
        y_start:
        cmp             DWORD [tempy], HEIGHT
        je              y_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
               mov             DWORD [tempx], 0
                x_start:
                cmp             DWORD [tempx], WIDTH
                je              x_end

                                mov             eax, DWORD[tempy]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, DWORD[tempx]
                                mov             ebx, DWORD[printwhite]
                                mov             DWORD [boardcolor + eax*4], ebx

                inc             DWORD[tempx]
                jmp             x_start
                x_end:

        inc             DWORD[tempy]
        jmp             y_start
        y_end:



        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)


        game_loop:
                ; draw the game board
                call    render

                ; get an action from the user
                call    getchar

                ; store the current position
                ; we will test if the new position is legal
                ; if not, we will restore these
                mov             esi, [xpos]
                mov             edi, [ypos]

                ; choose what to do
                cmp             eax, EXITCHAR
                je              game_loop_end
                cmp             eax, UPCHAR
                je              move_up
                cmp             eax, LEFTCHAR
                je              move_left
                cmp             eax, DOWNCHAR
                je              move_down
                cmp             eax, RIGHTCHAR
                je              move_right
                jmp             input_end                       ; or just do nothing

                ; move the player according to the input character
                move_up:
                        dec             DWORD [ypos]
                        jmp             input_end
                move_left:
                        dec             DWORD [xpos]
                        jmp             input_end
                move_down:
                        inc             DWORD [ypos]
                        jmp             input_end
                move_right:
                        inc             DWORD [xpos]
						jmp				input_end
                input_end:

				mov		ecx, eax 			; store what key input you put to re-check again after valid move

                ; (W * y) + x = pos

                ; compare the current position to the wall character
                mov             eax, WIDTH
                mul             DWORD [ypos]
                add             eax, [xpos]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                jne             valid_move
                        ; opps, that was an invalid move, reset
                        mov             DWORD [xpos], esi
                        mov             DWORD [ypos], edi
                valid_move:

				cmp				ecx, CHANGECOLORCHAR
				jne				not_changecolor
						cmp				DWORD[ccolor], printwhite
						jne				checkred
								mov		DWORD[ccolor], printred
								jmp		nothing
						checkred:
						cmp				DWORD[ccolor], printred
						jne				checkgreen
								mov		DWORD[ccolor], printgreen
								jmp		nothing
						checkgreen:
						cmp				DWORD[ccolor], printgreen
						jne				checkyellow
								mov		DWORD[ccolor], printyellow
								jmp		nothing
						checkyellow:
						cmp				DWORD[ccolor], printyellow
						jne				checkblue
								mov		DWORD[ccolor], printblue
								jmp		nothing
						checkblue:
						cmp				DWORD[ccolor], printblue
						jne				checkmagenta
								mov		DWORD[ccolor], printmagenta
								jmp		nothing
						checkmagenta:
						cmp				DWORD[ccolor], printmagenta
						jne				checkcyan
								mov		DWORD[ccolor], printcyan
								jmp		nothing
						checkcyan:
								mov		DWORD[ccolor], printwhite
								jmp		nothing


				not_changecolor:
				cmp				ecx, CHANGESIGNCHAR
				jne				not_changesign
						cmp				DWORD[csign], PRINT_ONE
						jne				Checktwo
							mov				DWORD[csign], PRINT_TWO
							jmp				nothing
						Checktwo:
						cmp				DWORD[csign], PRINT_TWO
						jne				Checkthree
							mov				DWORD[csign], PRINT_THREE
							jmp				nothing
						Checkthree:
						cmp				DWORD[csign], PRINT_THREE
						jne				Checkfour
							mov				DWORD[csign], PRINT_FOUR
							jmp				nothing
						Checkfour:
						cmp				DWORD[csign], PRINT_FOUR
						jne				Checkfive
							mov				DWORD[csign], PRINT_FIVE
							jmp				nothing
						Checkfive:
							mov				DWORD[csign], PRINT_ONE
							jmp				nothing

				not_changesign:
				cmp				ecx, PRINTIT
				jne				not_printit

						mov				dl, BYTE[csign]
						mov				BYTE[eax], dl

					; put color in
                        mov             eax, DWORD[ypos]
                        mov             ebx, WIDTH
                        mul             ebx
                        add             eax, DWORD[xpos]
	                    mov             ebx, DWORD[ccolor]
    	                mov             DWORD [boardcolor + eax*4], ebx

						jmp				nothing

				not_printit:
				cmp				ecx, DELETEIT
				jne				nothing

						mov				BYTE[eax], EMPTY_CHAR
						jmp				input_end

				nothing:




        jmp             game_loop
        game_loop_end:

        ; restore old terminal functionality
        call raw_mode_off


	; *********** CODE ENDS HERE ***********
	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION RAW MODE ON===
raw_mode_on:
	push ebp
	mov ebp, esp

	push raw_mode_on_cmd
	call system
	add esp, 4

	mov esp, ebp
	pop ebp
	ret

; === FUNCTION ===
raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp-4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp-8], 0
        read_loop:
        cmp             DWORD [ebp-8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp-8]
                lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp-4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp-4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp-8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp-4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
render:

        push    ebp
        mov             ebp, esp

        ; two ints, for two loop counters
        ; ebp-4, ebp-8
        sub             esp, 8

        ; clear the screen
        push    clear_screen_cmd
        call    system
        add             esp, 4

        ; print the help information
        push    help_str1
        call    printf
        add             esp, 4
        push    help_str2
        call    printf
        add             esp, 4
        push    help_str3
        call    printf
        add             esp, 4

		; print the current color, sign
		push	DWORD[ccolor]
		push	printcyan
		push	printmagenta
		push	printblue
		push	printyellow
		push	printgreen
		push	printred
		push	printwhite

		push	currentstate_str1
		call	printf
		add				esp, 36

		push	DWORD[csign]
		push	currentstate_str2
		call	printf
		add				esp, 8

        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp-4], 0
        y_loop_start:
        cmp             DWORD [ebp-4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp-8], 0
                x_loop_start:
                cmp             DWORD [ebp-8], WIDTH
                je              x_loop_end

                        ; check if (xpos,ypos)=(x,y)
                        mov             eax, [xpos]
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
										; this will have Player char same as print char but it it hard to see
										;                                push    DWORD[csign]
                                jmp             print_end
                        print_board:
                                ; otherwise print whatever's in the buffer
                                mov             eax, [ebp-4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, [ebp-8]

							; add color
								; call printf will reset all register >> have an exteral variable to remember
								mov		DWORD[tempx], eax
									cmp				DWORD[boardcolor+eax*4], printwhite
									jne				notwhite

										push		white
										call		printf
										add			esp, 4
										jmp			donecolor
									notwhite:
									cmp				DWORD[boardcolor+eax*4], printred
									jne				notred

										push		red
										call		printf
										add			esp, 4
										jmp			donecolor
									notred:
									cmp				DWORD[boardcolor+eax*4], printgreen
									jne				notgreen

										push		green
										call		printf
										add			esp, 4
										jmp			donecolor

									notgreen:
									cmp				DWORD[boardcolor+eax*4], printyellow
									jne				notyellow

										push		yellow
										call		printf
										add			esp, 4
										jmp			donecolor

									notyellow:
									cmp				DWORD[boardcolor+eax*4], printblue
									jne				notblue

										push		blue
										call		printf
										add			esp, 4
										jmp			donecolor

									notblue:
									cmp				DWORD[boardcolor+eax*4], printmagenta
									jne				notmagenta
										push		magenta
										call		printf
										add			esp, 4
										jmp			donecolor

									notmagenta:
									cmp				DWORD[boardcolor+eax*4], printcyan
									jne				donecolor
										push		cyan
										call		printf
										add			esp, 4

									donecolor:

								mov				eax, DWORD[tempx]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push    ebx
                        print_end:
                        call    putchar
                        add             esp, 4

						;reset
								push		normal
								call		printf
								add			esp, 4


                inc             DWORD [ebp-8]
                jmp             x_loop_start
                x_loop_end:

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

        inc             DWORD [ebp-4]
        jmp             y_loop_start
        y_loop_end:


        mov             esp, ebp
        pop             ebp
        ret

