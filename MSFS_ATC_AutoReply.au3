; ===============================================================================
; Title .........: MSFS ATC Auto-Reply
; AutoIt Version : 3.3.16.1 or higher
; Language ......: English
; Description ...: Automatically responds to ATC in Microsoft Flight Simulator
; Author(s) .....: Wicket (Original concept & design)
;                  SkyNet (AutoIt implementation)
; Version .......: 6.0 (Performance Optimized)
; ===============================================================================

#RequireAdmin
#Region ;**** Directives ****
#AutoIt3Wrapper_Icon=shell32.dll,41
#AutoIt3Wrapper_Outfile=MSFS_ATC_AutoReply_v6.exe
#AutoIt3Wrapper_Res_Description=MSFS ATC Auto-Reply v6.0
#AutoIt3Wrapper_Res_Fileversion=6.0.0.0
#AutoIt3Wrapper_Res_ProductVersion=6.0
#AutoIt3Wrapper_Res_LegalCopyright=Created by Wicket & SkyNet
#AutoIt3Wrapper_UseX64=y  ; Use 64-bit for better performance
#EndRegion ;**** Directives ****

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>

Opt("GUIOnEventMode", 0)  ; Ensure message loop mode
Opt("GUICloseOnESC", 0)   ; Disable ESC closing GUI

; ===============================================================================
; CONFIGURATION
; ===============================================================================
Global Const $WINDOW_TITLE = "Microsoft Flight Simulator 2024"
Global Const $WINDOW_CLASS = "AceApp"
Global Const $TOGGLE_HOTKEY = "^{F8}"  ; Ctrl+F8
Global Const $DEFAULT_INTERVAL = 10000  ; 10 seconds in milliseconds

; Notification Settings
Global Const $NOTIFICATION_WIDTH = 300
Global Const $NOTIFICATION_HEIGHT = 80
Global Const $NOTIFICATION_DISPLAY_TIME = 2500  ; milliseconds
Global Const $NOTIFICATION_FADE_STEP = 25
Global Const $NOTIFICATION_FADE_DELAY = 20

; Performance Settings
Global Const $MAIN_LOOP_SLEEP_ACTIVE = 50    ; Reduced CPU when active
Global Const $MAIN_LOOP_SLEEP_INACTIVE = 200 ; More aggressive sleep when idle
Global Const $WINDOW_CACHE_TIME = 5000       ; Cache window handle for 5 seconds

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

; Notification variables
Global $g_hNotificationGUI = 0
Global $g_bNotificationShowing = False

; Performance: Window handle caching
Global $g_hCachedMSFSWindow = 0
Global $g_iLastWindowCheck = 0

; ===============================================================================
; MAIN PROGRAM
; ===============================================================================
Main()

Func Main()
    CreateGUI()
    HotKeySet($TOGGLE_HOTKEY, "Toggle")
    
    Local $iLastGUICheck = TimerInit()
    
    While 1
        ; Only process GUI events every 50ms instead of constantly
        If TimerDiff($iLastGUICheck) > 50 Then
            ProcessGUIEvents()
            $iLastGUICheck = TimerInit()
        EndIf
        
        ; Dynamic sleep based on state
        Sleep($g_bEnabled ? $MAIN_LOOP_SLEEP_ACTIVE : $MAIN_LOOP_SLEEP_INACTIVE)
    WEnd
EndFunc

; ===============================================================================
; GUI FUNCTIONS
; ===============================================================================
Func CreateGUI()
    Local $iStyle = BitOR($GUI_SS_DEFAULT_GUI, $WS_MINIMIZEBOX, $WS_SYSMENU)
    $g_hGUI = GUICreate("MSFS ATC Auto-Reply v6.0", 370, 290, -1, -1, $iStyle)
    
    ; Title
    GUICtrlCreateLabel("MSFS ATC Auto-Reply", 10, 10, 350, 25, $SS_CENTER)
    GUICtrlSetFont(-1, 12, 800)
    
    ; Version
    GUICtrlCreateLabel("v6.0 - Performance Optimized", 10, 35, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 600)
    GUICtrlSetColor(-1, 0x0066CC)
    
    ; Credits
    GUICtrlCreateLabel("Created by Wicket && SkyNet", 10, 55, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 400)
    
    ; Description
    GUICtrlCreateLabel("Automatically presses Enter at set intervals to reply to ATC.", 10, 75, 350, 20, $SS_CENTER)
    GUICtrlCreateLabel("Activates MSFS briefly to send keys, then restores focus", 10, 95, 350, 20, $SS_CENTER)
    GUICtrlSetFont(-1, 9, 600)
    GUICtrlSetColor(-1, 0x008800)
    
    GUICtrlCreateLabel("Refuel button sends Ctrl+Shift+F to the game.", 10, 115, 350, 20, $SS_CENTER)
    
    ; Separator
    GUICtrlCreateLabel("", 10, 140, 350, 2, $SS_ETCHEDHORZ)
    
    ; Status
    GUICtrlCreateLabel("Status:", 10, 155, 100, 20)
    $g_idStatusText = GUICtrlCreateLabel("OFF", 120, 155, 80, 20)
    GUICtrlSetColor(-1, 0xFF0000)
    GUICtrlSetFont(-1, 10, 600)
    
    ; Interval Controls
    GUICtrlCreateLabel("Interval (ms):", 10, 185, 100, 20)
    $g_idIntervalEdit = GUICtrlCreateInput($g_iInterval, 120, 182, 100, 22, $ES_NUMBER)
    $g_idApplyBtn = GUICtrlCreateButton("Apply", 230, 180, 70, 25)
    
    ; Action Buttons
    $g_idToggleBtn = GUICtrlCreateButton("Start ATC Auto-Reply", 10, 225, 150, 30)
    $g_idRefuelBtn = GUICtrlCreateButton("Refuel", 170, 225, 80, 30)
    
    GUISetState(@SW_SHOW)
