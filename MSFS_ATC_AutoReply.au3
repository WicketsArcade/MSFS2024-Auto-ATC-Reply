; ===============================================================================
; Title .........: MSFS ATC Auto-Reply (Experimental Background Mode)
; AutoIt Version : 3.3.16.1 or higher
; Language ......: English
; Description ...: EXPERIMENTAL - Attempts multiple methods for background input
; Author(s) .....: Wicket (Original concept & design)
;                  SkyNet (AutoIt implementation)
; Version .......: 6.1 (Experimental)
; ===============================================================================
;
; WARNING: This is experimental and may not work with MSFS 2024
; The game actively blocks background input for security reasons
; ===============================================================================

#RequireAdmin
#Region ;**** Directives ****
#AutoIt3Wrapper_Icon=shell32.dll,41
#AutoIt3Wrapper_Outfile=MSFS_ATC_AutoReply_v6_Experimental.exe
#AutoIt3Wrapper_Res_Description=MSFS ATC Auto-Reply v6.1 Experimental
#AutoIt3Wrapper_Res_Fileversion=6.1.0.0
#AutoIt3Wrapper_Res_ProductVersion=6.1
#AutoIt3Wrapper_Res_LegalCopyright=Created by Wicket & SkyNet
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives ****

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>

Opt("GUIOnEventMode", 0)
Opt("GUICloseOnESC", 0)

; ===============================================================================
; CONFIGURATION
; ===============================================================================
Global Const $WINDOW_TITLE = "Microsoft Flight Simulator 2024"
Global Const $WINDOW_CLASS = "AceApp"
Global Const $TOGGLE_HOTKEY = "^{F8}"
Global Const $DEFAULT_INTERVAL = 10000

; Notification Settings
Global Const $NOTIFICATION_WIDTH = 300
Global Const $NOTIFICATION_HEIGHT = 80
Global Const $NOTIFICATION_DISPLAY_TIME = 2500
Global Const $NOTIFICATION_FADE_STEP = 25
Global Const $NOTIFICATION_FADE_DELAY = 20

; Performance Settings
Global Const $MAIN_LOOP_SLEEP_ACTIVE = 10
Global Const $MAIN_LOOP_SLEEP_INACTIVE = 50
Global Const $WINDOW_CACHE_TIME = 5000

; Background Input Methods (will try in order)
Global Enum $METHOD_CONTROLSEND = 0, $METHOD_POSTMESSAGE, $METHOD_SENDMESSAGE, $METHOD_SENDINPUT, $METHOD_ACTIVATE

; Virtual Key Codes
Global Const $VK_RETURN = 0x0D
Global Const $VK_CONTROL = 0x11
Global Const $VK_SHIFT = 0x10
Global Const $VK_F = 0x46

; ===============================================================================
; GLOBAL VARIABLES
; ===============================================================================
Global $g_bEnabled = False
Global $g_iInterval = $DEFAULT_INTERVAL
Global $g_hGUI = 0
Global $g_idStatusText = 0
Global $g_idIntervalEdit = 0
Global $g_idApplyBtn = 0
Global $g_idToggleBtn = 0
Global $g_idRefuelBtn = 0
Global $g_idMethodCombo = 0

; Notification variables
Global $g_hNotificationGUI = 0
Global $g_bNotificationShowing = False

; Performance: Window handle caching
Global $g_hCachedMSFSWindow = 0
Global $g_iLastWindowCheck = 0

; Current input method
Global $g_iCurrentMethod = $METHOD_ACTIVATE  ; Default to activation (works 100%)

; ===============================================================================
; MAIN PROGRAM
; ===============================================================================
Main()

Func Main()
    CreateGUI()
    HotKeySet($TOGGLE_HOTKEY, "Toggle")
    
    While 1
        ProcessGUIEvents()
        Sleep($g_bEnabled ? $MAIN_LOOP_SLEEP_ACTIVE : $MAIN_LOOP_SLEEP_INACTIVE)
    WEnd
EndFunc

