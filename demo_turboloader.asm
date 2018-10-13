; This file is part of "Turboloader routine for ZX Spectrum"
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


;Small demo that loads a standard ULA screen

                         org 49152

                         ld ix,16384
                         ld de,6912
                         call LoadBytes

                         xor a
                         out (254),a
LoopPause0               halt
                         xor a
                         in a,(254)
                         and 1Fh
                         cp 1Fh
                         jr z,LoopPause0

                         ret

include "loader.asm"

                         end 49152


                         end
