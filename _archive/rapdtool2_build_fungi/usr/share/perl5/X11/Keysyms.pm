# Keysyms.pm semi-automatically derived from:
# $XConsortium: keysymdef.h,v 1.21 94/08/28 16:17:06 rws Exp $ 
#
#**********************************************************
#Copyright (c) 1987, 1994  X Consortium
#
#Permission is hereby granted, free of charge, to any person obtaining
#a copy of this software and associated documentation files (the
#"Software"), to deal in the Software without restriction, including
#without limitation the rights to use, copy, modify, merge, publish,
#distribute, sublicense, and/or sell copies of the Software, and to
#permit persons to whom the Software is furnished to do so, subject to
#the following conditions:
#
#The above copyright notice and this permission notice shall be included
#in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#IN NO EVENT SHALL THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR
#OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#OTHER DEALINGS IN THE SOFTWARE.
#
#Except as contained in this notice, the name of the X Consortium shall
#not be used in advertising or otherwise to promote the sale, use or
#other dealings in this Software without prior written authorization
#from the X Consortium.
#
#
#Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts
#
#                        All Rights Reserved
#
#Permission to use, copy, modify, and distribute this software and its
#documentation for any purpose and without fee is hereby granted,
#provided that the above copyright notice appear in all copies and that
#both that copyright notice and this permission notice appear in
#supporting documentation, and that the name of Digital not be
#used in advertising or publicity pertaining to distribution of the
#software without specific, written prior permission.
#
#DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
#ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
#DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
#ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
#WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
#ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
#SOFTWARE.
#
#*****************************************************************

package X11::Keysyms;

use Carp;
$VERSION = 0.01;

