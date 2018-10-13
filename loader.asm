; Turboloader routine for ZX Spectrum
; Copyright (C) 2018 Miguel Angel Rodriguez Jodar
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Lesser General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this program. If not, see <http://www.gnu.org/licenses/>.


;To be assembled with PASMO. Other assemblers may work as well.


TST_BUCLE                equ 54   ;numero de T-estados que tarda una vuelta de bucle
TOLERANCIA               equ 25

TST_TONOGUIA             equ 1500  ;numero de T-estados que tarda el pulso del tono guia
BUC_TONOGUIA             equ (TST_TONOGUIA / TST_BUCLE)
CTE_CMP_TONOGUIA         equ (BUC_TONOGUIA-BUC_TONOGUIA*TOLERANCIA/100)

TST_SYNC1                equ 400  ;numero de T-estados que tarda el primer pulso de sincronismo
TST_SYNC2                equ 800  ;numero de T-estados que tarda el segundo pulso de sincronismo
BUC_SYNC1                equ (TST_SYNC1 / TST_BUCLE)
BUC_SYNC2                equ (TST_SYNC2 / TST_BUCLE)
CTE_CMP_SYNC             equ (BUC_SYNC1+BUC_SYNC2)/2-((BUC_SYNC1+BUC_SYNC2)/2)*TOLERANCIA/100

TST_BITZERO              equ 500  ;numero de T-estados que tarda un pulso de bit cero
TST_BITUNO               equ 1000 ;numero de T-estados que tarda un pulso de bit uno
BUC_BITZERO              equ (TST_BITZERO / TST_BUCLE)
BUC_BITUNO               equ (TST_BITUNO / TST_BUCLE)
CTE_CMP_BIT              equ (BUC_BITZERO+BUC_BITUNO)


LoadBytes                ;Entrada: IX=direccion inicio, DE=longitud carga
                         ;B = constantes de tiempo.
                         ;C = polaridad señal y color borde
                         ;L = byte recibido. Cuenta pulsos tono guia
                         ;A y H = registros generales para calculos
                         di

                         ; PASO 1 : encontrar el tono guia y contar al menos 256 ciclos completos

ResetMascara             ld c,00001010b  ;Polaridad normal, borde rojo/cyan, MIC on (esperamos nivel bajo)
BuscaEngancheTonoguia    ld l,0

EsperaPulsoTonoGuia      ld b,0
                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_TONOGUIA
                         jr c,BuscaEngancheTonoguia ;pulso demasiado corto

                         ;Llegados aqui, tenemos un candidato para pulso bajo del tono guia.
                         ;Vamos a ver si le sigue un pulso alto de la duracion adecuada
                         ld b,0
                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_TONOGUIA
                         jr c,BuscaEngancheTonoguia  ;pulso demasiado corto

                         ;Tenemos lo que parece que es un ciclo completo de
                         ;tono guia. Incrementamos el contador en L.
                         ;Si se han recibido al menos 240 ciclos completos,
                         ;esperar a recibir el pulso de sincronismo. Si no,
                         ;seguir recibiendo ciclos de tono guia
                         inc l
                         jp nz,EsperaPulsoTonoGuia

                         ;PASO 2: sigo recibiendo ciclos de tonos guia pero espero pulso de sincronismo

EsperaPulsoSync          ld b,0
                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_SYNC
                         jr nc,EsperaPulsoSync       ;pulso demasiado largo? seguimos buscando

                         ld b,0
                         call Mide1Pulso
                         jr z,BuscaEngancheTonoguia  ;no se detectó cambio
                         jr nc,SalidaLoad            ;se pulso BREAK
                         ld a,b
                         cp CTE_CMP_SYNC
                         jr c,EsperaPulsoSync       ;pulso demasiado corto? seguimos buscando

                         ; PASO 3: sincronismo encontrado. Comienzo a cargar bytes

                         ld a,c
                         xor 00000100b              ;cambio a combinacion azul/amarillo
                         ld c,a

BucleLoadBytes           ld l,1                     ;L guarda el byte formandose (de bit más a menos significativo)
BucleLoadBits            ld b,0
                         call Mide1Pulso
                         call Mide1Pulso
                         jr z,ResetMascara          ;no se detectó cambio
                         jr nc,SalidaLoad           ;se pulso BREAK
                         ld a,CTE_CMP_BIT
                         cp b                       ;Comparamos con tiempo medio de bit. El valor de CF nos indica si es 0 o 1
                         rl l                       ;Nuevo bit se introduce por la derecha
                         jp nc,BucleLoadBits

                         ld (ix),l
                         inc ix
                         dec de
                         ld a,d
                         or e
                         jp nz,BucleLoadBytes

SalidaLoad               ld a,(23624)
                         and 7
                         out (254),a
                         ei
                         ret

Mide1Pulso               ;CF=0 para indicar que se pulso BREAK
                         ;ZF=1 para indicar overrun de la constante de tiempo
                         ;B = tiempo del pulso medido (en ciclos de este bucle)
                         ;Cada ciclo del bucle consume 54 ciclos de reloj
                         ld h,00100000b ;Mascara para aislar EAR (una vez desplazado A a la derecha)
BucleMidePulso           ld a,7Fh
                         in a,(254)
                         rra
                         ret nc         ;si se pulso BREAK, salir
                         inc b          ;actualizamos contador de tiempos
                         ret z
                         xor c          ;aplicamos polaridad actual
                         and h          ;aislamos pulso EAR
                         jp z,BucleMidePulso
                         ld a,c         ;recuperamos color borde de C
                         xor 00100111b  ;cambiamos polaridad actual y color del borde
                         out (254),a
                         ld c,a
                         scf            ;todo OK. CF=1, ZF=0
                         ret
