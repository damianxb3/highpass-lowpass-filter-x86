      section .text
      global func
func:
      ; void func(unsigned char* data, int[3][3] filter, unsigned char* data_modified)
      
      ; ARGUMENTY:
      ; [ebp+8]  - &data
      ; [ebp+12] - &filter
      ; [ebp+16] - &data_modifed


      ; ZMIENNE LOKALNE:
      ; [ebp-4]  - adres konca bitmapy (data+size)
      ; [ebp-8]  - suma z filtrowania
      ; [ebp-12] - factor

;-----------------------------------------------------------------------------------------------      
      push  ebp
      mov   ebp, esp
      sub   esp, 12            
      
      push  ebx               ; rejestry zachowywane
      push  edi
      push  esi

;-----------------------------------------------------------------------------------------------
      
      mov   eax, [ebp+8]      ; eax = wskaznik na data
      mov   ebx, [ebp+16]     ; ebx = wskaznik na data_modified

      mov   ecx, [eax+2]      ; rozmiar pliku
      add   ecx, eax          ; rozmiar pliku + &data[0]
      mov   [ebp-4], ecx      ; [ebp-4] = adres konca bitmapy

      add   eax, [eax+10]     ; przesun wskaznik czytania do pixel_array (pomin header)
      add   ebx, [ebx+10]     ; to sam dla data_modified (header kopiowany w C)
;-----------------------------------------------------------------------------------------------
    
      mov   esi, 0            ; iterator `row`
      mov   edi, 0            ; iterator `column`
      mov   ecx, 0
      mov   [ebp-8], ecx      ; zerujemy sume
      mov   [ebp-12], ecx     ; zerujemy factor

main_loop:
      ; if(eax >= adres konca bitmapy)
      cmp   eax, [ebp-4]
      jge   end
    
      ; edx = szerokosc
      mov   edx, [ebp+8]      ; edx = &data
      mov   edx, [edx+18]     ; edx = *(data+18) <=> szerokosc

      ; wylicz index = eax + 3*(szerokosc*(1-row)-1+column)
      mov   ecx, 1            ; ecx = 1
      sub   ecx, esi          ; ecx = 1-row
      imul  ecx, edx          ; ecx = szerokosc(1-row)
      dec   ecx               ; ecx = szerokosc(1-row)-1
      add   ecx, edi          ; ecx = szerokosc(1-row)-1+colum
      imul  ecx, 3            ; ecx = 3*(szerokosc(1-row)-1+column)
      add   ecx, eax          ; ecx = calculated index (eax+3(szerokosc(1-row)-1+column)

      ; sprawdz czy index jest w granicach bitmapy
      ; if(index < data+offset) goto next_column
      mov   edx, [ebp+8]      ; edx = &data
      add   edx, [edx+10]     ; edx = &data + offset
      cmp   ecx, edx
      jl    next_column
      ; if(index > data+size) goto next_column
      cmp   ecx, [ebp-4]
      jg    next_column

      ; edx = data[calculated_index]
      xor   edx, edx
      mov   dl, BYTE[ecx]
      push  edx
      
      ; ecx = filter[row][column] filter+12*row+4*i = filter+4*(3*row+column)
      mov   ecx, esi          ; ecx = row
      imul  ecx, 3            ; ecx = 3*row
      add   ecx, edi          ; ecx = 3*row+column
      mov   edx, [ebp+12]     ; edx = &filter
      mov   ecx, [edx+4*ecx]  ; ecx = *(filter+12*row+4*column) <=> filter[row][column]
      
      ; factor += filter[row][column]
      add   [ebp-12], ecx

      ; edx = data[calculated_index]
      pop   edx

      ; ecx = filter[row][column] * data[calculated_index]
      imul  ecx, edx
      
      ; suma += filter[row][column] * data[calculated_index]
      add   [ebp-8], ecx

next_column:
      cmp   edi, 2            ; if(column>=2)
      jge   next_row
      inc   edi               ; ++column
      jmp   main_loop

next_row:
      mov   edi, 0            ; column = 0
      inc   esi               ; ++row
      cmp   esi, 3
      jl    main_loop

next_byte:
      ; if(factor == 0) factor = 1
      mov   ecx, [ebp-12]     ; ecx = factor
      mov   edx, 1            ; edx = 1
      cmp   ecx, 0            ; if(factor == 0)
      cmove ecx, edx          ; then factor = 1
      mov   [ebp-12], ecx

      ; sum/factor
      fild  dword[ebp-8]      ; dzielna - suma
      fild  dword[ebp-12]     ; dzielnik - factor
      fdiv                    ; suma/factor
      fistp dword[ebp-12]     ; wynik zdejmij do [ebp-12]
      mov   edx, [ebp-12]     ; wynik do rejestru
      
      ; if(wynik<0) wynik = 0
      ; if(wynik>255) wynik = 255
      mov   ecx, 0
      cmp   edx, 0
      cmovl edx, ecx
      mov   ecx, 255
      cmp   edx, 255
      cmovg edx, ecx
   
      ; zapisz wynik do bufora data_modified
      mov   BYTE[ebx], dl

      mov   esi, 0            ; zeruj iteratory
      mov   edi, 0
      mov   ecx, 0
      mov   [ebp-8], ecx      ; zeruj sume
      mov   [ebp-12], ecx     ; zeruj factor
      inc   eax               ; wskaznik data +1
      inc   ebx               ; wskaznik data_modified +1
      jmp   main_loop
      
;-----------------------------------------------------------------------------------------------      
end:
      pop   esi               ; rejestry zachowane
      pop   edi
      pop   ebx
      mov   esp, ebp          ; dealokacja zmiennych lokalnych
      pop   ebp               ; odtworzenie wskaźnika ramki procedury wołającej
      ret                     ; powrót