sub import {
    my($pkg, $var, @x) = @_;
    my($into) = caller();

    croak "Need the name of a variable to import into" unless $var;
    $var =~ s/^%//;

    my(%KL);
    if (@x) {
	@KL{@x} = (1) x @x;
    } else {
	@KL{'MISCELLANY', 'XKB_KEYS', 'LATIN1', 'LATIN2', 'LATIN3', 'LATIN4',
	    'GREEK'} = (1) x 7;
    }

    local(*Keysyms) = *{"${into}::$var"};
#   print STDERR "Exporting into ${into}::$var\n";

    $Keysyms{"VoidSymbol"} = 0xFFFFFF;	# void symbol 
    
#ifdef XK_MISCELLANY
#
# * TTY Functions, cleverly chosen to map to ascii, for convenience of
# * programming, but could have been arbitrary (at the cost of lookup
# * tables in client code.
    
    if ($KL{'MISCELLANY'}) {
	$Keysyms{"BackSpace"} = 0xFF08;	# back space, back char 
	$Keysyms{"Tab"} = 0xFF09;
	$Keysyms{"Linefeed"} = 0xFF0A;	# Linefeed, LF 
	$Keysyms{"Clear"} = 0xFF0B;
	$Keysyms{"Return"} = 0xFF0D;	# Return, enter 
	$Keysyms{"Pause"} = 0xFF13;	# Pause, hold 
	$Keysyms{"Scroll_Lock"} = 0xFF14;
	$Keysyms{"Sys_Req"} = 0xFF15;
	$Keysyms{"Escape"} = 0xFF1B;
	$Keysyms{"Delete"} = 0xFFFF;	# Delete, rubout 

# International & multi-key character composition 

	$Keysyms{"Multi_key"} = 0xFF20;  # Multi-key character compose 

# Japanese keyboard support 

	$Keysyms{"Kanji"} = 0xFF21;	# Kanji, Kanji convert 
	$Keysyms{"Muhenkan"} = 0xFF22;  # Cancel Conversion 
	$Keysyms{"Henkan_Mode"} = 0xFF23;  # Start/Stop Conversion 
	$Keysyms{"Henkan"} = 0xFF23;  # Alias for Henkan_Mode 
	$Keysyms{"Romaji"} = 0xFF24;  # to Romaji 
	$Keysyms{"Hiragana"} = 0xFF25;  # to Hiragana 
	$Keysyms{"Katakana"} = 0xFF26;  # to Katakana 
	$Keysyms{"Hiragana_Katakana"} = 0xFF27;  # Hiragana/Katakana toggle 
	$Keysyms{"Zenkaku"} = 0xFF28;  # to Zenkaku 
	$Keysyms{"Hankaku"} = 0xFF29;  # to Hankaku 
	$Keysyms{"Zenkaku_Hankaku"} = 0xFF2A;  # Zenkaku/Hankaku toggle 
	$Keysyms{"Touroku"} = 0xFF2B;  # Add to Dictionary 
	$Keysyms{"Massyo"} = 0xFF2C;  # Delete from Dictionary 
	$Keysyms{"Kana_Lock"} = 0xFF2D;  # Kana Lock 
	$Keysyms{"Kana_Shift"} = 0xFF2E;  # Kana Shift 
	$Keysyms{"Eisu_Shift"} = 0xFF2F;  # Alphanumeric Shift 
	$Keysyms{"Eisu_toggle"} = 0xFF30;  # Alphanumeric toggle 

# 0xFF31 thru 0xFF3F are under XK_KOREAN 

# Cursor control & motion 

	$Keysyms{"Home"} = 0xFF50;
	$Keysyms{"Left"} = 0xFF51;	# Move left, left arrow 
	$Keysyms{"Up"} = 0xFF52;	# Move up, up arrow 
	$Keysyms{"Right"} = 0xFF53;	# Move right, right arrow 
	$Keysyms{"Down"} = 0xFF54;	# Move down, down arrow 
	$Keysyms{"Prior"} = 0xFF55;	# Prior, previous 
	$Keysyms{"Page_Up"} = 0xFF55;
	$Keysyms{"Next"} = 0xFF56;	# Next 
	$Keysyms{"Page_Down"} = 0xFF56;
	$Keysyms{"End"} = 0xFF57;	# EOL 
	$Keysyms{"Begin"} = 0xFF58;	# BOL 


# Misc Functions 

	$Keysyms{"Select"} = 0xFF60;	# Select, mark 
	$Keysyms{"Print"} = 0xFF61;
	$Keysyms{"Execute"} = 0xFF62;	# Execute, run, do 
	$Keysyms{"Insert"} = 0xFF63;	# Insert, insert here 
	$Keysyms{"Undo"} = 0xFF65;	# Undo, oops 
	$Keysyms{"Redo"} = 0xFF66;	# redo, again 
	$Keysyms{"Menu"} = 0xFF67;
	$Keysyms{"Find"} = 0xFF68;	# Find, search 
	$Keysyms{"Cancel"} = 0xFF69;	# Cancel, stop, abort, exit 
	$Keysyms{"Help"} = 0xFF6A;	# Help 
	$Keysyms{"Break"} = 0xFF6B;
	$Keysyms{"Mode_switch"} = 0xFF7E;	# Character set switch 
	$Keysyms{"script_switch"} = 0xFF7E;  # Alias for mode_switch 
	$Keysyms{"Num_Lock"} = 0xFF7F;

# Keypad Functions, keypad numbers cleverly chosen to map to ascii 

	$Keysyms{"KP_Space"} = 0xFF80;	# space 
	$Keysyms{"KP_Tab"} = 0xFF89;
	$Keysyms{"KP_Enter"} = 0xFF8D;	# enter 
	$Keysyms{"KP_F1"} = 0xFF91;	# PF1, KP_A, ... 
	$Keysyms{"KP_F2"} = 0xFF92;
	$Keysyms{"KP_F3"} = 0xFF93;
	$Keysyms{"KP_F4"} = 0xFF94;
	$Keysyms{"KP_Home"} = 0xFF95;
	$Keysyms{"KP_Left"} = 0xFF96;
	$Keysyms{"KP_Up"} = 0xFF97;
	$Keysyms{"KP_Right"} = 0xFF98;
	$Keysyms{"KP_Down"} = 0xFF99;
	$Keysyms{"KP_Prior"} = 0xFF9A;
	$Keysyms{"KP_Page_Up"} = 0xFF9A;
	$Keysyms{"KP_Next"} = 0xFF9B;
	$Keysyms{"KP_Page_Down"} = 0xFF9B;
	$Keysyms{"KP_End"} = 0xFF9C;
	$Keysyms{"KP_Begin"} = 0xFF9D;
	$Keysyms{"KP_Insert"} = 0xFF9E;
	$Keysyms{"KP_Delete"} = 0xFF9F;
	$Keysyms{"KP_Equal"} = 0xFFBD;	# equals 
	$Keysyms{"KP_Multiply"} = 0xFFAA;
	$Keysyms{"KP_Add"} = 0xFFAB;
	$Keysyms{"KP_Separator"} = 0xFFAC;	# separator, often comma 
	$Keysyms{"KP_Subtract"} = 0xFFAD;
	$Keysyms{"KP_Decimal"} = 0xFFAE;
	$Keysyms{"KP_Divide"} = 0xFFAF;

	$Keysyms{"KP_0"} = 0xFFB0;
	$Keysyms{"KP_1"} = 0xFFB1;
	$Keysyms{"KP_2"} = 0xFFB2;
	$Keysyms{"KP_3"} = 0xFFB3;
	$Keysyms{"KP_4"} = 0xFFB4;
	$Keysyms{"KP_5"} = 0xFFB5;
	$Keysyms{"KP_6"} = 0xFFB6;
	$Keysyms{"KP_7"} = 0xFFB7;
	$Keysyms{"KP_8"} = 0xFFB8;
	$Keysyms{"KP_9"} = 0xFFB9;

#
# * Auxilliary Functions; note the duplicate definitions for left and right
# * function keys;  Sun keyboards and a few other manufactures have such
# * function key groups on the left and/or right sides of the keyboard.
# * We've not found a keyboard with more than 35 function keys total.
	
	$Keysyms{"F1"} = 0xFFBE;
	$Keysyms{"F2"} = 0xFFBF;
	$Keysyms{"F3"} = 0xFFC0;
	$Keysyms{"F4"} = 0xFFC1;
	$Keysyms{"F5"} = 0xFFC2;
	$Keysyms{"F6"} = 0xFFC3;
	$Keysyms{"F7"} = 0xFFC4;
	$Keysyms{"F8"} = 0xFFC5;
	$Keysyms{"F9"} = 0xFFC6;
	$Keysyms{"F10"} = 0xFFC7;
	$Keysyms{"F11"} = 0xFFC8;
	$Keysyms{"L1"} = 0xFFC8;
	$Keysyms{"F12"} = 0xFFC9;
	$Keysyms{"L2"} = 0xFFC9;
	$Keysyms{"F13"} = 0xFFCA;
	$Keysyms{"L3"} = 0xFFCA;
	$Keysyms{"F14"} = 0xFFCB;
	$Keysyms{"L4"} = 0xFFCB;
	$Keysyms{"F15"} = 0xFFCC;
	$Keysyms{"L5"} = 0xFFCC;
	$Keysyms{"F16"} = 0xFFCD;
	$Keysyms{"L6"} = 0xFFCD;
	$Keysyms{"F17"} = 0xFFCE;
	$Keysyms{"L7"} = 0xFFCE;
	$Keysyms{"F18"} = 0xFFCF;
	$Keysyms{"L8"} = 0xFFCF;
	$Keysyms{"F19"} = 0xFFD0;
	$Keysyms{"L9"} = 0xFFD0;
	$Keysyms{"F20"} = 0xFFD1;
	$Keysyms{"L10"} = 0xFFD1;
	$Keysyms{"F21"} = 0xFFD2; 
	$Keysyms{"R1"} = 0xFFD2;
	$Keysyms{"F22"} = 0xFFD3;
	$Keysyms{"R2"} = 0xFFD3;
	$Keysyms{"F23"} = 0xFFD4;
	$Keysyms{"R3"} = 0xFFD4;
	$Keysyms{"F24"} = 0xFFD5;
	$Keysyms{"R4"} = 0xFFD5; 
	$Keysyms{"F25"} = 0xFFD6;
	$Keysyms{"R5"} = 0xFFD6;
	$Keysyms{"F26"} = 0xFFD7;
	$Keysyms{"R6"} = 0xFFD7;
	$Keysyms{"F27"} = 0xFFD8;
	$Keysyms{"R7"} = 0xFFD8;
	$Keysyms{"F28"} = 0xFFD9;
	$Keysyms{"R8"} = 0xFFD9;
	$Keysyms{"F29"} = 0xFFDA;
	$Keysyms{"R9"} = 0xFFDA;
	$Keysyms{"F30"} = 0xFFDB;
	$Keysyms{"R10"} = 0xFFDB;
	$Keysyms{"F31"} = 0xFFDC;
	$Keysyms{"R11"} = 0xFFDC;
	$Keysyms{"F32"} = 0xFFDD;
	$Keysyms{"R12"} = 0xFFDD;
	$Keysyms{"F33"} = 0xFFDE;
	$Keysyms{"R13"} = 0xFFDE;
	$Keysyms{"F34"} = 0xFFDF;
	$Keysyms{"R14"} = 0xFFDF;
	$Keysyms{"F35"} = 0xFFE0;
	$Keysyms{"R15"} = 0xFFE0;

# Modifiers 

	$Keysyms{"Shift_L"} = 0xFFE1;	# Left shift 
	$Keysyms{"Shift_R"} = 0xFFE2;	# Right shift 
	$Keysyms{"Control_L"} = 0xFFE3;	# Left control 
	$Keysyms{"Control_R"} = 0xFFE4;	# Right control 
	$Keysyms{"Caps_Lock"} = 0xFFE5;	# Caps lock 
	$Keysyms{"Shift_Lock"} = 0xFFE6;	# Shift lock 
	
	$Keysyms{"Meta_L"} = 0xFFE7;	# Left meta 
	$Keysyms{"Meta_R"} = 0xFFE8;	# Right meta 
	$Keysyms{"Alt_L"} = 0xFFE9;	# Left alt 
	$Keysyms{"Alt_R"} = 0xFFEA;	# Right alt 
	$Keysyms{"Super_L"} = 0xFFEB;	# Left super 
	$Keysyms{"Super_R"} = 0xFFEC;	# Right super 
	$Keysyms{"Hyper_L"} = 0xFFED;	# Left hyper 
	$Keysyms{"Hyper_R"} = 0xFFEE;	# Right hyper 
    }
#endif # XK_MISCELLANY 

# 
# * ISO 9995 Function and Modifier Keys
# * Byte 3 = 0xFE
    

#ifdef XK_XKB_KEYS
    if ($KL{'XKB_KEYS'}) {
	$Keysyms{"ISO_Lock"} = 0xFE01;
	$Keysyms{"ISO_Level2_Latch"} = 0xFE02;
	$Keysyms{"ISO_Level3_Shift"} = 0xFE03;
	$Keysyms{"ISO_Level3_Latch"} = 0xFE04;
	$Keysyms{"ISO_Level3_Lock"} = 0xFE05;
	$Keysyms{"ISO_Group_Shift"} = 0xFF7E;	# Alias for mode_switch 
	$Keysyms{"ISO_Group_Latch"} = 0xFE06;
	$Keysyms{"ISO_Group_Lock"} = 0xFE07;
	$Keysyms{"ISO_Next_Group"} = 0xFE08;
	$Keysyms{"ISO_Next_Group_Lock"} = 0xFE09;
	$Keysyms{"ISO_Prev_Group"} = 0xFE0A;
	$Keysyms{"ISO_Prev_Group_Lock"} = 0xFE0B;
	$Keysyms{"ISO_First_Group"} = 0xFE0C;
	$Keysyms{"ISO_First_Group_Lock"} = 0xFE0D;
	$Keysyms{"ISO_Last_Group"} = 0xFE0E;
	$Keysyms{"ISO_Last_Group_Lock"} = 0xFE0F;

	$Keysyms{"ISO_Left_Tab"} = 0xFE20;
	$Keysyms{"ISO_Move_Line_Up"} = 0xFE21;
	$Keysyms{"ISO_Move_Line_Down"} = 0xFE22;
	$Keysyms{"ISO_Partial_Line_Up"} = 0xFE23;
	$Keysyms{"ISO_Partial_Line_Down"} = 0xFE24;
	$Keysyms{"ISO_Partial_Space_Left"} = 0xFE25;
	$Keysyms{"ISO_Partial_Space_Right"} = 0xFE26;
	$Keysyms{"ISO_Set_Margin_Left"} = 0xFE27;
	$Keysyms{"ISO_Set_Margin_Right"} = 0xFE28;
	$Keysyms{"ISO_Release_Margin_Left"} = 0xFE29;
	$Keysyms{"ISO_Release_Margin_Right"} = 0xFE2A;
	$Keysyms{"ISO_Release_Both_Margins"} = 0xFE2B;
	$Keysyms{"ISO_Fast_Cursor_Left"} = 0xFE2C;
	$Keysyms{"ISO_Fast_Cursor_Right"} = 0xFE2D;
	$Keysyms{"ISO_Fast_Cursor_Up"} = 0xFE2E;
	$Keysyms{"ISO_Fast_Cursor_Down"} = 0xFE2F;
	$Keysyms{"ISO_Continuous_Underline"} = 0xFE30;
	$Keysyms{"ISO_Discontinuous_Underline"} = 0xFE31;
	$Keysyms{"ISO_Emphasize"} = 0xFE32;
	$Keysyms{"ISO_Center_Object"} = 0xFE33;
	$Keysyms{"ISO_Enter"} = 0xFE34;

	$Keysyms{"dead_grave"} = 0xFE50;
	$Keysyms{"dead_acute"} = 0xFE51;
	$Keysyms{"dead_circumflex"} = 0xFE52;
	$Keysyms{"dead_tilde"} = 0xFE53;
	$Keysyms{"dead_macron"} = 0xFE54;
	$Keysyms{"dead_breve"} = 0xFE55;
	$Keysyms{"dead_abovedot"} = 0xFE56;
	$Keysyms{"dead_diaeresis"} = 0xFE57;
	$Keysyms{"dead_abovering"} = 0xFE58;
	$Keysyms{"dead_doubleacute"} = 0xFE59;
	$Keysyms{"dead_caron"} = 0xFE5A;
	$Keysyms{"dead_cedilla"} = 0xFE5B;
	$Keysyms{"dead_ogonek"} = 0xFE5C;
	$Keysyms{"dead_iota"} = 0xFE5D;
	$Keysyms{"dead_voiced_sound"} = 0xFE5E;
	$Keysyms{"dead_semivoiced_sound"} = 0xFE5F;

	$Keysyms{"First_Virtual_Screen"} = 0xFED0;
	$Keysyms{"Prev_Virtual_Screen"} = 0xFED1;
	$Keysyms{"Next_Virtual_Screen"} = 0xFED2;
	$Keysyms{"Last_Virtual_Screen"} = 0xFED4;
	$Keysyms{"Terminate_Server"} = 0xFED5;

	$Keysyms{"Pointer_Left"} = 0xFEE0;
	$Keysyms{"Pointer_Right"} = 0xFEE1;
	$Keysyms{"Pointer_Up"} = 0xFEE2;
	$Keysyms{"Pointer_Down"} = 0xFEE3;
	$Keysyms{"Pointer_UpLeft"} = 0xFEE4;
	$Keysyms{"Pointer_UpRight"} = 0xFEE5;
	$Keysyms{"Pointer_DownLeft"} = 0xFEE6;
	$Keysyms{"Pointer_DownRight"} = 0xFEE7;
	$Keysyms{"Pointer_Button_Dflt"} = 0xFEE8;
	$Keysyms{"Pointer_Button1"} = 0xFEE9;
	$Keysyms{"Pointer_Button2"} = 0xFEEA;
	$Keysyms{"Pointer_Button3"} = 0xFEEB;
	$Keysyms{"Pointer_Button4"} = 0xFEEC;
	$Keysyms{"Pointer_Button5"} = 0xFEED;
	$Keysyms{"Pointer_DblClick_Dflt"} = 0xFEEE;
	$Keysyms{"Pointer_DblClick1"} = 0xFEEF;
	$Keysyms{"Pointer_DblClick2"} = 0xFEF0;
	$Keysyms{"Pointer_DblClick3"} = 0xFEF1;
	$Keysyms{"Pointer_DblClick4"} = 0xFEF2;
	$Keysyms{"Pointer_DblClick5"} = 0xFEF3;
	$Keysyms{"Pointer_Drag_Dflt"} = 0xFEF4;
	$Keysyms{"Pointer_Drag1"} = 0xFEF5;
	$Keysyms{"Pointer_Drag2"} = 0xFEF6;
	$Keysyms{"Pointer_Drag3"} = 0xFEF7;
	$Keysyms{"Pointer_Drag4"} = 0xFEF8;

	$Keysyms{"Pointer_EnableKeys"} = 0xFEF9;
	$Keysyms{"Pointer_Accelerate"} = 0xFEFA;
	$Keysyms{"Pointer_DfltBtnNext"} = 0xFEFB;
	$Keysyms{"Pointer_DfltBtnPrev"} = 0xFEFC;
    }
#endif

#
# * 3270 Terminal Keys
# * Byte 3 = 0xFD
    

#ifdef XK_3270
    if ($KL{'3270'}) {
	$Keysyms{"3270_Duplicate"} = 0xFD01;
	$Keysyms{"3270_FieldMark"} = 0xFD02;
	$Keysyms{"3270_Right2"} = 0xFD03;
	$Keysyms{"3270_Left2"} = 0xFD04;
	$Keysyms{"3270_BackTab"} = 0xFD05;
	$Keysyms{"3270_EraseEOF"} = 0xFD06;
	$Keysyms{"3270_EraseInput"} = 0xFD07;
	$Keysyms{"3270_Reset"} = 0xFD08;
	$Keysyms{"3270_Quit"} = 0xFD09;
	$Keysyms{"3270_PA1"} = 0xFD0A;
	$Keysyms{"3270_PA2"} = 0xFD0B;
	$Keysyms{"3270_PA3"} = 0xFD0C;
	$Keysyms{"3270_Test"} = 0xFD0D;
	$Keysyms{"3270_Attn"} = 0xFD0E;
	$Keysyms{"3270_CursorBlink"} = 0xFD0F;
	$Keysyms{"3270_AltCursor"} = 0xFD10;
	$Keysyms{"3270_KeyClick"} = 0xFD11;
	$Keysyms{"3270_Jump"} = 0xFD12;
	$Keysyms{"3270_Ident"} = 0xFD13;
	$Keysyms{"3270_Rule"} = 0xFD14;
	$Keysyms{"3270_Copy"} = 0xFD15;
	$Keysyms{"3270_Play"} = 0xFD16;
	$Keysyms{"3270_Setup"} = 0xFD17;
	$Keysyms{"3270_Record"} = 0xFD18;
	$Keysyms{"3270_ChangeScreen"} = 0xFD19;
	$Keysyms{"3270_DeleteWord"} = 0xFD1A;
	$Keysyms{"3270_ExSelect"} = 0xFD1B;
	$Keysyms{"3270_CursorSelect"} = 0xFD1C;
	$Keysyms{"3270_PrintScreen"} = 0xFD1D;
	$Keysyms{"3270_Enter"} = 0xFD1E;
    }
#endif

#
# *  Latin 1
# *  Byte 3 = 0
    
#ifdef XK_LATIN1
    if ($KL{'LATIN1'}) {
	$Keysyms{"space"} = 0x020;
	$Keysyms{"exclam"} = 0x021;
	$Keysyms{"quotedbl"} = 0x022;
	$Keysyms{"numbersign"} = 0x023;
	$Keysyms{"dollar"} = 0x024;
	$Keysyms{"percent"} = 0x025;
	$Keysyms{"ampersand"} = 0x026;
	$Keysyms{"apostrophe"} = 0x027;
	$Keysyms{"quoteright"} = 0x027;	# deprecated 
	$Keysyms{"parenleft"} = 0x028;
	$Keysyms{"parenright"} = 0x029;
	$Keysyms{"asterisk"} = 0x02a;
	$Keysyms{"plus"} = 0x02b;
	$Keysyms{"comma"} = 0x02c;
	$Keysyms{"minus"} = 0x02d;
	$Keysyms{"period"} = 0x02e;
	$Keysyms{"slash"} = 0x02f;
	$Keysyms{"0"} = 0x030;
	$Keysyms{"1"} = 0x031;
	$Keysyms{"2"} = 0x032;
	$Keysyms{"3"} = 0x033;
	$Keysyms{"4"} = 0x034;
	$Keysyms{"5"} = 0x035;
	$Keysyms{"6"} = 0x036;
	$Keysyms{"7"} = 0x037;
	$Keysyms{"8"} = 0x038;
	$Keysyms{"9"} = 0x039;
	$Keysyms{"colon"} = 0x03a;
	$Keysyms{"semicolon"} = 0x03b;
	$Keysyms{"less"} = 0x03c;
	$Keysyms{"equal"} = 0x03d;
	$Keysyms{"greater"} = 0x03e;
	$Keysyms{"question"} = 0x03f;
	$Keysyms{"at"} = 0x040;
	$Keysyms{"A"} = 0x041;
	$Keysyms{"B"} = 0x042;
	$Keysyms{"C"} = 0x043;
	$Keysyms{"D"} = 0x044;
	$Keysyms{"E"} = 0x045;
	$Keysyms{"F"} = 0x046;
	$Keysyms{"G"} = 0x047;
	$Keysyms{"H"} = 0x048;
	$Keysyms{"I"} = 0x049;
	$Keysyms{"J"} = 0x04a;
	$Keysyms{"K"} = 0x04b;
	$Keysyms{"L"} = 0x04c;
	$Keysyms{"M"} = 0x04d;
	$Keysyms{"N"} = 0x04e;
	$Keysyms{"O"} = 0x04f;
	$Keysyms{"P"} = 0x050;
	$Keysyms{"Q"} = 0x051;
	$Keysyms{"R"} = 0x052;
	$Keysyms{"S"} = 0x053;
	$Keysyms{"T"} = 0x054;
	$Keysyms{"U"} = 0x055;
	$Keysyms{"V"} = 0x056;
	$Keysyms{"W"} = 0x057;
	$Keysyms{"X"} = 0x058;
	$Keysyms{"Y"} = 0x059;
	$Keysyms{"Z"} = 0x05a;
	$Keysyms{"bracketleft"} = 0x05b;
	$Keysyms{"backslash"} = 0x05c;
	$Keysyms{"bracketright"} = 0x05d;
	$Keysyms{"asciicircum"} = 0x05e;
	$Keysyms{"underscore"} = 0x05f;
	$Keysyms{"grave"} = 0x060;
	$Keysyms{"quoteleft"} = 0x060;	# deprecated 
	$Keysyms{"a"} = 0x061;
	$Keysyms{"b"} = 0x062;
	$Keysyms{"c"} = 0x063;
	$Keysyms{"d"} = 0x064;
	$Keysyms{"e"} = 0x065;
	$Keysyms{"f"} = 0x066;
	$Keysyms{"g"} = 0x067;
	$Keysyms{"h"} = 0x068;
	$Keysyms{"i"} = 0x069;
	$Keysyms{"j"} = 0x06a;
	$Keysyms{"k"} = 0x06b;
	$Keysyms{"l"} = 0x06c;
	$Keysyms{"m"} = 0x06d;
	$Keysyms{"n"} = 0x06e;
	$Keysyms{"o"} = 0x06f;
	$Keysyms{"p"} = 0x070;
	$Keysyms{"q"} = 0x071;
	$Keysyms{"r"} = 0x072;
	$Keysyms{"s"} = 0x073;
	$Keysyms{"t"} = 0x074;
	$Keysyms{"u"} = 0x075;
	$Keysyms{"v"} = 0x076;
	$Keysyms{"w"} = 0x077;
	$Keysyms{"x"} = 0x078;
	$Keysyms{"y"} = 0x079;
	$Keysyms{"z"} = 0x07a;
	$Keysyms{"braceleft"} = 0x07b;
	$Keysyms{"bar"} = 0x07c;
	$Keysyms{"braceright"} = 0x07d;
	$Keysyms{"asciitilde"} = 0x07e;

	$Keysyms{"nobreakspace"} = 0x0a0;
	$Keysyms{"exclamdown"} = 0x0a1;
	$Keysyms{"cent"} = 0x0a2;
	$Keysyms{"sterling"} = 0x0a3;
	$Keysyms{"currency"} = 0x0a4;
	$Keysyms{"yen"} = 0x0a5;
	$Keysyms{"brokenbar"} = 0x0a6;
	$Keysyms{"section"} = 0x0a7;
	$Keysyms{"diaeresis"} = 0x0a8;
	$Keysyms{"copyright"} = 0x0a9;
	$Keysyms{"ordfeminine"} = 0x0aa;
	$Keysyms{"guillemotleft"} = 0x0ab;	# left angle quotation mark 
	$Keysyms{"notsign"} = 0x0ac;
	$Keysyms{"hyphen"} = 0x0ad;
	$Keysyms{"registered"} = 0x0ae;
	$Keysyms{"macron"} = 0x0af;
	$Keysyms{"degree"} = 0x0b0;
	$Keysyms{"plusminus"} = 0x0b1;
	$Keysyms{"twosuperior"} = 0x0b2;
	$Keysyms{"threesuperior"} = 0x0b3;
	$Keysyms{"acute"} = 0x0b4;
	$Keysyms{"mu"} = 0x0b5;
	$Keysyms{"paragraph"} = 0x0b6;
	$Keysyms{"periodcentered"} = 0x0b7;
	$Keysyms{"cedilla"} = 0x0b8;
	$Keysyms{"onesuperior"} = 0x0b9;
	$Keysyms{"masculine"} = 0x0ba;
	$Keysyms{"guillemotright"} = 0x0bb;	# right angle quotation mark 
	$Keysyms{"onequarter"} = 0x0bc;
	$Keysyms{"onehalf"} = 0x0bd;
	$Keysyms{"threequarters"} = 0x0be;
	$Keysyms{"questiondown"} = 0x0bf;
	$Keysyms{"Agrave"} = 0x0c0;
	$Keysyms{"Aacute"} = 0x0c1;
	$Keysyms{"Acircumflex"} = 0x0c2;
	$Keysyms{"Atilde"} = 0x0c3;
	$Keysyms{"Adiaeresis"} = 0x0c4;
	$Keysyms{"Aring"} = 0x0c5;
	$Keysyms{"AE"} = 0x0c6;
	$Keysyms{"Ccedilla"} = 0x0c7;
	$Keysyms{"Egrave"} = 0x0c8;
	$Keysyms{"Eacute"} = 0x0c9;
	$Keysyms{"Ecircumflex"} = 0x0ca;
	$Keysyms{"Ediaeresis"} = 0x0cb;
	$Keysyms{"Igrave"} = 0x0cc;
	$Keysyms{"Iacute"} = 0x0cd;
	$Keysyms{"Icircumflex"} = 0x0ce;
	$Keysyms{"Idiaeresis"} = 0x0cf;
	$Keysyms{"ETH"} = 0x0d0;
	$Keysyms{"Eth"} = 0x0d0;	# deprecated 
	$Keysyms{"Ntilde"} = 0x0d1;
	$Keysyms{"Ograve"} = 0x0d2;
	$Keysyms{"Oacute"} = 0x0d3;
	$Keysyms{"Ocircumflex"} = 0x0d4;
	$Keysyms{"Otilde"} = 0x0d5;
	$Keysyms{"Odiaeresis"} = 0x0d6;
	$Keysyms{"multiply"} = 0x0d7;
	$Keysyms{"Ooblique"} = 0x0d8;
	$Keysyms{"Ugrave"} = 0x0d9;
	$Keysyms{"Uacute"} = 0x0da;
	$Keysyms{"Ucircumflex"} = 0x0db;
	$Keysyms{"Udiaeresis"} = 0x0dc;
	$Keysyms{"Yacute"} = 0x0dd;
	$Keysyms{"THORN"} = 0x0de;
	$Keysyms{"Thorn"} = 0x0de;	# deprecated 
	$Keysyms{"ssharp"} = 0x0df;
	$Keysyms{"agrave"} = 0x0e0;
	$Keysyms{"aacute"} = 0x0e1;
	$Keysyms{"acircumflex"} = 0x0e2;
	$Keysyms{"atilde"} = 0x0e3;
	$Keysyms{"adiaeresis"} = 0x0e4;
	$Keysyms{"aring"} = 0x0e5;
	$Keysyms{"ae"} = 0x0e6;
	$Keysyms{"ccedilla"} = 0x0e7;
	$Keysyms{"egrave"} = 0x0e8;
	$Keysyms{"eacute"} = 0x0e9;
	$Keysyms{"ecircumflex"} = 0x0ea;
	$Keysyms{"ediaeresis"} = 0x0eb;
	$Keysyms{"igrave"} = 0x0ec;
	$Keysyms{"iacute"} = 0x0ed;
	$Keysyms{"icircumflex"} = 0x0ee;
	$Keysyms{"idiaeresis"} = 0x0ef;
	$Keysyms{"eth"} = 0x0f0;
	$Keysyms{"ntilde"} = 0x0f1;
	$Keysyms{"ograve"} = 0x0f2;
	$Keysyms{"oacute"} = 0x0f3;
	$Keysyms{"ocircumflex"} = 0x0f4;
	$Keysyms{"otilde"} = 0x0f5;
	$Keysyms{"odiaeresis"} = 0x0f6;
	$Keysyms{"division"} = 0x0f7;
	$Keysyms{"oslash"} = 0x0f8;
	$Keysyms{"ugrave"} = 0x0f9;
	$Keysyms{"uacute"} = 0x0fa;
	$Keysyms{"ucircumflex"} = 0x0fb;
	$Keysyms{"udiaeresis"} = 0x0fc;
	$Keysyms{"yacute"} = 0x0fd;
	$Keysyms{"thorn"} = 0x0fe;
	$Keysyms{"ydiaeresis"} = 0x0ff;
    }
#endif # XK_LATIN1 

#
# *   Latin 2
# *   Byte 3 = 1
    

#ifdef XK_LATIN2
    if ($KL{'LATIN2'}) {
	$Keysyms{"Aogonek"} = 0x1a1;
	$Keysyms{"breve"} = 0x1a2;
	$Keysyms{"Lstroke"} = 0x1a3;
	$Keysyms{"Lcaron"} = 0x1a5;
	$Keysyms{"Sacute"} = 0x1a6;
	$Keysyms{"Scaron"} = 0x1a9;
	$Keysyms{"Scedilla"} = 0x1aa;
	$Keysyms{"Tcaron"} = 0x1ab;
	$Keysyms{"Zacute"} = 0x1ac;
	$Keysyms{"Zcaron"} = 0x1ae;
	$Keysyms{"Zabovedot"} = 0x1af;
	$Keysyms{"aogonek"} = 0x1b1;
	$Keysyms{"ogonek"} = 0x1b2;
	$Keysyms{"lstroke"} = 0x1b3;
	$Keysyms{"lcaron"} = 0x1b5;
	$Keysyms{"sacute"} = 0x1b6;
	$Keysyms{"caron"} = 0x1b7;
	$Keysyms{"scaron"} = 0x1b9;
	$Keysyms{"scedilla"} = 0x1ba;
	$Keysyms{"tcaron"} = 0x1bb;
	$Keysyms{"zacute"} = 0x1bc;
	$Keysyms{"doubleacute"} = 0x1bd;
	$Keysyms{"zcaron"} = 0x1be;
	$Keysyms{"zabovedot"} = 0x1bf;
	$Keysyms{"Racute"} = 0x1c0;
	$Keysyms{"Abreve"} = 0x1c3;
	$Keysyms{"Lacute"} = 0x1c5;
	$Keysyms{"Cacute"} = 0x1c6;
	$Keysyms{"Ccaron"} = 0x1c8;
	$Keysyms{"Eogonek"} = 0x1ca;
	$Keysyms{"Ecaron"} = 0x1cc;
	$Keysyms{"Dcaron"} = 0x1cf;
	$Keysyms{"Dstroke"} = 0x1d0;
	$Keysyms{"Nacute"} = 0x1d1;
	$Keysyms{"Ncaron"} = 0x1d2;
	$Keysyms{"Odoubleacute"} = 0x1d5;
	$Keysyms{"Rcaron"} = 0x1d8;
	$Keysyms{"Uring"} = 0x1d9;
	$Keysyms{"Udoubleacute"} = 0x1db;
	$Keysyms{"Tcedilla"} = 0x1de;
	$Keysyms{"racute"} = 0x1e0;
	$Keysyms{"abreve"} = 0x1e3;
	$Keysyms{"lacute"} = 0x1e5;
	$Keysyms{"cacute"} = 0x1e6;
	$Keysyms{"ccaron"} = 0x1e8;
	$Keysyms{"eogonek"} = 0x1ea;
	$Keysyms{"ecaron"} = 0x1ec;
	$Keysyms{"dcaron"} = 0x1ef;
	$Keysyms{"dstroke"} = 0x1f0;
	$Keysyms{"nacute"} = 0x1f1;
	$Keysyms{"ncaron"} = 0x1f2;
	$Keysyms{"odoubleacute"} = 0x1f5;
	$Keysyms{"udoubleacute"} = 0x1fb;
	$Keysyms{"rcaron"} = 0x1f8;
	$Keysyms{"uring"} = 0x1f9;
	$Keysyms{"tcedilla"} = 0x1fe;
	$Keysyms{"abovedot"} = 0x1ff;
    }
#endif # XK_LATIN2 

#
# *   Latin 3
# *   Byte 3 = 2
    

#ifdef XK_LATIN3
    if ($KL{'LATIN3'}) {
	$Keysyms{"Hstroke"} = 0x2a1;
	$Keysyms{"Hcircumflex"} = 0x2a6;
	$Keysyms{"Iabovedot"} = 0x2a9;
	$Keysyms{"Gbreve"} = 0x2ab;
	$Keysyms{"Jcircumflex"} = 0x2ac;
	$Keysyms{"hstroke"} = 0x2b1;
	$Keysyms{"hcircumflex"} = 0x2b6;
	$Keysyms{"idotless"} = 0x2b9;
	$Keysyms{"gbreve"} = 0x2bb;
	$Keysyms{"jcircumflex"} = 0x2bc;
	$Keysyms{"Cabovedot"} = 0x2c5;
	$Keysyms{"Ccircumflex"} = 0x2c6;
	$Keysyms{"Gabovedot"} = 0x2d5;
	$Keysyms{"Gcircumflex"} = 0x2d8;
	$Keysyms{"Ubreve"} = 0x2dd;
	$Keysyms{"Scircumflex"} = 0x2de;
	$Keysyms{"cabovedot"} = 0x2e5;
	$Keysyms{"ccircumflex"} = 0x2e6;
	$Keysyms{"gabovedot"} = 0x2f5;
	$Keysyms{"gcircumflex"} = 0x2f8;
	$Keysyms{"ubreve"} = 0x2fd;
	$Keysyms{"scircumflex"} = 0x2fe;
    }
#endif # XK_LATIN3 


#
# *   Latin 4
# *   Byte 3 = 3
    

#ifdef XK_LATIN4
    if ($KL{'LATIN4'}) {
	$Keysyms{"kra"} = 0x3a2;
	$Keysyms{"kappa"} = 0x3a2;	# deprecated 
	$Keysyms{"Rcedilla"} = 0x3a3;
	$Keysyms{"Itilde"} = 0x3a5;
	$Keysyms{"Lcedilla"} = 0x3a6;
	$Keysyms{"Emacron"} = 0x3aa;
	$Keysyms{"Gcedilla"} = 0x3ab;
	$Keysyms{"Tslash"} = 0x3ac;
	$Keysyms{"rcedilla"} = 0x3b3;
	$Keysyms{"itilde"} = 0x3b5;
	$Keysyms{"lcedilla"} = 0x3b6;
	$Keysyms{"emacron"} = 0x3ba;
	$Keysyms{"gcedilla"} = 0x3bb;
	$Keysyms{"tslash"} = 0x3bc;
	$Keysyms{"ENG"} = 0x3bd;
	$Keysyms{"eng"} = 0x3bf;
	$Keysyms{"Amacron"} = 0x3c0;
	$Keysyms{"Iogonek"} = 0x3c7;
	$Keysyms{"Eabovedot"} = 0x3cc;
	$Keysyms{"Imacron"} = 0x3cf;
	$Keysyms{"Ncedilla"} = 0x3d1;
	$Keysyms{"Omacron"} = 0x3d2;
	$Keysyms{"Kcedilla"} = 0x3d3;
	$Keysyms{"Uogonek"} = 0x3d9;
	$Keysyms{"Utilde"} = 0x3dd;
	$Keysyms{"Umacron"} = 0x3de;
	$Keysyms{"amacron"} = 0x3e0;
	$Keysyms{"iogonek"} = 0x3e7;
	$Keysyms{"eabovedot"} = 0x3ec;
	$Keysyms{"imacron"} = 0x3ef;
	$Keysyms{"ncedilla"} = 0x3f1;
	$Keysyms{"omacron"} = 0x3f2;
	$Keysyms{"kcedilla"} = 0x3f3;
	$Keysyms{"uogonek"} = 0x3f9;
	$Keysyms{"utilde"} = 0x3fd;
	$Keysyms{"umacron"} = 0x3fe;
    }
#endif # XK_LATIN4 

#
# * Katakana
# * Byte 3 = 4
    

#ifdef XK_KATAKANA
    if ($KL{'KATAKANA'}) {
	$Keysyms{"overline"} = 0x47e;
	$Keysyms{"kana_fullstop"} = 0x4a1;
	$Keysyms{"kana_openingbracket"} = 0x4a2;
	$Keysyms{"kana_closingbracket"} = 0x4a3;
	$Keysyms{"kana_comma"} = 0x4a4;
	$Keysyms{"kana_conjunctive"} = 0x4a5;
	$Keysyms{"kana_middledot"} = 0x4a5;  # deprecated 
	$Keysyms{"kana_WO"} = 0x4a6;
	$Keysyms{"kana_a"} = 0x4a7;
	$Keysyms{"kana_i"} = 0x4a8;
	$Keysyms{"kana_u"} = 0x4a9;
	$Keysyms{"kana_e"} = 0x4aa;
	$Keysyms{"kana_o"} = 0x4ab;
	$Keysyms{"kana_ya"} = 0x4ac;
	$Keysyms{"kana_yu"} = 0x4ad;
	$Keysyms{"kana_yo"} = 0x4ae;
	$Keysyms{"kana_tsu"} = 0x4af;
	$Keysyms{"kana_tu"} = 0x4af;  # deprecated 
	$Keysyms{"prolongedsound"} = 0x4b0;
	$Keysyms{"kana_A"} = 0x4b1;
	$Keysyms{"kana_I"} = 0x4b2;
	$Keysyms{"kana_U"} = 0x4b3;
	$Keysyms{"kana_E"} = 0x4b4;
	$Keysyms{"kana_O"} = 0x4b5;
	$Keysyms{"kana_KA"} = 0x4b6;
	$Keysyms{"kana_KI"} = 0x4b7;
	$Keysyms{"kana_KU"} = 0x4b8;
	$Keysyms{"kana_KE"} = 0x4b9;
	$Keysyms{"kana_KO"} = 0x4ba;
	$Keysyms{"kana_SA"} = 0x4bb;
	$Keysyms{"kana_SHI"} = 0x4bc;
	$Keysyms{"kana_SU"} = 0x4bd;
	$Keysyms{"kana_SE"} = 0x4be;
	$Keysyms{"kana_SO"} = 0x4bf;
	$Keysyms{"kana_TA"} = 0x4c0;
	$Keysyms{"kana_CHI"} = 0x4c1;
	$Keysyms{"kana_TI"} = 0x4c1;  # deprecated 
	$Keysyms{"kana_TSU"} = 0x4c2;
	$Keysyms{"kana_TU"} = 0x4c2;  # deprecated 
	$Keysyms{"kana_TE"} = 0x4c3;
	$Keysyms{"kana_TO"} = 0x4c4;
	$Keysyms{"kana_NA"} = 0x4c5;
	$Keysyms{"kana_NI"} = 0x4c6;
	$Keysyms{"kana_NU"} = 0x4c7;
	$Keysyms{"kana_NE"} = 0x4c8;
	$Keysyms{"kana_NO"} = 0x4c9;
	$Keysyms{"kana_HA"} = 0x4ca;
	$Keysyms{"kana_HI"} = 0x4cb;
	$Keysyms{"kana_FU"} = 0x4cc;
	$Keysyms{"kana_HU"} = 0x4cc;  # deprecated 
	$Keysyms{"kana_HE"} = 0x4cd;
	$Keysyms{"kana_HO"} = 0x4ce;
	$Keysyms{"kana_MA"} = 0x4cf;
	$Keysyms{"kana_MI"} = 0x4d0;
	$Keysyms{"kana_MU"} = 0x4d1;
	$Keysyms{"kana_ME"} = 0x4d2;
	$Keysyms{"kana_MO"} = 0x4d3;
	$Keysyms{"kana_YA"} = 0x4d4;
	$Keysyms{"kana_YU"} = 0x4d5;
	$Keysyms{"kana_YO"} = 0x4d6;
	$Keysyms{"kana_RA"} = 0x4d7;
	$Keysyms{"kana_RI"} = 0x4d8;
	$Keysyms{"kana_RU"} = 0x4d9;
	$Keysyms{"kana_RE"} = 0x4da;
	$Keysyms{"kana_RO"} = 0x4db;
	$Keysyms{"kana_WA"} = 0x4dc;
	$Keysyms{"kana_N"} = 0x4dd;
	$Keysyms{"voicedsound"} = 0x4de;
	$Keysyms{"semivoicedsound"} = 0x4df;
	$Keysyms{"kana_switch"} = 0xFF7E;  # Alias for mode_switch 
    }
#endif # XK_KATAKANA 

#
# *  Arabic
# *  Byte 3 = 5
    

#ifdef XK_ARABIC
    if ($KL{'ARABIC'}) {
	$Keysyms{"Arabic_comma"} = 0x5ac;
	$Keysyms{"Arabic_semicolon"} = 0x5bb;
	$Keysyms{"Arabic_question_mark"} = 0x5bf;
	$Keysyms{"Arabic_hamza"} = 0x5c1;
	$Keysyms{"Arabic_maddaonalef"} = 0x5c2;
	$Keysyms{"Arabic_hamzaonalef"} = 0x5c3;
	$Keysyms{"Arabic_hamzaonwaw"} = 0x5c4;
	$Keysyms{"Arabic_hamzaunderalef"} = 0x5c5;
	$Keysyms{"Arabic_hamzaonyeh"} = 0x5c6;
	$Keysyms{"Arabic_alef"} = 0x5c7;
	$Keysyms{"Arabic_beh"} = 0x5c8;
	$Keysyms{"Arabic_tehmarbuta"} = 0x5c9;
	$Keysyms{"Arabic_teh"} = 0x5ca;
	$Keysyms{"Arabic_theh"} = 0x5cb;
	$Keysyms{"Arabic_jeem"} = 0x5cc;
	$Keysyms{"Arabic_hah"} = 0x5cd;
	$Keysyms{"Arabic_khah"} = 0x5ce;
	$Keysyms{"Arabic_dal"} = 0x5cf;
	$Keysyms{"Arabic_thal"} = 0x5d0;
	$Keysyms{"Arabic_ra"} = 0x5d1;
	$Keysyms{"Arabic_zain"} = 0x5d2;
	$Keysyms{"Arabic_seen"} = 0x5d3;
	$Keysyms{"Arabic_sheen"} = 0x5d4;
	$Keysyms{"Arabic_sad"} = 0x5d5;
	$Keysyms{"Arabic_dad"} = 0x5d6;
	$Keysyms{"Arabic_tah"} = 0x5d7;
	$Keysyms{"Arabic_zah"} = 0x5d8;
	$Keysyms{"Arabic_ain"} = 0x5d9;
	$Keysyms{"Arabic_ghain"} = 0x5da;
	$Keysyms{"Arabic_tatweel"} = 0x5e0;
	$Keysyms{"Arabic_feh"} = 0x5e1;
	$Keysyms{"Arabic_qaf"} = 0x5e2;
	$Keysyms{"Arabic_kaf"} = 0x5e3;
	$Keysyms{"Arabic_lam"} = 0x5e4;
	$Keysyms{"Arabic_meem"} = 0x5e5;
	$Keysyms{"Arabic_noon"} = 0x5e6;
	$Keysyms{"Arabic_ha"} = 0x5e7;
	$Keysyms{"Arabic_heh"} = 0x5e7;  # deprecated 
	$Keysyms{"Arabic_waw"} = 0x5e8;
	$Keysyms{"Arabic_alefmaksura"} = 0x5e9;
	$Keysyms{"Arabic_yeh"} = 0x5ea;
	$Keysyms{"Arabic_fathatan"} = 0x5eb;
	$Keysyms{"Arabic_dammatan"} = 0x5ec;
	$Keysyms{"Arabic_kasratan"} = 0x5ed;
	$Keysyms{"Arabic_fatha"} = 0x5ee;
	$Keysyms{"Arabic_damma"} = 0x5ef;
	$Keysyms{"Arabic_kasra"} = 0x5f0;
	$Keysyms{"Arabic_shadda"} = 0x5f1;
	$Keysyms{"Arabic_sukun"} = 0x5f2;
	$Keysyms{"Arabic_switch"} = 0xFF7E;  # Alias for mode_switch 
    }
#endif # XK_ARABIC 

#
# * Cyrillic
# * Byte 3 = 6
    
#ifdef XK_CYRILLIC
    if ($KL{'CYRILLIC'}) {
	$Keysyms{"Serbian_dje"} = 0x6a1;
	$Keysyms{"Macedonia_gje"} = 0x6a2;
	$Keysyms{"Cyrillic_io"} = 0x6a3;
	$Keysyms{"Ukrainian_ie"} = 0x6a4;
	$Keysyms{"Ukranian_je"} = 0x6a4;  # deprecated 
	$Keysyms{"Macedonia_dse"} = 0x6a5;
	$Keysyms{"Ukrainian_i"} = 0x6a6;
	$Keysyms{"Ukranian_i"} = 0x6a6;  # deprecated 
	$Keysyms{"Ukrainian_yi"} = 0x6a7;
	$Keysyms{"Ukranian_yi"} = 0x6a7;  # deprecated 
	$Keysyms{"Cyrillic_je"} = 0x6a8;
	$Keysyms{"Serbian_je"} = 0x6a8;  # deprecated 
	$Keysyms{"Cyrillic_lje"} = 0x6a9;
	$Keysyms{"Serbian_lje"} = 0x6a9;  # deprecated 
	$Keysyms{"Cyrillic_nje"} = 0x6aa;
	$Keysyms{"Serbian_nje"} = 0x6aa;  # deprecated 
	$Keysyms{"Serbian_tshe"} = 0x6ab;
	$Keysyms{"Macedonia_kje"} = 0x6ac;
	$Keysyms{"Byelorussian_shortu"} = 0x6ae;
	$Keysyms{"Cyrillic_dzhe"} = 0x6af;
	$Keysyms{"Serbian_dze"} = 0x6af;  # deprecated 
	$Keysyms{"numerosign"} = 0x6b0;
	$Keysyms{"Serbian_DJE"} = 0x6b1;
	$Keysyms{"Macedonia_GJE"} = 0x6b2;
	$Keysyms{"Cyrillic_IO"} = 0x6b3;
	$Keysyms{"Ukrainian_IE"} = 0x6b4;
	$Keysyms{"Ukranian_JE"} = 0x6b4;  # deprecated 
	$Keysyms{"Macedonia_DSE"} = 0x6b5;
	$Keysyms{"Ukrainian_I"} = 0x6b6;
	$Keysyms{"Ukranian_I"} = 0x6b6;  # deprecated 
	$Keysyms{"Ukrainian_YI"} = 0x6b7;
	$Keysyms{"Ukranian_YI"} = 0x6b7;  # deprecated 
	$Keysyms{"Cyrillic_JE"} = 0x6b8;
	$Keysyms{"Serbian_JE"} = 0x6b8;  # deprecated 
	$Keysyms{"Cyrillic_LJE"} = 0x6b9;
	$Keysyms{"Serbian_LJE"} = 0x6b9;  # deprecated 
	$Keysyms{"Cyrillic_NJE"} = 0x6ba;
	$Keysyms{"Serbian_NJE"} = 0x6ba;  # deprecated 
	$Keysyms{"Serbian_TSHE"} = 0x6bb;
	$Keysyms{"Macedonia_KJE"} = 0x6bc;
	$Keysyms{"Byelorussian_SHORTU"} = 0x6be;
	$Keysyms{"Cyrillic_DZHE"} = 0x6bf;
	$Keysyms{"Serbian_DZE"} = 0x6bf;  # deprecated 
	$Keysyms{"Cyrillic_yu"} = 0x6c0;
	$Keysyms{"Cyrillic_a"} = 0x6c1;
	$Keysyms{"Cyrillic_be"} = 0x6c2;
	$Keysyms{"Cyrillic_tse"} = 0x6c3;
	$Keysyms{"Cyrillic_de"} = 0x6c4;
	$Keysyms{"Cyrillic_ie"} = 0x6c5;
	$Keysyms{"Cyrillic_ef"} = 0x6c6;
	$Keysyms{"Cyrillic_ghe"} = 0x6c7;
	$Keysyms{"Cyrillic_ha"} = 0x6c8;
	$Keysyms{"Cyrillic_i"} = 0x6c9;
	$Keysyms{"Cyrillic_shorti"} = 0x6ca;
	$Keysyms{"Cyrillic_ka"} = 0x6cb;
	$Keysyms{"Cyrillic_el"} = 0x6cc;
	$Keysyms{"Cyrillic_em"} = 0x6cd;
	$Keysyms{"Cyrillic_en"} = 0x6ce;
	$Keysyms{"Cyrillic_o"} = 0x6cf;
	$Keysyms{"Cyrillic_pe"} = 0x6d0;
	$Keysyms{"Cyrillic_ya"} = 0x6d1;
	$Keysyms{"Cyrillic_er"} = 0x6d2;
	$Keysyms{"Cyrillic_es"} = 0x6d3;
	$Keysyms{"Cyrillic_te"} = 0x6d4;
	$Keysyms{"Cyrillic_u"} = 0x6d5;
	$Keysyms{"Cyrillic_zhe"} = 0x6d6;
	$Keysyms{"Cyrillic_ve"} = 0x6d7;
	$Keysyms{"Cyrillic_softsign"} = 0x6d8;
	$Keysyms{"Cyrillic_yeru"} = 0x6d9;
	$Keysyms{"Cyrillic_ze"} = 0x6da;
	$Keysyms{"Cyrillic_sha"} = 0x6db;
	$Keysyms{"Cyrillic_e"} = 0x6dc;
	$Keysyms{"Cyrillic_shcha"} = 0x6dd;
	$Keysyms{"Cyrillic_che"} = 0x6de;
	$Keysyms{"Cyrillic_hardsign"} = 0x6df;
	$Keysyms{"Cyrillic_YU"} = 0x6e0;
	$Keysyms{"Cyrillic_A"} = 0x6e1;
	$Keysyms{"Cyrillic_BE"} = 0x6e2;
	$Keysyms{"Cyrillic_TSE"} = 0x6e3;
	$Keysyms{"Cyrillic_DE"} = 0x6e4;
	$Keysyms{"Cyrillic_IE"} = 0x6e5;
	$Keysyms{"Cyrillic_EF"} = 0x6e6;
	$Keysyms{"Cyrillic_GHE"} = 0x6e7;
	$Keysyms{"Cyrillic_HA"} = 0x6e8;
	$Keysyms{"Cyrillic_I"} = 0x6e9;
	$Keysyms{"Cyrillic_SHORTI"} = 0x6ea;
	$Keysyms{"Cyrillic_KA"} = 0x6eb;
	$Keysyms{"Cyrillic_EL"} = 0x6ec;
	$Keysyms{"Cyrillic_EM"} = 0x6ed;
	$Keysyms{"Cyrillic_EN"} = 0x6ee;
	$Keysyms{"Cyrillic_O"} = 0x6ef;
	$Keysyms{"Cyrillic_PE"} = 0x6f0;
	$Keysyms{"Cyrillic_YA"} = 0x6f1;
	$Keysyms{"Cyrillic_ER"} = 0x6f2;
	$Keysyms{"Cyrillic_ES"} = 0x6f3;
	$Keysyms{"Cyrillic_TE"} = 0x6f4;
	$Keysyms{"Cyrillic_U"} = 0x6f5;
	$Keysyms{"Cyrillic_ZHE"} = 0x6f6;
	$Keysyms{"Cyrillic_VE"} = 0x6f7;
	$Keysyms{"Cyrillic_SOFTSIGN"} = 0x6f8;
	$Keysyms{"Cyrillic_YERU"} = 0x6f9;
	$Keysyms{"Cyrillic_ZE"} = 0x6fa;
	$Keysyms{"Cyrillic_SHA"} = 0x6fb;
	$Keysyms{"Cyrillic_E"} = 0x6fc;
	$Keysyms{"Cyrillic_SHCHA"} = 0x6fd;
	$Keysyms{"Cyrillic_CHE"} = 0x6fe;
	$Keysyms{"Cyrillic_HARDSIGN"} = 0x6ff;
    }
#endif # XK_CYRILLIC 

#
# * Greek
# * Byte 3 = 7
    

#ifdef XK_GREEK
    if ($KL{'GREEK'}) {
	$Keysyms{"Greek_ALPHAaccent"} = 0x7a1;
	$Keysyms{"Greek_EPSILONaccent"} = 0x7a2;
	$Keysyms{"Greek_ETAaccent"} = 0x7a3;
	$Keysyms{"Greek_IOTAaccent"} = 0x7a4;
	$Keysyms{"Greek_IOTAdiaeresis"} = 0x7a5;
	$Keysyms{"Greek_OMICRONaccent"} = 0x7a7;
	$Keysyms{"Greek_UPSILONaccent"} = 0x7a8;
	$Keysyms{"Greek_UPSILONdieresis"} = 0x7a9;
	$Keysyms{"Greek_OMEGAaccent"} = 0x7ab;
	$Keysyms{"Greek_accentdieresis"} = 0x7ae;
	$Keysyms{"Greek_horizbar"} = 0x7af;
	$Keysyms{"Greek_alphaaccent"} = 0x7b1;
	$Keysyms{"Greek_epsilonaccent"} = 0x7b2;
	$Keysyms{"Greek_etaaccent"} = 0x7b3;
	$Keysyms{"Greek_iotaaccent"} = 0x7b4;
	$Keysyms{"Greek_iotadieresis"} = 0x7b5;
	$Keysyms{"Greek_iotaaccentdieresis"} = 0x7b6;
	$Keysyms{"Greek_omicronaccent"} = 0x7b7;
	$Keysyms{"Greek_upsilonaccent"} = 0x7b8;
	$Keysyms{"Greek_upsilondieresis"} = 0x7b9;
	$Keysyms{"Greek_upsilonaccentdieresis"} = 0x7ba;
	$Keysyms{"Greek_omegaaccent"} = 0x7bb;
	$Keysyms{"Greek_ALPHA"} = 0x7c1;
	$Keysyms{"Greek_BETA"} = 0x7c2;
	$Keysyms{"Greek_GAMMA"} = 0x7c3;
	$Keysyms{"Greek_DELTA"} = 0x7c4;
	$Keysyms{"Greek_EPSILON"} = 0x7c5;
	$Keysyms{"Greek_ZETA"} = 0x7c6;
	$Keysyms{"Greek_ETA"} = 0x7c7;
	$Keysyms{"Greek_THETA"} = 0x7c8;
	$Keysyms{"Greek_IOTA"} = 0x7c9;
	$Keysyms{"Greek_KAPPA"} = 0x7ca;
	$Keysyms{"Greek_LAMDA"} = 0x7cb;
	$Keysyms{"Greek_LAMBDA"} = 0x7cb;
	$Keysyms{"Greek_MU"} = 0x7cc;
	$Keysyms{"Greek_NU"} = 0x7cd;
	$Keysyms{"Greek_XI"} = 0x7ce;
	$Keysyms{"Greek_OMICRON"} = 0x7cf;
	$Keysyms{"Greek_PI"} = 0x7d0;
	$Keysyms{"Greek_RHO"} = 0x7d1;
	$Keysyms{"Greek_SIGMA"} = 0x7d2;
	$Keysyms{"Greek_TAU"} = 0x7d4;
	$Keysyms{"Greek_UPSILON"} = 0x7d5;
	$Keysyms{"Greek_PHI"} = 0x7d6;
	$Keysyms{"Greek_CHI"} = 0x7d7;
	$Keysyms{"Greek_PSI"} = 0x7d8;
	$Keysyms{"Greek_OMEGA"} = 0x7d9;
	$Keysyms{"Greek_alpha"} = 0x7e1;
	$Keysyms{"Greek_beta"} = 0x7e2;
	$Keysyms{"Greek_gamma"} = 0x7e3;
	$Keysyms{"Greek_delta"} = 0x7e4;
	$Keysyms{"Greek_epsilon"} = 0x7e5;
	$Keysyms{"Greek_zeta"} = 0x7e6;
	$Keysyms{"Greek_eta"} = 0x7e7;
	$Keysyms{"Greek_theta"} = 0x7e8;
	$Keysyms{"Greek_iota"} = 0x7e9;
	$Keysyms{"Greek_kappa"} = 0x7ea;
	$Keysyms{"Greek_lamda"} = 0x7eb;
	$Keysyms{"Greek_lambda"} = 0x7eb;
	$Keysyms{"Greek_mu"} = 0x7ec;
	$Keysyms{"Greek_nu"} = 0x7ed;
	$Keysyms{"Greek_xi"} = 0x7ee;
	$Keysyms{"Greek_omicron"} = 0x7ef;
	$Keysyms{"Greek_pi"} = 0x7f0;
	$Keysyms{"Greek_rho"} = 0x7f1;
	$Keysyms{"Greek_sigma"} = 0x7f2;
	$Keysyms{"Greek_finalsmallsigma"} = 0x7f3;
	$Keysyms{"Greek_tau"} = 0x7f4;
	$Keysyms{"Greek_upsilon"} = 0x7f5;
	$Keysyms{"Greek_phi"} = 0x7f6;
	$Keysyms{"Greek_chi"} = 0x7f7;
	$Keysyms{"Greek_psi"} = 0x7f8;
	$Keysyms{"Greek_omega"} = 0x7f9;
	$Keysyms{"Greek_switch"} = 0xFF7E;  # Alias for mode_switch 
    }
#endif # XK_GREEK 

#
# * Technical
# * Byte 3 = 8
    

#ifdef XK_TECHNICAL
    if ($KL{'TECHNICAL'}) {
	$Keysyms{"leftradical"} = 0x8a1;
	$Keysyms{"topleftradical"} = 0x8a2;
	$Keysyms{"horizconnector"} = 0x8a3;
	$Keysyms{"topintegral"} = 0x8a4;
	$Keysyms{"botintegral"} = 0x8a5;
	$Keysyms{"vertconnector"} = 0x8a6;
	$Keysyms{"topleftsqbracket"} = 0x8a7;
	$Keysyms{"botleftsqbracket"} = 0x8a8;
	$Keysyms{"toprightsqbracket"} = 0x8a9;
	$Keysyms{"botrightsqbracket"} = 0x8aa;
	$Keysyms{"topleftparens"} = 0x8ab;
	$Keysyms{"botleftparens"} = 0x8ac;
	$Keysyms{"toprightparens"} = 0x8ad;
	$Keysyms{"botrightparens"} = 0x8ae;
	$Keysyms{"leftmiddlecurlybrace"} = 0x8af;
	$Keysyms{"rightmiddlecurlybrace"} = 0x8b0;
	$Keysyms{"topleftsummation"} = 0x8b1;
	$Keysyms{"botleftsummation"} = 0x8b2;
	$Keysyms{"topvertsummationconnector"} = 0x8b3;
	$Keysyms{"botvertsummationconnector"} = 0x8b4;
	$Keysyms{"toprightsummation"} = 0x8b5;
	$Keysyms{"botrightsummation"} = 0x8b6;
	$Keysyms{"rightmiddlesummation"} = 0x8b7;
	$Keysyms{"lessthanequal"} = 0x8bc;
	$Keysyms{"notequal"} = 0x8bd;
	$Keysyms{"greaterthanequal"} = 0x8be;
	$Keysyms{"integral"} = 0x8bf;
	$Keysyms{"therefore"} = 0x8c0;
	$Keysyms{"variation"} = 0x8c1;
	$Keysyms{"infinity"} = 0x8c2;
	$Keysyms{"nabla"} = 0x8c5;
	$Keysyms{"approximate"} = 0x8c8;
	$Keysyms{"similarequal"} = 0x8c9;
	$Keysyms{"ifonlyif"} = 0x8cd;
	$Keysyms{"implies"} = 0x8ce;
	$Keysyms{"identical"} = 0x8cf;
	$Keysyms{"radical"} = 0x8d6;
	$Keysyms{"includedin"} = 0x8da;
	$Keysyms{"includes"} = 0x8db;
	$Keysyms{"intersection"} = 0x8dc;
	$Keysyms{"union"} = 0x8dd;
	$Keysyms{"logicaland"} = 0x8de;
	$Keysyms{"logicalor"} = 0x8df;
	$Keysyms{"partialderivative"} = 0x8ef;
	$Keysyms{"function"} = 0x8f6;
	$Keysyms{"leftarrow"} = 0x8fb;
	$Keysyms{"uparrow"} = 0x8fc;
	$Keysyms{"rightarrow"} = 0x8fd;
	$Keysyms{"downarrow"} = 0x8fe;
    }
#endif # XK_TECHNICAL 

#
# *  Special
# *  Byte 3 = 9
    

#ifdef XK_SPECIAL
    if ($KL{'SPECIAL'}) {
	$Keysyms{"blank"} = 0x9df;
	$Keysyms{"soliddiamond"} = 0x9e0;
	$Keysyms{"checkerboard"} = 0x9e1;
	$Keysyms{"ht"} = 0x9e2;
	$Keysyms{"ff"} = 0x9e3;
	$Keysyms{"cr"} = 0x9e4;
	$Keysyms{"lf"} = 0x9e5;
	$Keysyms{"nl"} = 0x9e8;
	$Keysyms{"vt"} = 0x9e9;
	$Keysyms{"lowrightcorner"} = 0x9ea;
	$Keysyms{"uprightcorner"} = 0x9eb;
	$Keysyms{"upleftcorner"} = 0x9ec;
	$Keysyms{"lowleftcorner"} = 0x9ed;
	$Keysyms{"crossinglines"} = 0x9ee;
	$Keysyms{"horizlinescan1"} = 0x9ef;
	$Keysyms{"horizlinescan3"} = 0x9f0;
	$Keysyms{"horizlinescan5"} = 0x9f1;
	$Keysyms{"horizlinescan7"} = 0x9f2;
	$Keysyms{"horizlinescan9"} = 0x9f3;
	$Keysyms{"leftt"} = 0x9f4;
	$Keysyms{"rightt"} = 0x9f5;
	$Keysyms{"bott"} = 0x9f6;
	$Keysyms{"topt"} = 0x9f7;
	$Keysyms{"vertbar"} = 0x9f8;
    }
#endif # XK_SPECIAL 

#
# *  Publishing
# *  Byte 3 = a
    

#ifdef XK_PUBLISHING
    if ($KL{'PUBLISHING'}) {
	$Keysyms{"emspace"} = 0xaa1;
	$Keysyms{"enspace"} = 0xaa2;
	$Keysyms{"em3space"} = 0xaa3;
	$Keysyms{"em4space"} = 0xaa4;
	$Keysyms{"digitspace"} = 0xaa5;
	$Keysyms{"punctspace"} = 0xaa6;
	$Keysyms{"thinspace"} = 0xaa7;
	$Keysyms{"hairspace"} = 0xaa8;
	$Keysyms{"emdash"} = 0xaa9;
	$Keysyms{"endash"} = 0xaaa;
	$Keysyms{"signifblank"} = 0xaac;
	$Keysyms{"ellipsis"} = 0xaae;
	$Keysyms{"doubbaselinedot"} = 0xaaf;
	$Keysyms{"onethird"} = 0xab0;
	$Keysyms{"twothirds"} = 0xab1;
	$Keysyms{"onefifth"} = 0xab2;
	$Keysyms{"twofifths"} = 0xab3;
	$Keysyms{"threefifths"} = 0xab4;
	$Keysyms{"fourfifths"} = 0xab5;
	$Keysyms{"onesixth"} = 0xab6;
	$Keysyms{"fivesixths"} = 0xab7;
	$Keysyms{"careof"} = 0xab8;
	$Keysyms{"figdash"} = 0xabb;
	$Keysyms{"leftanglebracket"} = 0xabc;
	$Keysyms{"decimalpoint"} = 0xabd;
	$Keysyms{"rightanglebracket"} = 0xabe;
	$Keysyms{"marker"} = 0xabf;
	$Keysyms{"oneeighth"} = 0xac3;
	$Keysyms{"threeeighths"} = 0xac4;
	$Keysyms{"fiveeighths"} = 0xac5;
	$Keysyms{"seveneighths"} = 0xac6;
	$Keysyms{"trademark"} = 0xac9;
	$Keysyms{"signaturemark"} = 0xaca;
	$Keysyms{"trademarkincircle"} = 0xacb;
	$Keysyms{"leftopentriangle"} = 0xacc;
	$Keysyms{"rightopentriangle"} = 0xacd;
	$Keysyms{"emopencircle"} = 0xace;
	$Keysyms{"emopenrectangle"} = 0xacf;
	$Keysyms{"leftsinglequotemark"} = 0xad0;
	$Keysyms{"rightsinglequotemark"} = 0xad1;
	$Keysyms{"leftdoublequotemark"} = 0xad2;
	$Keysyms{"rightdoublequotemark"} = 0xad3;
	$Keysyms{"prescription"} = 0xad4;
	$Keysyms{"minutes"} = 0xad6;
	$Keysyms{"seconds"} = 0xad7;
	$Keysyms{"latincross"} = 0xad9;
	$Keysyms{"hexagram"} = 0xada;
	$Keysyms{"filledrectbullet"} = 0xadb;
	$Keysyms{"filledlefttribullet"} = 0xadc;
	$Keysyms{"filledrighttribullet"} = 0xadd;
	$Keysyms{"emfilledcircle"} = 0xade;
	$Keysyms{"emfilledrect"} = 0xadf;
	$Keysyms{"enopencircbullet"} = 0xae0;
	$Keysyms{"enopensquarebullet"} = 0xae1;
	$Keysyms{"openrectbullet"} = 0xae2;
	$Keysyms{"opentribulletup"} = 0xae3;
	$Keysyms{"opentribulletdown"} = 0xae4;
	$Keysyms{"openstar"} = 0xae5;
	$Keysyms{"enfilledcircbullet"} = 0xae6;
	$Keysyms{"enfilledsqbullet"} = 0xae7;
	$Keysyms{"filledtribulletup"} = 0xae8;
	$Keysyms{"filledtribulletdown"} = 0xae9;
	$Keysyms{"leftpointer"} = 0xaea;
	$Keysyms{"rightpointer"} = 0xaeb;
	$Keysyms{"club"} = 0xaec;
	$Keysyms{"diamond"} = 0xaed;
	$Keysyms{"heart"} = 0xaee;
	$Keysyms{"maltesecross"} = 0xaf0;
	$Keysyms{"dagger"} = 0xaf1;
	$Keysyms{"doubledagger"} = 0xaf2;
	$Keysyms{"checkmark"} = 0xaf3;
	$Keysyms{"ballotcross"} = 0xaf4;
	$Keysyms{"musicalsharp"} = 0xaf5;
	$Keysyms{"musicalflat"} = 0xaf6;
	$Keysyms{"malesymbol"} = 0xaf7;
	$Keysyms{"femalesymbol"} = 0xaf8;
	$Keysyms{"telephone"} = 0xaf9;
	$Keysyms{"telephonerecorder"} = 0xafa;
	$Keysyms{"phonographcopyright"} = 0xafb;
	$Keysyms{"caret"} = 0xafc;
	$Keysyms{"singlelowquotemark"} = 0xafd;
	$Keysyms{"doublelowquotemark"} = 0xafe;
	$Keysyms{"cursor"} = 0xaff;
    }
#endif # XK_PUBLISHING 

#
# *  APL
# *  Byte 3 = b
    

#ifdef XK_APL
    if ($KL{'APL'}) {
	$Keysyms{"leftcaret"} = 0xba3;
	$Keysyms{"rightcaret"} = 0xba6;
	$Keysyms{"downcaret"} = 0xba8;
	$Keysyms{"upcaret"} = 0xba9;
	$Keysyms{"overbar"} = 0xbc0;
	$Keysyms{"downtack"} = 0xbc2;
	$Keysyms{"upshoe"} = 0xbc3;
	$Keysyms{"downstile"} = 0xbc4;
	$Keysyms{"underbar"} = 0xbc6;
	$Keysyms{"jot"} = 0xbca;
	$Keysyms{"quad"} = 0xbcc;
	$Keysyms{"uptack"} = 0xbce;
	$Keysyms{"circle"} = 0xbcf;
	$Keysyms{"upstile"} = 0xbd3;
	$Keysyms{"downshoe"} = 0xbd6;
	$Keysyms{"rightshoe"} = 0xbd8;
	$Keysyms{"leftshoe"} = 0xbda;
	$Keysyms{"lefttack"} = 0xbdc;
	$Keysyms{"righttack"} = 0xbfc;
    }
#endif # XK_APL 

#
# * Hebrew
# * Byte 3 = c
    

#ifdef XK_HEBREW
    if ($KL{'HEBREW'}) {
	$Keysyms{"hebrew_doublelowline"} = 0xcdf;
	$Keysyms{"hebrew_aleph"} = 0xce0;
	$Keysyms{"hebrew_bet"} = 0xce1;
	$Keysyms{"hebrew_beth"} = 0xce1;  # deprecated 
	$Keysyms{"hebrew_gimel"} = 0xce2;
	$Keysyms{"hebrew_gimmel"} = 0xce2;  # deprecated 
	$Keysyms{"hebrew_dalet"} = 0xce3;
	$Keysyms{"hebrew_daleth"} = 0xce3;  # deprecated 
	$Keysyms{"hebrew_he"} = 0xce4;
	$Keysyms{"hebrew_waw"} = 0xce5;
	$Keysyms{"hebrew_zain"} = 0xce6;
	$Keysyms{"hebrew_zayin"} = 0xce6;  # deprecated 
	$Keysyms{"hebrew_chet"} = 0xce7;
	$Keysyms{"hebrew_het"} = 0xce7;  # deprecated 
	$Keysyms{"hebrew_tet"} = 0xce8;
	$Keysyms{"hebrew_teth"} = 0xce8;  # deprecated 
	$Keysyms{"hebrew_yod"} = 0xce9;
	$Keysyms{"hebrew_finalkaph"} = 0xcea;
	$Keysyms{"hebrew_kaph"} = 0xceb;
	$Keysyms{"hebrew_lamed"} = 0xcec;
	$Keysyms{"hebrew_finalmem"} = 0xced;
	$Keysyms{"hebrew_mem"} = 0xcee;
	$Keysyms{"hebrew_finalnun"} = 0xcef;
	$Keysyms{"hebrew_nun"} = 0xcf0;
	$Keysyms{"hebrew_samech"} = 0xcf1;
	$Keysyms{"hebrew_samekh"} = 0xcf1;  # deprecated 
	$Keysyms{"hebrew_ayin"} = 0xcf2;
	$Keysyms{"hebrew_finalpe"} = 0xcf3;
	$Keysyms{"hebrew_pe"} = 0xcf4;
	$Keysyms{"hebrew_finalzade"} = 0xcf5;
	$Keysyms{"hebrew_finalzadi"} = 0xcf5;  # deprecated 
	$Keysyms{"hebrew_zade"} = 0xcf6;
	$Keysyms{"hebrew_zadi"} = 0xcf6;  # deprecated 
	$Keysyms{"hebrew_qoph"} = 0xcf7;
	$Keysyms{"hebrew_kuf"} = 0xcf7;  # deprecated 
	$Keysyms{"hebrew_resh"} = 0xcf8;
	$Keysyms{"hebrew_shin"} = 0xcf9;
	$Keysyms{"hebrew_taw"} = 0xcfa;
	$Keysyms{"hebrew_taf"} = 0xcfa;  # deprecated 
	$Keysyms{"Hebrew_switch"} = 0xFF7E;  # Alias for mode_switch 
    }
#endif # XK_HEBREW 

#
# * Thai
# * Byte 3 = d
    

#ifdef XK_THAI
    if ($KL{'THAI'}) {
	$Keysyms{"Thai_kokai"} = 0xda1;
	$Keysyms{"Thai_khokhai"} = 0xda2;
	$Keysyms{"Thai_khokhuat"} = 0xda3;
	$Keysyms{"Thai_khokhwai"} = 0xda4;
	$Keysyms{"Thai_khokhon"} = 0xda5;
	$Keysyms{"Thai_khorakhang"} = 0xda6;  
	$Keysyms{"Thai_ngongu"} = 0xda7;  
	$Keysyms{"Thai_chochan"} = 0xda8;  
	$Keysyms{"Thai_choching"} = 0xda9;   
	$Keysyms{"Thai_chochang"} = 0xdaa;  
	$Keysyms{"Thai_soso"} = 0xdab;
	$Keysyms{"Thai_chochoe"} = 0xdac;
	$Keysyms{"Thai_yoying"} = 0xdad;
	$Keysyms{"Thai_dochada"} = 0xdae;
	$Keysyms{"Thai_topatak"} = 0xdaf;
	$Keysyms{"Thai_thothan"} = 0xdb0;
	$Keysyms{"Thai_thonangmontho"} = 0xdb1;
	$Keysyms{"Thai_thophuthao"} = 0xdb2;
	$Keysyms{"Thai_nonen"} = 0xdb3;
	$Keysyms{"Thai_dodek"} = 0xdb4;
	$Keysyms{"Thai_totao"} = 0xdb5;
	$Keysyms{"Thai_thothung"} = 0xdb6;
	$Keysyms{"Thai_thothahan"} = 0xdb7;
	$Keysyms{"Thai_thothong"} = 0xdb8;
	$Keysyms{"Thai_nonu"} = 0xdb9;
	$Keysyms{"Thai_bobaimai"} = 0xdba;
	$Keysyms{"Thai_popla"} = 0xdbb;
	$Keysyms{"Thai_phophung"} = 0xdbc;
	$Keysyms{"Thai_fofa"} = 0xdbd;
	$Keysyms{"Thai_phophan"} = 0xdbe;
	$Keysyms{"Thai_fofan"} = 0xdbf;
	$Keysyms{"Thai_phosamphao"} = 0xdc0;
	$Keysyms{"Thai_moma"} = 0xdc1;
	$Keysyms{"Thai_yoyak"} = 0xdc2;
	$Keysyms{"Thai_rorua"} = 0xdc3;
	$Keysyms{"Thai_ru"} = 0xdc4;
	$Keysyms{"Thai_loling"} = 0xdc5;
	$Keysyms{"Thai_lu"} = 0xdc6;
	$Keysyms{"Thai_wowaen"} = 0xdc7;
	$Keysyms{"Thai_sosala"} = 0xdc8;
	$Keysyms{"Thai_sorusi"} = 0xdc9;
	$Keysyms{"Thai_sosua"} = 0xdca;
	$Keysyms{"Thai_hohip"} = 0xdcb;
	$Keysyms{"Thai_lochula"} = 0xdcc;
	$Keysyms{"Thai_oang"} = 0xdcd;
	$Keysyms{"Thai_honokhuk"} = 0xdce;
	$Keysyms{"Thai_paiyannoi"} = 0xdcf;
	$Keysyms{"Thai_saraa"} = 0xdd0;
	$Keysyms{"Thai_maihanakat"} = 0xdd1;
	$Keysyms{"Thai_saraaa"} = 0xdd2;
	$Keysyms{"Thai_saraam"} = 0xdd3;
	$Keysyms{"Thai_sarai"} = 0xdd4;   
	$Keysyms{"Thai_saraii"} = 0xdd5;   
	$Keysyms{"Thai_saraue"} = 0xdd6;    
	$Keysyms{"Thai_sarauee"} = 0xdd7;    
	$Keysyms{"Thai_sarau"} = 0xdd8;    
	$Keysyms{"Thai_sarauu"} = 0xdd9;   
	$Keysyms{"Thai_phinthu"} = 0xdda;
	$Keysyms{"Thai_maihanakat_maitho"} = 0xdde;
	$Keysyms{"Thai_baht"} = 0xddf;
	$Keysyms{"Thai_sarae"} = 0xde0;    
	$Keysyms{"Thai_saraae"} = 0xde1;
	$Keysyms{"Thai_sarao"} = 0xde2;
	$Keysyms{"Thai_saraaimaimuan"} = 0xde3;   
	$Keysyms{"Thai_saraaimaimalai"} = 0xde4;  
	$Keysyms{"Thai_lakkhangyao"} = 0xde5;
	$Keysyms{"Thai_maiyamok"} = 0xde6;
	$Keysyms{"Thai_maitaikhu"} = 0xde7;
	$Keysyms{"Thai_maiek"} = 0xde8;   
	$Keysyms{"Thai_maitho"} = 0xde9;
	$Keysyms{"Thai_maitri"} = 0xdea;
	$Keysyms{"Thai_maichattawa"} = 0xdeb;
	$Keysyms{"Thai_thanthakhat"} = 0xdec;
	$Keysyms{"Thai_nikhahit"} = 0xded;
	$Keysyms{"Thai_leksun"} = 0xdf0; 
	$Keysyms{"Thai_leknung"} = 0xdf1;  
	$Keysyms{"Thai_leksong"} = 0xdf2; 
	$Keysyms{"Thai_leksam"} = 0xdf3;
	$Keysyms{"Thai_leksi"} = 0xdf4;  
	$Keysyms{"Thai_lekha"} = 0xdf5;  
	$Keysyms{"Thai_lekhok"} = 0xdf6;  
	$Keysyms{"Thai_lekchet"} = 0xdf7;  
	$Keysyms{"Thai_lekpaet"} = 0xdf8;  
	$Keysyms{"Thai_lekkao"} = 0xdf9; 
    }
#endif # XK_THAI 

#
# *   Korean
# *   Byte 3 = e
    

#ifdef XK_KOREAN
    if ($KL{'KOREAN'}) {
	$Keysyms{"Hangul"} = 0xff31;    # Hangul start/stop(toggle) 
	$Keysyms{"Hangul_Start"} = 0xff32;    # Hangul start 
	$Keysyms{"Hangul_End"} = 0xff33;    # Hangul end, English start 
	$Keysyms{"Hangul_Hanja"} = 0xff34;    # Start Hangul->Hanja Conversion 
	$Keysyms{"Hangul_Jamo"} = 0xff35;    # Hangul Jamo mode 
	$Keysyms{"Hangul_Romaja"} = 0xff36;    # Hangul Romaja mode 
	$Keysyms{"Hangul_Codeinput"} = 0xff37;    # Hangul code input mode 
	$Keysyms{"Hangul_Jeonja"} = 0xff38;    # Jeonja mode 
	$Keysyms{"Hangul_Banja"} = 0xff39;    # Banja mode 
	$Keysyms{"Hangul_PreHanja"} = 0xff3a;    # Pre Hanja conversion 
	$Keysyms{"Hangul_PostHanja"} = 0xff3b;    # Post Hanja conversion 
	$Keysyms{"Hangul_SingleCandidate"} = 0xff3c;    # Single candidate 
	$Keysyms{"Hangul_MultipleCandidate"} = 0xff3d;    # Multiple candidate 
	$Keysyms{"Hangul_PreviousCandidate"} = 0xff3e;    # Previous candidate 
	$Keysyms{"Hangul_Special"} = 0xff3f;    # Special symbols 
	$Keysyms{"Hangul_switch"} = 0xFF7E;    # Alias for mode_switch 

# Hangul Consonant Characters 
	$Keysyms{"Hangul_Kiyeog"} = 0xea1;
	$Keysyms{"Hangul_SsangKiyeog"} = 0xea2;
	$Keysyms{"Hangul_KiyeogSios"} = 0xea3;
	$Keysyms{"Hangul_Nieun"} = 0xea4;
	$Keysyms{"Hangul_NieunJieuj"} = 0xea5;
	$Keysyms{"Hangul_NieunHieuh"} = 0xea6;
	$Keysyms{"Hangul_Dikeud"} = 0xea7;
	$Keysyms{"Hangul_SsangDikeud"} = 0xea8;
	$Keysyms{"Hangul_Rieul"} = 0xea9;
	$Keysyms{"Hangul_RieulKiyeog"} = 0xeaa;
	$Keysyms{"Hangul_RieulMieum"} = 0xeab;
	$Keysyms{"Hangul_RieulPieub"} = 0xeac;
	$Keysyms{"Hangul_RieulSios"} = 0xead;
	$Keysyms{"Hangul_RieulTieut"} = 0xeae;
	$Keysyms{"Hangul_RieulPhieuf"} = 0xeaf;
	$Keysyms{"Hangul_RieulHieuh"} = 0xeb0;
	$Keysyms{"Hangul_Mieum"} = 0xeb1;
	$Keysyms{"Hangul_Pieub"} = 0xeb2;
	$Keysyms{"Hangul_SsangPieub"} = 0xeb3;
	$Keysyms{"Hangul_PieubSios"} = 0xeb4;
	$Keysyms{"Hangul_Sios"} = 0xeb5;
	$Keysyms{"Hangul_SsangSios"} = 0xeb6;
	$Keysyms{"Hangul_Ieung"} = 0xeb7;
	$Keysyms{"Hangul_Jieuj"} = 0xeb8;
	$Keysyms{"Hangul_SsangJieuj"} = 0xeb9;
	$Keysyms{"Hangul_Cieuc"} = 0xeba;
	$Keysyms{"Hangul_Khieuq"} = 0xebb;
	$Keysyms{"Hangul_Tieut"} = 0xebc;
	$Keysyms{"Hangul_Phieuf"} = 0xebd;
	$Keysyms{"Hangul_Hieuh"} = 0xebe;

# Hangul Vowel Characters 
	$Keysyms{"Hangul_A"} = 0xebf;
	$Keysyms{"Hangul_AE"} = 0xec0;
	$Keysyms{"Hangul_YA"} = 0xec1;
	$Keysyms{"Hangul_YAE"} = 0xec2;
	$Keysyms{"Hangul_EO"} = 0xec3;
	$Keysyms{"Hangul_E"} = 0xec4;
	$Keysyms{"Hangul_YEO"} = 0xec5;
	$Keysyms{"Hangul_YE"} = 0xec6;
	$Keysyms{"Hangul_O"} = 0xec7;
	$Keysyms{"Hangul_WA"} = 0xec8;
	$Keysyms{"Hangul_WAE"} = 0xec9;
	$Keysyms{"Hangul_OE"} = 0xeca;
	$Keysyms{"Hangul_YO"} = 0xecb;
	$Keysyms{"Hangul_U"} = 0xecc;
	$Keysyms{"Hangul_WEO"} = 0xecd;
	$Keysyms{"Hangul_WE"} = 0xece;
	$Keysyms{"Hangul_WI"} = 0xecf;
	$Keysyms{"Hangul_YU"} = 0xed0;
	$Keysyms{"Hangul_EU"} = 0xed1;
	$Keysyms{"Hangul_YI"} = 0xed2;
	$Keysyms{"Hangul_I"} = 0xed3;

# Hangul syllable-final (JongSeong) Characters 
	$Keysyms{"Hangul_J_Kiyeog"} = 0xed4;
	$Keysyms{"Hangul_J_SsangKiyeog"} = 0xed5;
	$Keysyms{"Hangul_J_KiyeogSios"} = 0xed6;
	$Keysyms{"Hangul_J_Nieun"} = 0xed7;
	$Keysyms{"Hangul_J_NieunJieuj"} = 0xed8;
	$Keysyms{"Hangul_J_NieunHieuh"} = 0xed9;
	$Keysyms{"Hangul_J_Dikeud"} = 0xeda;
	$Keysyms{"Hangul_J_Rieul"} = 0xedb;
	$Keysyms{"Hangul_J_RieulKiyeog"} = 0xedc;
	$Keysyms{"Hangul_J_RieulMieum"} = 0xedd;
	$Keysyms{"Hangul_J_RieulPieub"} = 0xede;
	$Keysyms{"Hangul_J_RieulSios"} = 0xedf;
	$Keysyms{"Hangul_J_RieulTieut"} = 0xee0;
	$Keysyms{"Hangul_J_RieulPhieuf"} = 0xee1;
	$Keysyms{"Hangul_J_RieulHieuh"} = 0xee2;
	$Keysyms{"Hangul_J_Mieum"} = 0xee3;
	$Keysyms{"Hangul_J_Pieub"} = 0xee4;
	$Keysyms{"Hangul_J_PieubSios"} = 0xee5;
	$Keysyms{"Hangul_J_Sios"} = 0xee6;
	$Keysyms{"Hangul_J_SsangSios"} = 0xee7;
	$Keysyms{"Hangul_J_Ieung"} = 0xee8;
	$Keysyms{"Hangul_J_Jieuj"} = 0xee9;
	$Keysyms{"Hangul_J_Cieuc"} = 0xeea;
	$Keysyms{"Hangul_J_Khieuq"} = 0xeeb;
	$Keysyms{"Hangul_J_Tieut"} = 0xeec;
	$Keysyms{"Hangul_J_Phieuf"} = 0xeed;
	$Keysyms{"Hangul_J_Hieuh"} = 0xeee;

# Ancient Hangul Consonant Characters 
	$Keysyms{"Hangul_RieulYeorinHieuh"} = 0xeef;
	$Keysyms{"Hangul_SunkyeongeumMieum"} = 0xef0;
	$Keysyms{"Hangul_SunkyeongeumPieub"} = 0xef1;
	$Keysyms{"Hangul_PanSios"} = 0xef2;
	$Keysyms{"Hangul_KkogjiDalrinIeung"} = 0xef3;
	$Keysyms{"Hangul_SunkyeongeumPhieuf"} = 0xef4;
	$Keysyms{"Hangul_YeorinHieuh"} = 0xef5;

# Ancient Hangul Vowel Characters 
	$Keysyms{"Hangul_AraeA"} = 0xef6;
	$Keysyms{"Hangul_AraeAE"} = 0xef7;

# Ancient Hangul syllable-final (JongSeong) Characters 
	$Keysyms{"Hangul_J_PanSios"} = 0xef8;
	$Keysyms{"Hangul_J_KkogjiDalrinIeung"} = 0xef9;
	$Keysyms{"Hangul_J_YeorinHieuh"} = 0xefa;

# Korean currency symbol 
	$Keysyms{"Korean_Won"} = 0xeff;
    }
#endif # XK_KOREAN 

}