; ===============================================================================
; GUI FUNCTIONS
; ===============================================================================
Func CreateGUI()
    Local $iStyle = BitOR($GUI_SS_DEFAULT_GUI, $WS_MINIMIZEBOX, $WS_SYSMENU)
    $g_hGUI = GUICreate("MSFS ATC Auto-Reply v6.1 (Experimental)", 370, 340, -1, -1, $iStyle)
    
    ; Title
    GUICtrlCreateLabel("MSFS ATC Auto-Reply", 10, 10, 350, 25, $SS_CENTER)
    GUICtrlSetFont(-1, 12, 800)
    
    ; Version
    GUICtrlCreateLabel("v6.1 - Experimental Background Mode", 10, 35, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 600)
    GUICtrlSetColor(-1, 0xFF6600)  ; Orange for experimental
    
    ; Credits
    GUICtrlCreateLabel("Created by Wicket && SkyNet", 10, 55, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 400)
    
    ; Description
    GUICtrlCreateLabel("Automatically presses Enter at set intervals to reply to ATC.", 10, 75, 350, 20, $SS_CENTER)
    GUICtrlCreateLabel("EXPERIMENTAL: Try different input methods below", 10, 95, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 600)
    GUICtrlSetColor(-1, 0xFF6600)
    
    GUICtrlCreateLabel("Refuel button sends Ctrl+Shift+F to the game.", 10, 115, 350, 20, $SS_CENTER)
    
    ; Separator
    GUICtrlCreateLabel("", 10, 140, 350, 2, $SS_ETCHEDHORZ)
    
    ; Status
    GUICtrlCreateLabel("Status:", 10, 155, 100, 20)
    $g_idStatusText = GUICtrlCreateLabel("OFF", 120, 155, 80, 20)
    GUICtrlSetColor(-1, 0xFF0000)
    GUICtrlSetFont(-1, 10, 600)
    
    ; Interval Controls
    GUICtrlCreateLabel("Interval (seconds):", 10, 185, 100, 20)
    $g_idIntervalEdit = GUICtrlCreateInput($g_iInterval/1000, 120, 182, 100, 22, $ES_NUMBER)
    $g_idApplyBtn = GUICtrlCreateButton("Apply", 230, 180, 70, 25)
    
    ; Input Method Selection
    GUICtrlCreateLabel("Input Method:", 10, 220, 100, 20)
    $g_idMethodCombo = GUICtrlCreateCombo("", 120, 217, 180, 25, 0x0003)  ; CBS_DROPDOWNLIST
    GUICtrlSetData($g_idMethodCombo, "ControlSend (Background)|PostMessage (Background)|SendMessage (Background)|SendInput (Background)|Activate Window (Reliable)", "Activate Window (Reliable)")
    
    ; Action Buttons
    $g_idToggleBtn = GUICtrlCreateButton("Start ATC Auto-Reply", 10, 260, 150, 30)
    $g_idRefuelBtn = GUICtrlCreateButton("Refuel", 170, 260, 80, 30)
    
    ; Help text
    GUICtrlCreateLabel("Try different methods if background mode doesn't work", 10, 300, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 8, 400)
    GUICtrlSetColor(-1, 0x666666)
    
    GUISetState(@SW_SHOW)
EndFunc

Func ProcessGUIEvents()
    Local $nMsg = GUIGetMsg()
    If $nMsg = 0 Then Return
    
    Switch $nMsg
        Case $GUI_EVENT_CLOSE
            GuiClose()
        Case $g_idToggleBtn
            Toggle()
        Case $g_idApplyBtn
            ApplyInterval()
        Case $g_idRefuelBtn
            Refuel()
        Case $g_idMethodCombo
            UpdateInputMethod()
    EndSwitch
EndFunc

Func UpdateInputMethod()
    Local $sMethod = GUICtrlRead($g_idMethodCombo)
    
    Switch $sMethod
        Case "ControlSend (Background)"
            $g_iCurrentMethod = $METHOD_CONTROLSEND
        Case "PostMessage (Background)"
            $g_iCurrentMethod = $METHOD_POSTMESSAGE
        Case "SendMessage (Background)"
            $g_iCurrentMethod = $METHOD_SENDMESSAGE
        Case "SendInput (Background)"
            $g_iCurrentMethod = $METHOD_SENDINPUT
        Case Else
            $g_iCurrentMethod = $METHOD_ACTIVATE
    EndSwitch
    
    ShowNotification("Input Method Changed", $sMethod, "info")
EndFunc

Func UpdateGUI()
    If $g_bEnabled Then
        GUICtrlSetData($g_idStatusText, "ON")
        GUICtrlSetColor($g_idStatusText, 0x00FF00)
        GUICtrlSetData($g_idToggleBtn, "Stop ATC Auto-Reply")
    Else
        GUICtrlSetData($g_idStatusText, "OFF")
        GUICtrlSetColor($g_idStatusText, 0xFF0000)
        GUICtrlSetData($g_idToggleBtn, "Start ATC Auto-Reply")
    EndIf
EndFunc

Func ApplyInterval()
    Local $iNewVal = Number(GUICtrlRead($g_idIntervalEdit))
    
    If $iNewVal > 0 Then
        $g_iInterval = $iNewVal * 1000
        GUICtrlSetData($g_idIntervalEdit, $iNewVal)
        
        If $g_bEnabled Then
            AdlibUnRegister("PressEnter")
            AdlibRegister("PressEnter", $g_iInterval)
        EndIf
        
        ShowNotification("Interval Updated", "New interval: " & $iNewVal & " seconds", "success")
    Else
        ShowNotification("Invalid Interval", "Please enter a positive number", "error")
    EndIf