EndFunc

Func ProcessGUIEvents()
    Local $nMsg = GUIGetMsg()
    
    ; Early return for no message - most common case
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
    EndSwitch
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
    Local $iNewVal = Int(GUICtrlRead($g_idIntervalEdit))
    
    If $iNewVal > 0 Then
        $g_iInterval = $iNewVal
        GUICtrlSetData($g_idIntervalEdit, $g_iInterval)
        
        ; Update timer if already running
        If $g_bEnabled Then
            AdlibUnRegister("PressEnter")
            AdlibRegister("PressEnter", $g_iInterval)
        EndIf
        
        ShowNotification("Interval Updated", "New interval: " & $g_iInterval & " ms (" & Round($g_iInterval/1000, 1) & " seconds)", "success")
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
; NOTIFICATION SYSTEM (Optimized)
; ===============================================================================
Func ShowNotification($sTitle, $sMessage, $sType = "info")
    ; Close existing notification if showing (reuse instead of creating new)
    If $g_bNotificationShowing Then
        CloseNotificationImmediate()
    EndIf
    
    ; Pre-calculate colors (lookup table approach)
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
    
    ; Pre-calculated position
    Local $iPosX = @DesktopWidth - $NOTIFICATION_WIDTH - 20
    Local $iPosY = @DesktopHeight - $NOTIFICATION_HEIGHT - 50
    
    ; Create notification window
    $g_hNotificationGUI = GUICreate("", $NOTIFICATION_WIDTH, $NOTIFICATION_HEIGHT, $iPosX, $iPosY, $WS_POPUP, $WS_EX_TOPMOST + $WS_EX_TOOLWINDOW)
    GUISetBkColor($iBgColor, $g_hNotificationGUI)
    
    ; Add title
    Local $idTitle = GUICtrlCreateLabel($sTitle, 15, 10, $NOTIFICATION_WIDTH - 30, 25)
    GUICtrlSetFont(-1, 11, 700)
    GUICtrlSetColor(-1, $iTitleColor)
    GUICtrlSetBkColor(-1, $iBgColor)
    
    ; Add message
    Local $idMessage = GUICtrlCreateLabel($sMessage, 15, 35, $NOTIFICATION_WIDTH - 30, 35)
    GUICtrlSetFont(-1, 9, 400)
    GUICtrlSetColor(-1, $iTitleColor)
    GUICtrlSetBkColor(-1, $iBgColor)
    
    ; Show notification
    GUISetState(@SW_SHOW, $g_hNotificationGUI)
    $g_bNotificationShowing = True
    
    ; Optimized fade-in (fewer steps, faster)
    For $i = 0 To 255 Step $NOTIFICATION_FADE_STEP
        WinSetTrans($g_hNotificationGUI, "", $i)
        Sleep($NOTIFICATION_FADE_DELAY)
    Next
    WinSetTrans($g_hNotificationGUI, "", 255)
    
    ; Schedule close
    AdlibRegister("CloseNotification", $NOTIFICATION_DISPLAY_TIME)
EndFunc

Func CloseNotification()
    AdlibUnRegister("CloseNotification")
    If Not $g_bNotificationShowing Then Return
    
    ; Optimized fade-out
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
; WINDOW DETECTION (Optimized with Caching)
; ===============================================================================
Func FindMSFSWindow()
    Local $iCurrentTime = TimerInit()
    
    ; Return cached window if still valid and window exists
    If $g_hCachedMSFSWindow <> 0 And ($iCurrentTime - $g_iLastWindowCheck) < $WINDOW_CACHE_TIME Then
        If WinExists($g_hCachedMSFSWindow) Then
            Return $g_hCachedMSFSWindow
        EndIf
    EndIf
    
    ; Cache expired or invalid - find window
    Local $aWindows = WinList("[CLASS:" & $WINDOW_CLASS & "]")
    Local $hMainWnd = 0
    Local $iMaxArea = 0
    
    ; Find the largest window (main MSFS window, not popup panels)
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
    
    ; Fallback to title search
    If $hMainWnd = 0 Then
        $hMainWnd = WinGetHandle($WINDOW_TITLE)
        If @error Then
            $g_hCachedMSFSWindow = 0
            Return 0
        EndIf
    EndIf
    
    ; Update cache
    $g_hCachedMSFSWindow = $hMainWnd
    $g_iLastWindowCheck = $iCurrentTime
    
    Return $hMainWnd
EndFunc

Func InvalidateWindowCache()
    $g_hCachedMSFSWindow = 0
    $g_iLastWindowCheck = 0
EndFunc

; ===============================================================================
; KEY SENDING (Optimized)
; ===============================================================================
Func SendToMSFS($sKeys)
    Local $hWnd = FindMSFSWindow()
    If $hWnd = 0 Then
        InvalidateWindowCache()
        Return False
    EndIf
    
    ; Store current window
    Local $hPrevWindow = WinGetHandle("[ACTIVE]")
    
    ; Activate MSFS and send keys
    WinActivate($hWnd)
    
    ; Reduced wait time with timeout
    If Not WinWaitActive($hWnd, "", 2) Then
        InvalidateWindowCache()
        Return False
    EndIf
    
    Sleep(150)  ; Reduced from 200ms
    Send($sKeys)
    Sleep(50)   ; Reduced from 100ms
    
    ; Restore previous window
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
        ShowNotification("ATC Auto-Reply Started", "Pressing Enter every " & Round($g_iInterval/1000, 1) & " seconds", "success")
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