1;

__END__

=head1 NAME

X11::Keysyms - Perl module for names of X11 keysyms

=head1 SYNOPSIS

  use X11::Keysyms '%Keysyms', qw(MISCELLANY XKB_KEYS LATIN1);
  %Keysyms_name = reverse %Keysyms;
  $ks = $Keysyms{'BackSpace'};
  $name = $Keysysms_name{$ks};

=head1 DESCRIPTION

This module exports a hash mapping the names of X11 keysyms, such
as 'A' or 'Linefeed' or 'Hangul_J_YeorinHieuh', onto the numbers that
represent them. The first argument to 'use' is the name of the variable
the hash should be exported into, and the rest are names of subsets of
the keysysms to export: one or more of 

  'MISCELLANY', 'XKB_KEYS', '3270', 'LATIN1', 'LATIN2',
  'LATIN3', 'LATIN4', 'KATAKANA', 'ARABIC', 'CYRILLIC',
  'GREEK', 'TECHNICAL', 'SPECIAL', 'PUBLISHING', 'APL',
  'HEBREW', 'THAI', 'KOREAN'.

If this list is omitted, the list 

  'MISCELLANY', 'XKB_KEYS', 'LATIN1', 'LATIN2', 'LATIN3',
  'LATIN4', 'GREEK'

is used.

=head1 AUTHOR

This module was generated semi-automatically by Stephen McCamant
(<SMCCAM@cpan.org>) from the header file 'X11/keysymdef.h', distributed by the
X Consortium.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
I<X Window System Protocol (X Version 11)>.

=cut