EndFunc

Func GuiClose()
    Local $iResult = MsgBox(36, "Confirm", "Exit the script completely (Yes) or hide to tray (No)?")
    If $iResult = 6 Then
        Exit
    Else
        GUISetState(@SW_HIDE, $g_hGUI)
        ShowNotification("Minimized to Tray", "Script is still running in the background", "info")
    EndIf
EndFunc

; ===============================================================================
; NOTIFICATION SYSTEM
; ===============================================================================
Func ShowNotification($sTitle, $sMessage, $sType = "info")
    If $g_bNotificationShowing Then
        CloseNotificationImmediate()
    EndIf
    
    Local $iBgColor, $iTitleColor
    Switch $sType
        Case "success"
            $iBgColor = 0x2ECC71
            $iTitleColor = 0xFFFFFF
        Case "error"
            $iBgColor = 0xE74C3C
            $iTitleColor = 0xFFFFFF
        Case "warning"
            $iBgColor = 0xF39C12
            $iTitleColor = 0xFFFFFF
        Case Else
            $iBgColor = 0x3498DB
            $iTitleColor = 0xFFFFFF
    EndSwitch
    
    Local $iPosX = @DesktopWidth - $NOTIFICATION_WIDTH - 20
    Local $iPosY = @DesktopHeight - $NOTIFICATION_HEIGHT - 50
    
    $g_hNotificationGUI = GUICreate("", $NOTIFICATION_WIDTH, $NOTIFICATION_HEIGHT, $iPosX, $iPosY, $WS_POPUP, $WS_EX_TOPMOST + $WS_EX_TOOLWINDOW)
    GUISetBkColor($iBgColor, $g_hNotificationGUI)
    
    Local $idTitle = GUICtrlCreateLabel($sTitle, 15, 10, $NOTIFICATION_WIDTH - 30, 25)
    GUICtrlSetFont(-1, 11, 700)
    GUICtrlSetColor(-1, $iTitleColor)
    GUICtrlSetBkColor(-1, $iBgColor)
    
    Local $idMessage = GUICtrlCreateLabel($sMessage, 15, 35, $NOTIFICATION_WIDTH - 30, 35)
    GUICtrlSetFont(-1, 9, 400)
    GUICtrlSetColor(-1, $iTitleColor)
    GUICtrlSetBkColor(-1, $iBgColor)
    
    GUISetState(@SW_SHOW, $g_hNotificationGUI)
    $g_bNotificationShowing = True
    
    For $i = 0 To 255 Step $NOTIFICATION_FADE_STEP
        WinSetTrans($g_hNotificationGUI, "", $i)
        Sleep($NOTIFICATION_FADE_DELAY)
    Next
    WinSetTrans($g_hNotificationGUI, "", 255)
    
    AdlibRegister("CloseNotification", $NOTIFICATION_DISPLAY_TIME)
EndFunc

Func CloseNotification()
    AdlibUnRegister("CloseNotification")
    If Not $g_bNotificationShowing Then Return
    
    For $i = 255 To 0 Step -$NOTIFICATION_FADE_STEP
        WinSetTrans($g_hNotificationGUI, "", $i)
        Sleep($NOTIFICATION_FADE_DELAY)
    Next
    
    GUIDelete($g_hNotificationGUI)
    $g_bNotificationShowing = False
EndFunc

Func CloseNotificationImmediate()
    AdlibUnRegister("CloseNotification")
    If $g_bNotificationShowing Then
        GUIDelete($g_hNotificationGUI)
        $g_bNotificationShowing = False
    EndIf
EndFunc

; ===============================================================================
; WINDOW DETECTION
; ===============================================================================
Func FindMSFSWindow()
    Local $iCurrentTime = TimerInit()
    
    If $g_hCachedMSFSWindow <> 0 And ($iCurrentTime - $g_iLastWindowCheck) < $WINDOW_CACHE_TIME Then
        If WinExists($g_hCachedMSFSWindow) Then
            Return $g_hCachedMSFSWindow
        EndIf
    EndIf
    
    Local $aWindows = WinList("[CLASS:" & $WINDOW_CLASS & "]")
    Local $hMainWnd = 0
    Local $iMaxArea = 0
    
    For $i = 1 To $aWindows[0][0]
        Local $hWnd = $aWindows[$i][1]
        Local $aPos = WinGetPos($hWnd)
        
        If Not @error And IsArray($aPos) Then
            Local $iArea = $aPos[2] * $aPos[3]
            
            If $iArea > $iMaxArea And BitAND(WinGetState($hWnd), 2) Then
                $iMaxArea = $iArea
                $hMainWnd = $hWnd
            EndIf
        EndIf
    Next
    
    If $hMainWnd = 0 Then
        $hMainWnd = WinGetHandle($WINDOW_TITLE)
        If @error Then
            $g_hCachedMSFSWindow = 0
            Return 0
        EndIf
    EndIf
    
    $g_hCachedMSFSWindow = $hMainWnd
    $g_iLastWindowCheck = $iCurrentTime
    
    Return $hMainWnd
