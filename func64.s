      section .text
      global func
func:
      ; void func(unsigned char* data, int[3][3] filter, unsigned char* data_modified)

      ; ARGUMENTY:
      ; rdi = &data
      ; rsi = &filter
      ; rdx = &data_modified

      ; ZMIENNE W REJESTRACH:
      ; r8  = adres przetwarzania data
      ; r9  = adres przetwarzania data_modified
      ; r10 = adres konca bitmapy (&data+size)
      ; eax = suma z filtrowania
      ; ebx = factor

;-----------------------------------------------------------------------------------------------

      push	rbx                      ; rejestry zachowywane
      push  r12

;-----------------------------------------------------------------------------------------------
      
      mov   r8, rdi                 ; r8 = wskaznik na data
      mov   r9, rdx                 ; r9 = wskaznik na data_modified

      xor   rcx, rcx
      mov   ecx, dword[rdi+2]       ; rozmiar pliku ( >= 0 )
      add   rcx, rdi       	      ; rozmiar pliku + &data[0]
      mov   r10, rcx                ; r10 = adres konca bitmapy

      xor   rcx, rcx
      mov   ecx, dword[rdi+10]      ; ecx = rcx = offset ( >= 0)
      add   r8, rcx  	            ; przesun wskaznik czytania do pixel_array (pomin header)
      add   r9, rcx                 ; to sam dla data_modified (header kopiowany w C)
;-----------------------------------------------------------------------------------------------

      mov   r11, 0                  ; iterator `row`
      mov   r12, 0                  ; iterator `column`
      xor   rax, rax                ; zerujemy sume
      xor   rbx, rbx                ; zerujemy factor

main_loop:
      ; if(r8 >= adres_konca_bitmapy)
      cmp   r8, r10
      jge   end
    
      ; rcx = szerokosc
      xor   rcx, rcx
      mov   ecx, dword[rdi+18]

      ; wylicz index = eax + 3*(szerokosc*(1-row)-1+column)
      mov   rdx, 1         	; rdx = 1
      sub   rdx, r11       	; rdx = 1-row
      imul  rdx, rcx		; rdx = szerokosc(1-row)
      dec   rdx            	; rdx = szerokosc(1-row)-1
      add   rdx, r12       	; rdx = szerokosc(1-row)-1+colum
      imul  rdx, 3         	; rdx = 3*(szerokosc(1-row)-1+column)
      add   rdx, r8       	; rdx = calculated index (r8+3(szerokosc(1-row)-1+column)

      ; sprawdz czy index jest w granicach bitmapy
      ; if(index < data+offset) goto next_column
      xor   rcx, rcx
      mov   ecx, dword[rdi+10]; rcx = offset
      add   rcx, rdi          ; rcx = &data + offset
      cmp   rdx, rcx
      jl    next_column
      ; if(index > data+size) goto next_column
      cmp   rdx, r10
      jg    next_column


      ; jesli index jest prawidlowy:

      ; rcx = data[calculated_index]
      xor   rcx, rcx
      mov   cl, BYTE[rdx]
      
      ; wez filter[row][column] filter+12*row+4*i = filter+4*(3*row+column)
      mov   rdx, r11       ; rdx = row
      imul  rdx, 3         ; rdx = 3*row
      add   rdx, r12       ; rdx = 3*row+column

      mov   edx, dword[rsi+4*rdx] ; rdx = *(filter+12*row+4*column)

      ; factor += filter[row][column]
      add   ebx, edx

      ; pomnoz data[calculated_index] * filter[row][column]
      imul  ecx, edx
 check_it:     
      ; dodaj do zmiennej lokalnej `suma`
      add   eax, ecx

next_column:
      cmp   r12, 2         ; if(column>=2)
      jge   next_row
      inc   r12            ; ++column
      jmp   main_loop

next_row:
      mov   r12, 0         ; column = 0
      inc   r11            ; ++row
      cmp   r11, 3         ; if(row < 3)
      jl    main_loop

next_byte:
      ; if(factor == 0)
      cmp   rbx, 0
      mov   rcx, 1
      cmove rbx, rcx
      ; sum/factor
      push  rbx            ; dzielnik - factor
      push  rax            ; dzielna - suma
      fild  dword[rsp]     ; dzielna - suma 
      fild  dword[rsp+8]   ; dzielnik - factor
      add   rsp, 8
      fdiv
      fistp qword[rsp]
      pop   rax
      
      
      ; if(wynik<0) wynik = 0
      ; if(wynik>255) wynik = 255
      mov   rcx, 0
      cmp   rax, 0
      cmovl rax, rcx
      mov   rcx, 255
      cmp   rax, 255
      cmovg rax, rcx
   
      ; zapisz wynik do bufora data_modified
      mov   BYTE[r9], al

      ; zeruj iteratory
      xor	r11, r11
      xor	r12, r12
      xor   rax, rax            ; zeruj sume
      xor   rbx, rbx       	  ; zeruj factor
      inc   r8                  ; wskaznik data +1
      inc   r9                  ; wskaznik data_modified +1
      jmp   main_loop
      
;-----------------------------------------------------------------------------------------------      
end:
      pop   r12
	pop	rbx
      ret                  ; powrót