EndFunc

Func InvalidateWindowCache()
    $g_hCachedMSFSWindow = 0
    $g_iLastWindowCheck = 0
EndFunc

; ===============================================================================
; KEY SENDING - MULTIPLE METHODS
; ===============================================================================
Func SendToMSFS($sKeys)
    Local $hWnd = FindMSFSWindow()
    If $hWnd = 0 Then
        InvalidateWindowCache()
        Return False
    EndIf
    
    ; Try the selected method
    Local $bSuccess = False
    Switch $g_iCurrentMethod
        Case $METHOD_CONTROLSEND
            $bSuccess = SendViaControlSend($hWnd, $sKeys)
        Case $METHOD_POSTMESSAGE
            $bSuccess = SendViaPostMessage($hWnd, $sKeys)
        Case $METHOD_SENDMESSAGE
            $bSuccess = SendViaSendMessage($hWnd, $sKeys)
        Case $METHOD_SENDINPUT
            $bSuccess = SendViaSendInput($hWnd, $sKeys)
        Case Else
            $bSuccess = SendViaActivate($hWnd, $sKeys)
    EndSwitch
    
    Return $bSuccess
EndFunc

Func SendViaControlSend($hWnd, $sKeys)
    ControlSend($hWnd, "", "", $sKeys, 0)
    Return Not @error
EndFunc

Func SendViaPostMessage($hWnd, $sKeys)
    If $sKeys = "{ENTER}" Then
        DllCall("user32.dll", "lresult", "PostMessage", "hwnd", $hWnd, "uint", $WM_KEYDOWN, "wparam", $VK_RETURN, "lparam", 0x001C0001)
        Sleep(50)
        DllCall("user32.dll", "lresult", "PostMessage", "hwnd", $hWnd, "uint", $WM_KEYUP, "wparam", $VK_RETURN, "lparam", 0xC01C0001)
        Return True
    EndIf
    Return False
EndFunc

Func SendViaSendMessage($hWnd, $sKeys)
    If $sKeys = "{ENTER}" Then
        DllCall("user32.dll", "lresult", "SendMessage", "hwnd", $hWnd, "uint", $WM_KEYDOWN, "wparam", $VK_RETURN, "lparam", 0x001C0001)
        Sleep(50)
        DllCall("user32.dll", "lresult", "SendMessage", "hwnd", $hWnd, "uint", $WM_KEYUP, "wparam", $VK_RETURN, "lparam", 0xC01C0001)
        Return True
    EndIf
    Return False
EndFunc

Func SendViaSendInput($hWnd, $sKeys)
    ; SendInput requires window to be in foreground but doesn't use WinActivate
    ; May work if MSFS is visible but not focused
    Send($sKeys)
    Return True
EndFunc

Func SendViaActivate($hWnd, $sKeys)
    Local $hPrevWindow = WinGetHandle("[ACTIVE]")
    
    WinActivate($hWnd)
    If Not WinWaitActive($hWnd, "", 2) Then
        InvalidateWindowCache()
        Return False
    EndIf
    
    Sleep(150)
    Send($sKeys)
    Sleep(50)
    
    If $hPrevWindow <> 0 And $hPrevWindow <> $hWnd Then
        WinActivate($hPrevWindow)
    EndIf
    
    Return True
EndFunc

; ===============================================================================
; ACTION FUNCTIONS
; ===============================================================================
Func Toggle()
    $g_bEnabled = Not $g_bEnabled
    
    If $g_bEnabled Then
        Local $sMethod = GUICtrlRead($g_idMethodCombo)
        ShowNotification("ATC Auto-Reply Started", "Using: " & $sMethod, "success")
        AdlibRegister("PressEnter", $g_iInterval)
    Else
        ShowNotification("ATC Auto-Reply Stopped", "Auto-reply has been disabled", "warning")
        AdlibUnRegister("PressEnter")
    EndIf
    
    UpdateGUI()
EndFunc

Func PressEnter()
    If Not $g_bEnabled Then Return
    SendToMSFS("{ENTER}")
EndFunc

Func Refuel()
    If SendToMSFS("^+F") Then
        ShowNotification("Refuel Requested", "Ctrl+Shift+F sent to MSFS", "success")
    Else
        ShowNotification("MSFS Not Found", "Could not find MSFS window", "error")
        InvalidateWindowCache()
    EndIf
EndFunc
