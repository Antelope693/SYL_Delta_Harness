#Requires AutoHotkey v2

; ========== 配置文件路径 ==========

Tool_Config_File := A_ScriptDir . "\Config\Config.ini"

Set_Hotkey_Config_File := A_ScriptDir . "\Config\热键配置.ini"

Start_Music_File := A_ScriptDir . "\WifiLib\Start.mp3"

End_Music_File := A_ScriptDir . "\WifiLib\End.mp3"

; ========== 全局变量 ==========

global Wifi_States1 := false

global Wifi_Time1 := 0

global hModule := 0

global hDivert := 0

global WINDIVERT_FLAG_DROP := 0x0002

global Keyboard_Shortcut1 := ""

global Keyboard_Auto1 := ""

global Countdown_Show_State := false

global Tip_Music_State := "开启"

global Is_Hidden := false

global SelectedKey := ""

global Keyboar1_Value := ""

global Keyboar2_Value := ""

; ========== GUI 控件引用 ==========

global MyGui := ""

global Wifi_Near_Switch_checked := ""

global Set_Recover_Time := ""

global Skill_Gun_checked := ""

global Gun_Recover_Time := ""

global Countdown_Show_Button := ""

global Tip_Music_Button := ""

global Set_Hotkey_Gui := ""

global Hotkey1_Text := ""

global Hotkey2_Text := ""

global Set_Hotkey := ""

; ========== 管理员权限 ==========

if (!A_IsAdmin) {

    try {

        Run("*RunAs " A_ScriptFullPath)

    } catch {

        MsgBox("无法获取管理员权限，请右键以管理员身份运行此脚本", "权限错误", 16)

        ExitApp

    }

    ExitApp

}

; ========== 初始化配置文件 ==========

if !FileExist(Tool_Config_File) {

    DirCreate(A_ScriptDir . "\Config")

    IniWrite("开启", Tool_Config_File, "Tool_Config", "Time")

    IniWrite("开启", Tool_Config_File, "Tool_Config", "Tip_Music")

    IniWrite("7", Tool_Config_File, "Tool_Config", "Recover_Time")

    IniWrite("600", Tool_Config_File, "Tool_Config", "Gun_Recover_Time")

}

; ========== 加载 WinDivert ==========

hModule := DllCall("LoadLibrary", "Str", A_ScriptDir . "\WifiLib\WinDivert.dll", "Ptr")

if (!hModule) {

    MsgBox("无法加载 WinDivert.dll，请检查 WifiLib 文件夹是否完整。", "错误", 16)

    ExitApp

}

; ========== 清理残留进程 ==========

ProcessClose("Bindwidth.exe")

ProcessClose("Limit.exe")

; ========== 核心函数：WinDivert 断网 ==========

Drop_Start_Func() {

    global hDivert, hModule, WINDIVERT_FLAG_DROP

    ; 清理上次异常退出残留的同名驱动服务（旧服务 ImagePath 可能指向已失效目录，导致句柄打不开）
    try {
        RunWait("C:\Windows\System32\sc.exe stop WinDivert", , "Hide")
        RunWait("C:\Windows\System32\sc.exe delete WinDivert", , "Hide")
    } catch

    DllCall("SetLastError", "UInt", 0)
    hDivert := DllCall("WinDivert\WinDivertOpen", "AStr", "outbound", "Int", 0, "Short", 0, "Int64", WINDIVERT_FLAG_DROP, "Ptr")

    if (!hDivert || hDivert == -1) {
        errCode := DllCall("GetLastError")
        reason := A_IsAdmin ? "驱动服务被占用，或 WinDivert64.sys 异常、被安全软件拦截。" : "程序未以管理员身份运行。"
        MsgBox("无法打开 WinDivert 句柄（错误码 " errCode "）。`n" reason, "错误", 16)
        return false
    }

    return true

}

Drop_Stop_Func() {

    global hDivert

    if (hDivert) {

        DllCall("WinDivert\WinDivertClose", "Ptr", hDivert)

        hDivert := 0

    }

}

; ========== 工具函数：带随机抖动的延迟 ==========

FSleep(Ms, Wave) {

    Dalay_Ms := Random(Ms - Wave, Ms + Wave)

    Sleep(Dalay_Ms)

}

; ========== 读取热键配置 ==========

Read_Keyini() {

    global Keyboar1_Value, Keyboar2_Value, Keyboard_Shortcut1, Keyboard_Auto1

    if FileExist(Set_Hotkey_Config_File) {

        Hotkey1_name := IniRead(Set_Hotkey_Config_File, "Settings", "Hotkey1_name", "XButton2")

        Hotkey2_name := IniRead(Set_Hotkey_Config_File, "Settings", "Hotkey2_name", "G")

        Keyboard_Shortcut1 := Hotkey1_name

        Keyboard_Auto1 := Hotkey2_name

        if (Hotkey1_name = "XButton2")

            Keyboar1_Value := "前侧键"

        else if (Hotkey1_name = "XButton1")

            Keyboar1_Value := "后侧键"

        else

            Keyboar1_Value := Hotkey1_name

        if (Hotkey2_name = "XButton2")

            Keyboar2_Value := "前侧键"

        else if (Hotkey2_name = "XButton1")

            Keyboar2_Value := "后侧键"

        else

            Keyboar2_Value := Hotkey2_name

    } else {

        DirCreate(A_ScriptDir . "\Config")

        IniWrite("XButton2", Set_Hotkey_Config_File, "Settings", "Hotkey1_name")

        IniWrite("G", Set_Hotkey_Config_File, "Settings", "Hotkey2_name")

        Keyboard_Shortcut1 := "XButton2"

        Keyboard_Auto1 := "G"

        Keyboar1_Value := "前侧键"

        Keyboar2_Value := "G"

    }

}

Read_Keyini()

; ========== 模块：虚拟键盘热键选择 ==========

GetKeyName() {

    global SelectedKey, Set_Hotkey

    SelectedKey := "暂未设置"

    Set_Hotkey := Gui()

    Set_Hotkey.Show("w590 h220")

    Set_Hotkey.Title := "设置快捷键"

    F1_Button := Set_Hotkey.addButton("x70 y10 w30 h20", "F1")

    F2_Button := Set_Hotkey.addButton("x100 y10 w30 h20", "F2")

    F3_Button := Set_Hotkey.addButton("x130 y10 w30 h20", "F3")

    F4_Button := Set_Hotkey.addButton("x160 y10 w30 h20", "F4")

    F5_Button := Set_Hotkey.addButton("x210 y10 w30 h20", "F5")

    F6_Button := Set_Hotkey.addButton("x240 y10 w30 h20", "F6")

    F7_Button := Set_Hotkey.addButton("x270 y10 w30 h20", "F7")

    F8_Button := Set_Hotkey.addButton("x300 y10 w30 h20", "F8")

    F9_Button := Set_Hotkey.addButton("x350 y10 w30 h20", "F9")

    F10_Button := Set_Hotkey.addButton("x380 y10 w30 h20", "F10")

    F11_Button := Set_Hotkey.addButton("x410 y10 w30 h20", "F11")

    F12_Button := Set_Hotkey.addButton("x440 y10 w30 h20", "F12")

    PS_Button := Set_Hotkey.addButton("x490 y10 w30 h20", "PS")

    SL_Button := Set_Hotkey.addButton("x520 y10 w30 h20", "SL")

    PB_Button := Set_Hotkey.addButton("x550 y10 w30 h20", "PB")

    FU_Button := Set_Hotkey.addButton("x10 y35 w30 h20", "~")

    Num1_Button := Set_Hotkey.addButton("x40 y35 w30 h20", "1")

    Num2_Button := Set_Hotkey.addButton("x70 y35 w30 h20", "2")

    Num3_Button := Set_Hotkey.addButton("x100 y35 w30 h20", "3")

    Num4_Button := Set_Hotkey.addButton("x130 y35 w30 h20", "4")

    Num5_Button := Set_Hotkey.addButton("x160 y35 w30 h20", "5")

    Num6_Button := Set_Hotkey.addButton("x190 y35 w30 h20", "6")

    Num7_Button := Set_Hotkey.addButton("x220 y35 w30 h20", "7")

    Num8_Button := Set_Hotkey.addButton("x250 y35 w30 h20", "8")

    Num9_Button := Set_Hotkey.addButton("x280 y35 w30 h20", "9")

    Num0_Button := Set_Hotkey.addButton("x310 y35 w30 h20", "0")

    Minus_Button := Set_Hotkey.addButton("x340 y35 w30 h20", "-")

    Equal_Button := Set_Hotkey.addButton("x370 y35 w30 h20", "=")

    Backspace_Button := Set_Hotkey.addButton("x400 y35 w70 h20", "Backspace")

    Ins_Button := Set_Hotkey.addButton("x490 y35 w30 h20", "Ins")

    Home_Button := Set_Hotkey.addButton("x520 y35 w30 h20", "Home")

    PgUp_Button := Set_Hotkey.addButton("x550 y35 w30 h20", "PgUp")

    Tab_Button := Set_Hotkey.addButton("x10 y60 w40 h20", "Tab")

    Q_Button := Set_Hotkey.addButton("x50 y60 w30 h20", "Q")

    W_Button := Set_Hotkey.addButton("x80 y60 w30 h20", "W")

    E_Button := Set_Hotkey.addButton("x110 y60 w30 h20", "E")

    R_Button := Set_Hotkey.addButton("x140 y60 w30 h20", "R")

    T_Button := Set_Hotkey.addButton("x170 y60 w30 h20", "T")

    Y_Button := Set_Hotkey.addButton("x200 y60 w30 h20", "Y")

    U_Button := Set_Hotkey.addButton("x230 y60 w30 h20", "U")

    I_Button := Set_Hotkey.addButton("x260 y60 w30 h20", "I")

    O_Button := Set_Hotkey.addButton("x290 y60 w30 h20", "O")

    P_Button := Set_Hotkey.addButton("x320 y60 w30 h20", "P")

    LBrackets_Button := Set_Hotkey.addButton("x350 y60 w30 h20", "[")

    RBrackets_Button := Set_Hotkey.addButton("x380 y60 w30 h20", "]")

    Backslash_Button := Set_Hotkey.addButton("x410 y60 w60 h20", "\")

    Del_Button := Set_Hotkey.addButton("x490 y60 w30 h20", "Del")

    End_Button := Set_Hotkey.addButton("x520 y60 w30 h20", "End")

    PgDn_Button := Set_Hotkey.addButton("x550 y60 w30 h20", "PgDn")

    CapsLock_Button := Set_Hotkey.addButton("x10 y85 w60 h20", "CapsLock")

    A_Button := Set_Hotkey.addButton("x70 y85 w30 h20", "A")

    S_Button := Set_Hotkey.addButton("x100 y85 w30 h20", "S")

    D_Button := Set_Hotkey.addButton("x130 y85 w30 h20", "D")

    F_Button := Set_Hotkey.addButton("x160 y85 w30 h20", "F")

    G_Button := Set_Hotkey.addButton("x190 y85 w30 h20", "G")

    H_Button := Set_Hotkey.addButton("x220 y85 w30 h20", "H")

    J_Button := Set_Hotkey.addButton("x250 y85 w30 h20", "J")

    K_Button := Set_Hotkey.addButton("x280 y85 w30 h20", "K")

    L_Button := Set_Hotkey.addButton("x310 y85 w30 h20", "L")

    Semicolon_Button := Set_Hotkey.addButton("x340 y85 w30 h20", ";")

    Apostrophe_Button := Set_Hotkey.addButton("x370 y85 w30 h20", "'")

    Enter_Button := Set_Hotkey.addButton("x400 y85 w70 h20", "Enter")

    Left_Shift_Button := Set_Hotkey.addButton("x10 y110 w72 h20", "Shift")

    Z_Button := Set_Hotkey.addButton("x82 y110 w30 h20", "Z")

    X_Button := Set_Hotkey.addButton("x112 y110 w30 h20", "X")

    C_Button := Set_Hotkey.addButton("x142 y110 w30 h20", "C")

    V_Button := Set_Hotkey.addButton("x172 y110 w30 h20", "V")

    B_Button := Set_Hotkey.addButton("x202 y110 w30 h20", "B")

    N_Button := Set_Hotkey.addButton("x232 y110 w30 h20", "N")

    M_Button := Set_Hotkey.addButton("x262 y110 w30 h20", "M")

    Comma_Button := Set_Hotkey.addButton("x292 y110 w30 h20", ",")

    Period_Button := Set_Hotkey.addButton("x322 y110 w30 h20", ".")

    Slash_Button := Set_Hotkey.addButton("x352 y110 w30 h20", "/")

    Right_Shift_Button := Set_Hotkey.addButton("x382 y110 w88 h20", "Shift")

    Up_Button := Set_Hotkey.addButton("x520 y110 w30 h20", "↑")

    Left_Ctrl_Button := Set_Hotkey.addButton("x10 y135 w37 h20", "Ctrl")

    Win_Button := Set_Hotkey.addButton("x47 y135 w37 h20", "Win")

    Left_Alt_Button := Set_Hotkey.addButton("x84 y135 w37 h20", "Alt")

    Space_Button := Set_Hotkey.addButton("x121 y135 w195 h20", "Space")

    Right_Alt_Button := Set_Hotkey.addButton("x317 y135 w35 h20", "Alt")

    Fn_Button := Set_Hotkey.addButton("x352 y135 w35 h20", "Fn")

    Meau_Button := Set_Hotkey.addButton("x387 y135 w35 h20", "Meau")

    Right_Ctrl_Button := Set_Hotkey.addButton("x422 y135 w48 h20", "Ctrl")

    Left_Button := Set_Hotkey.addButton("x490 y135 w30 h20", "←")

    Down_Button := Set_Hotkey.addButton("x520 y135 w30 h20", "↓")

    Right_Button := Set_Hotkey.addButton("x550 y135 w30 h20", "→")

    XButton1_Button := Set_Hotkey.addButton("x350 y160 w60 h20", "后侧键")

    XButton2_Button := Set_Hotkey.addButton("x420 y160 w60 h20", "前侧键")

    F1_Button.OnEvent("Click", (*) => SetSelectedKey("F1"))

    F2_Button.OnEvent("Click", (*) => SetSelectedKey("F2"))

    F3_Button.OnEvent("Click", (*) => SetSelectedKey("F3"))

    F4_Button.OnEvent("Click", (*) => SetSelectedKey("F4"))

    F5_Button.OnEvent("Click", (*) => SetSelectedKey("F5"))

    F6_Button.OnEvent("Click", (*) => SetSelectedKey("F6"))

    F7_Button.OnEvent("Click", (*) => SetSelectedKey("F7"))

    F8_Button.OnEvent("Click", (*) => SetSelectedKey("F8"))

    F9_Button.OnEvent("Click", (*) => SetSelectedKey("F9"))

    F10_Button.OnEvent("Click", (*) => SetSelectedKey("F10"))

    F11_Button.OnEvent("Click", (*) => SetSelectedKey("F11"))

    F12_Button.OnEvent("Click", (*) => SetSelectedKey("F12"))

    PS_Button.OnEvent("Click", (*) => SetSelectedKey("PrintScreen"))

    SL_Button.OnEvent("Click", (*) => SetSelectedKey("ScrollLock"))

    PB_Button.OnEvent("Click", (*) => SetSelectedKey("Pause"))

    FU_Button.OnEvent("Click", (*) => SetSelectedKey("``"))

    Num1_Button.OnEvent("Click", (*) => SetSelectedKey("1"))

    Num2_Button.OnEvent("Click", (*) => SetSelectedKey("2"))

    Num3_Button.OnEvent("Click", (*) => SetSelectedKey("3"))

    Num4_Button.OnEvent("Click", (*) => SetSelectedKey("4"))

    Num5_Button.OnEvent("Click", (*) => SetSelectedKey("5"))

    Num6_Button.OnEvent("Click", (*) => SetSelectedKey("6"))

    Num7_Button.OnEvent("Click", (*) => SetSelectedKey("7"))

    Num8_Button.OnEvent("Click", (*) => SetSelectedKey("8"))

    Num9_Button.OnEvent("Click", (*) => SetSelectedKey("9"))

    Num0_Button.OnEvent("Click", (*) => SetSelectedKey("0"))

    Minus_Button.OnEvent("Click", (*) => SetSelectedKey("-"))

    Equal_Button.OnEvent("Click", (*) => SetSelectedKey("="))

    Backspace_Button.OnEvent("Click", (*) => SetSelectedKey("Backspace"))

    Ins_Button.OnEvent("Click", (*) => SetSelectedKey("Ins"))

    Home_Button.OnEvent("Click", (*) => SetSelectedKey("Home"))

    PgUp_Button.OnEvent("Click", (*) => SetSelectedKey("PgUp"))

    Tab_Button.OnEvent("Click", (*) => SetSelectedKey("Tab"))

    Q_Button.OnEvent("Click", (*) => SetSelectedKey("Q"))

    W_Button.OnEvent("Click", (*) => SetSelectedKey("W"))

    E_Button.OnEvent("Click", (*) => SetSelectedKey("E"))

    R_Button.OnEvent("Click", (*) => SetSelectedKey("R"))

    T_Button.OnEvent("Click", (*) => SetSelectedKey("T"))

    Y_Button.OnEvent("Click", (*) => SetSelectedKey("Y"))

    U_Button.OnEvent("Click", (*) => SetSelectedKey("U"))

    I_Button.OnEvent("Click", (*) => SetSelectedKey("I"))

    O_Button.OnEvent("Click", (*) => SetSelectedKey("O"))

    P_Button.OnEvent("Click", (*) => SetSelectedKey("P"))

    LBrackets_Button.OnEvent("Click", (*) => SetSelectedKey("["))

    RBrackets_Button.OnEvent("Click", (*) => SetSelectedKey("]"))

    Backslash_Button.OnEvent("Click", (*) => SetSelectedKey("\"))

    Del_Button.OnEvent("Click", (*) => SetSelectedKey("Del"))

    End_Button.OnEvent("Click", (*) => SetSelectedKey("End"))

    PgDn_Button.OnEvent("Click", (*) => SetSelectedKey("PgDn"))

    CapsLock_Button.OnEvent("Click", (*) => SetSelectedKey("CapsLock"))

    A_Button.OnEvent("Click", (*) => SetSelectedKey("A"))

    S_Button.OnEvent("Click", (*) => SetSelectedKey("S"))

    D_Button.OnEvent("Click", (*) => SetSelectedKey("D"))

    F_Button.OnEvent("Click", (*) => SetSelectedKey("F"))

    G_Button.OnEvent("Click", (*) => SetSelectedKey("G"))

    H_Button.OnEvent("Click", (*) => SetSelectedKey("H"))

    J_Button.OnEvent("Click", (*) => SetSelectedKey("J"))

    K_Button.OnEvent("Click", (*) => SetSelectedKey("K"))

    L_Button.OnEvent("Click", (*) => SetSelectedKey("L"))

    Semicolon_Button.OnEvent("Click", (*) => SetSelectedKey(";"))

    Apostrophe_Button.OnEvent("Click", (*) => SetSelectedKey("'"))

    Enter_Button.OnEvent("Click", (*) => SetSelectedKey("Enter"))

    Left_Shift_Button.OnEvent("Click", (*) => SetSelectedKey("Shift"))

    Z_Button.OnEvent("Click", (*) => SetSelectedKey("Z"))

    X_Button.OnEvent("Click", (*) => SetSelectedKey("X"))

    C_Button.OnEvent("Click", (*) => SetSelectedKey("C"))

    V_Button.OnEvent("Click", (*) => SetSelectedKey("V"))

    B_Button.OnEvent("Click", (*) => SetSelectedKey("B"))

    N_Button.OnEvent("Click", (*) => SetSelectedKey("N"))

    M_Button.OnEvent("Click", (*) => SetSelectedKey("M"))

    Comma_Button.OnEvent("Click", (*) => SetSelectedKey(","))

    Period_Button.OnEvent("Click", (*) => SetSelectedKey("."))

    Slash_Button.OnEvent("Click", (*) => SetSelectedKey("/"))

    Right_Shift_Button.OnEvent("Click", (*) => SetSelectedKey("Shift"))

    Up_Button.OnEvent("Click", (*) => SetSelectedKey("Up"))

    Left_Ctrl_Button.OnEvent("Click", (*) => SetSelectedKey("Ctrl"))

    Win_Button.OnEvent("Click", (*) => SetSelectedKey("LWin"))

    Left_Alt_Button.OnEvent("Click", (*) => SetSelectedKey("Alt"))

    Space_Button.OnEvent("Click", (*) => SetSelectedKey("Space"))

    Right_Alt_Button.OnEvent("Click", (*) => SetSelectedKey("Alt"))

    Fn_Button.OnEvent("Click", (*) => SetSelectedKey("LWin"))

    Meau_Button.OnEvent("Click", (*) => SetSelectedKey("AppsKey"))

    Right_Ctrl_Button.OnEvent("Click", (*) => SetSelectedKey("Ctrl"))

    Left_Button.OnEvent("Click", (*) => SetSelectedKey("Left"))

    Down_Button.OnEvent("Click", (*) => SetSelectedKey("Down"))

    Right_Button.OnEvent("Click", (*) => SetSelectedKey("Right"))

    XButton1_Button.OnEvent("Click", (*) => SetSelectedKey("XButton1"))

    XButton2_Button.OnEvent("Click", (*) => SetSelectedKey("XButton2"))

    SetSelectedKey(key) {

        global SelectedKey

        SelectedKey := key

        SetTimer(() => Set_Hotkey.Destroy(), -10)

    }

}

; ========== 热键设置窗口 ==========

Build_Hotkey_Setting_Gui() {

    global Set_Hotkey_Gui, Hotkey1_Text, Hotkey2_Text

    Set_Hotkey_Gui := Gui()

    Set_Hotkey_Gui.Title := "键盘设置热键"

    Set_Hotkey_Gui.SetFont("s10")

    Hotkey1_Text := Set_Hotkey_Gui.addText("x10 y10 w240 h20", "破点断连网：" Keyboar1_Value)

    Hotkey1_Button := Set_Hotkey_Gui.addButton("x10 y40 w170 h30", "设置快捷键")

    Hotkey2_Text := Set_Hotkey_Gui.addText("x10 y80 w240 h20", "盾构技能键：" Keyboar2_Value)

    Hotkey2_Button := Set_Hotkey_Gui.addButton("x10 y100 w170 h30", "设置快捷键")

    Save_Keyboard_Config_Button := Set_Hotkey_Gui.addButton("x10 y140 w170 h30", "保存配置")

    Hotkey1_Button.OnEvent("Click", Set_Hotkey_func1)

    Hotkey2_Button.OnEvent("Click", Set_Hotkey_func2)

    Save_Keyboard_Config_Button.OnEvent("Click", Save_Keyboard_Config_Button_Func)

    Set_Hotkey_Gui.OnEvent("Close", Recover_Keyboard)

}

Set_Hotkey_func1(*) {

    global Keyboar1_Value, Hotkey1_Text

    GetKeyName()

    WinWaitClose("设置快捷键")

    if (SelectedKey != "暂未设置") {

        if (SelectedKey = "XButton2")

            Keyboar1_Value := "前侧键"

        else if (SelectedKey = "XButton1")

            Keyboar1_Value := "后侧键"

        else

            Keyboar1_Value := SelectedKey

        Hotkey1_Text.Text := "破点断连网：" Keyboar1_Value

    }

}

Set_Hotkey_func2(*) {

    global Keyboar2_Value, Hotkey2_Text

    GetKeyName()

    WinWaitClose("设置快捷键")

    if (SelectedKey != "暂未设置") {

        if (SelectedKey = "XButton2")

            Keyboar2_Value := "前侧键"

        else if (SelectedKey = "XButton1")

            Keyboar2_Value := "后侧键"

        else

            Keyboar2_Value := SelectedKey

        Hotkey2_Text.Text := "盾构技能键：" Keyboar2_Value

    }

}

Recover_Keyboard(*) {

    Read_Keyini()

    Hotkey1_Text.Text := "破点断连网：" Keyboar1_Value

    Hotkey2_Text.Text := "盾构技能键：" Keyboar2_Value

}

Save_Keyboard_Config_Button_Func(*) {

    global Keyboar1_Value, Keyboar2_Value

    if (Keyboar1_Value = "前侧键")

        IniWrite("XButton2", Set_Hotkey_Config_File, "Settings", "Hotkey1_name")

    else if (Keyboar1_Value = "后侧键")

        IniWrite("XButton1", Set_Hotkey_Config_File, "Settings", "Hotkey1_name")

    else

        IniWrite(Keyboar1_Value, Set_Hotkey_Config_File, "Settings", "Hotkey1_name")

    if (Keyboar2_Value = "前侧键")

        IniWrite("XButton2", Set_Hotkey_Config_File, "Settings", "Hotkey2_name")

    else if (Keyboar2_Value = "后侧键")

        IniWrite("XButton1", Set_Hotkey_Config_File, "Settings", "Hotkey2_name")

    else

        IniWrite(Keyboar2_Value, Set_Hotkey_Config_File, "Settings", "Hotkey2_name")

    MsgBox("配置已保存，重启程序后生效")

    ExitApp()

}

; ========== 系统托盘 ==========

InitializeSystemTray() {

    A_TrayMenu.Delete()

    A_TrayMenu.Add("显示窗口", Show_Window)

    A_TrayMenu.Add("退出 (End键退出)", Exit_Func)

    Hotkey("Home", Home_Window)

    OnMessage(0x404, Tray_Click)

}

Tray_Click(wParam, lParam, msg, hwnd) {

    if (lParam = 0x202)

        Home_Window()

}

Show_Window(*) {

    global Is_Hidden, MyGui

    MyGui.Show()

    Is_Hidden := false

}

Home_Window(*) {

    global Is_Hidden, MyGui

    if (Is_Hidden) {

        Show_Window()

    } else {

        MyGui.Hide()

        Is_Hidden := true

    }

}

; ========== 主 GUI 构建 ==========

Build_Main_Gui() {

    global MyGui, Wifi_Near_Switch_checked, Set_Recover_Time

    global Skill_Gun_checked, Gun_Recover_Time

    global Countdown_Show_Button, Tip_Music_Button

    Recover_Time := IniRead(Tool_Config_File, "Tool_Config", "Recover_Time", "7")

    Gun_Time := IniRead(Tool_Config_File, "Tool_Config", "Gun_Recover_Time", "600")

    Time_Switch_Content := IniRead(Tool_Config_File, "Tool_Config", "Time", "开启")

    Tip_Music_Content := IniRead(Tool_Config_File, "Tool_Config", "Tip_Music", "开启")

    MyGui := Gui()

    MyGui.Title := "SYL Delta Harness"

    MyGui.AddGroupBox("x10 y10 w320 h270 -Border c000000", "End键退出  Home键隐藏/呼出")

    MyGui.SetFont("s10")

    Wifi_Near_Switch_checked := MyGui.AddCheckbox("x35 y30 w140 h40", "断网开关(破点参数)")

    Set_Recover_Time := MyGui.AddEdit("x180 y41 w40 h20", Recover_Time)

    MyGui.AddText("x230 y41 w80 h40", "自动恢复网络(单位:秒)")

    Skill_Gun_checked := MyGui.AddCheckbox("x35 y70 w140 h30", "隔墙勾/隔墙枪自动")

    Gun_Recover_Time := MyGui.AddEdit("x180 y76 w40 h20", Gun_Time)

    MyGui.AddText("x230 y76 w80 h40", "自动恢复勾(单位:毫秒)")

    Countdown_Show_Button := MyGui.AddButton("x75 y110 w190 h30", "断连网倒计时：" Time_Switch_Content)

    Tip_Music_Button := MyGui.AddButton("x75 y150 w190 h30", "断连网提示音：" Tip_Music_Content)

    Keyboard_Shortcut_Button := MyGui.AddButton("x75 y190 w190 h30", "设置快捷键")

    Exit_Button := MyGui.AddButton("x75 y230 w190 h30", "退出")

    Wifi_Near_Switch_checked.OnEvent("Click", Wifi_Set_Function1)

    Set_Recover_Time.OnEvent("Change", Set_Recover_Time_Func)

    Gun_Recover_Time.OnEvent("Change", Set_Gun_Recover_Time_Func)

    Skill_Gun_checked.OnEvent("Click", Skill_Gun_Toggle)

    Countdown_Show_Button.OnEvent("Click", Countdown_Show_Button_Func)

    Tip_Music_Button.OnEvent("Click", Tip_Music_Button_Func)

    Keyboard_Shortcut_Button.OnEvent("Click", Keyboard_Shortcut_Func)

    Exit_Button.OnEvent("Click", Exit_Func)

    MyGui.OnEvent("Close", Exit_Func)

    MyGui.Show("w340 h290")

}

; ========== 断网开关主逻辑 ==========

Wifi_Set_Function1(*) {

    global Wifi_States1, Wifi_Time1, Wifi_Near_Switch_checked

    Wifi_States1 := !Wifi_States1

    Wifi_Near_Switch_checked.Value := Wifi_States1

    if (Wifi_States1) {

        Drop_Start_Func()

    } else {

        Drop_Stop_Func()

    }

    ; 倒计时悬浮窗

    if (Wifi_States1 && IniRead(Tool_Config_File, "Tool_Config", "Time") == "开启") {

        Countdown_Show_Func1()

    }

    ; 提示音

    if (Wifi_States1 && IniRead(Tool_Config_File, "Tool_Config", "Tip_Music") == "开启") {

        Tip_Music_Func_Start()

    } else if (!Wifi_States1 && IniRead(Tool_Config_File, "Tool_Config", "Tip_Music") == "开启") {

        Tip_Music_Func_End()

    }

    ; 自动恢复计时器

    if (Wifi_States1) {

        Wifi_Time1 := 0

        SetTimer(AutoRecover1, 1000)

    } else {

        SetTimer(AutoRecover1, 0)

        Wifi_Time1 := 0

    }

}

; ========== 自动恢复倒计时 ==========

AutoRecover1() {

    global Wifi_States1, Wifi_Time1, Wifi_Near_Switch_checked

    Wifi_Time1++

    if (Wifi_Time1 >= Set_Recover_Time.Value) {

        Wifi_States1 := false

        Drop_Stop_Func()

        if (IniRead(Tool_Config_File, "Tool_Config", "Tip_Music") == "开启") {

            Tip_Music_Func_End()

        }

        Wifi_Near_Switch_checked.Value := Wifi_States1

        SetTimer(AutoRecover1, 0)

        Wifi_Time1 := 0

    }

}

; ========== 配置保存 ==========

Set_Recover_Time_Func(*) {

    IniWrite(Set_Recover_Time.Value, Tool_Config_File, "Tool_Config", "Recover_Time")

}

Set_Gun_Recover_Time_Func(*) {

    IniWrite(Gun_Recover_Time.Value, Tool_Config_File, "Tool_Config", "Gun_Recover_Time")

}

; ========== 左键开枪自动恢复 ==========

Gun_Shoot_Func(*) {

    global Wifi_States1, Wifi_Time1

    KeyWait("LButton")

    if (Skill_Gun_checked.Value == 1 && Wifi_Near_Switch_checked.Value == 1) {

        FSleep(Gun_Recover_Time.Value, 20)

        Wifi_Near_Switch_checked.Value := 0

        Wifi_States1 := false

        Drop_Stop_Func()

        if (IniRead(Tool_Config_File, "Tool_Config", "Tip_Music") == "开启") {

            Tip_Music_Func_End()

        }

        SetTimer(AutoRecover1, 0)

        Wifi_Time1 := 0

    }

}

; ========== 隔墙勾开关（仅切换复选框状态，实际逻辑由热键触发） ==========

Skill_Gun_Toggle(*) {

    ; 空函数，点击复选框后 Value 自动更新，无需额外操作

}

; ========== 技能键自动恢复 ==========

Skill_Gun_Func(*) {

    global Wifi_States1, Wifi_Time1, Keyboard_Auto1

    KeyWait(Keyboard_Auto1)

    if (Skill_Gun_checked.Value == 1 && Wifi_Near_Switch_checked.Value == 1) {

        FSleep(Gun_Recover_Time.Value, 20)

        Wifi_Near_Switch_checked.Value := 0

        Wifi_States1 := false

        Drop_Stop_Func()

        if (IniRead(Tool_Config_File, "Tool_Config", "Tip_Music") == "开启") {

            Tip_Music_Func_End()

        }

        SetTimer(AutoRecover1, 0)

        Wifi_Time1 := 0

    }

}

; ========== 倒计时悬浮窗 ==========

Countdown_Show_Func1() {

    TimeGui := Gui()

    TimeGui.Opt("+AlwaysOnTop -Caption +ToolWindow")

    TimeGui.BackColor := "EEAA99"

    TimeGui.SetFont("s30")

    Countdown := TimeGui.Add("Text", "c48ff00", Set_Recover_Time.Value)

    WinSetTransColor(TimeGui.BackColor " 255", TimeGui)

    try {

        MonitorGetWorkArea(1, &Left, &Top, &Right, &Bottom)

    } catch {

        Left := 0, Top := 0, Right := A_ScreenWidth, Bottom := A_ScreenHeight

    }

    xPos := Right - 100

    yPos := Top

    TimeGui.Show("x" xPos " y" yPos " NA")

    SetTimer(CountdownTimer, 1000)

    CountdownTimer() {

        Countdown.Value := Countdown.Value - 1

        if (Wifi_Near_Switch_checked.Value == 0 || IniRead(Tool_Config_File, "Tool_Config", "Time") == "关闭" || Countdown.Value <= 0) {

            SetTimer(CountdownTimer, 0)

            TimeGui.Destroy()

        }

    }

}

Countdown_Show_Button_Func(*) {

    global Countdown_Show_State, Countdown_Show_Button

    Countdown_Show_State := !Countdown_Show_State

    newState := Countdown_Show_State ? "关闭" : "开启"

    Countdown_Show_Button.Text := "断连网倒计时：" newState

    IniWrite(newState, Tool_Config_File, "Tool_Config", "Time")

}

; ========== 提示音开关 ==========

Tip_Music_Button_Func(*) {

    global Tip_Music_State, Tip_Music_Button

    newState := (Tip_Music_State == "开启") ? "关闭" : "开启"

    Tip_Music_State := newState

    Tip_Music_Button.Text := "断连网提示音：" newState

    IniWrite(newState, Tool_Config_File, "Tool_Config", "Tip_Music")

}

; ========== 提示音播放 ==========

Tip_Music_Func_Start(*) {

    if FileExist(Start_Music_File)

        SoundPlay(Start_Music_File)

    Sleep(500)

}

Tip_Music_Func_End(*) {

    if FileExist(End_Music_File)

        SoundPlay(End_Music_File)

    Sleep(500)

}

; ========== 打开热键设置 ==========

Keyboard_Shortcut_Func(*) {

    Read_Keyini()

    Build_Hotkey_Setting_Gui()

    Set_Hotkey_Gui.Show("w200 h200")

}

; ========== 退出函数 ==========

Exit_Func(*) {

    global hModule

    Drop_Stop_Func()

    try {
        RunWait("C:\Windows\System32\sc.exe stop WinDivert", , "Hide")
        RunWait("C:\Windows\System32\sc.exe delete WinDivert", , "Hide")
    } catch

    if (hModule) {

        DllCall("FreeLibrary", "Ptr", hModule)

    }

    ProcessClose("Bindwidth.exe")

    ProcessClose("Limit.exe")

    ExitApp

}

; ========== 注册热键 ==========

RegisterHotkeys() {

    global Keyboard_Shortcut1, Keyboard_Auto1

    try {

        Hotkey("*" Keyboard_Shortcut1, Wifi_Set_Function1, "On")

    } catch {

        MsgBox("默认断网热键 " Keyboard_Shortcut1 " 无效，请在设置中重新配置。")

    }

    try {

        Hotkey("~" Keyboard_Auto1, Skill_Gun_Func, "On")

    } catch {

        ; 静默失败

    }

    try {

        Hotkey("~LButton", Gun_Shoot_Func, "On")

    } catch {

        ; 静默失败

    }

}

; ========== 主程序入口 ==========

Build_Main_Gui()

Build_Hotkey_Setting_Gui()

InitializeSystemTray()

RegisterHotkeys()

end:: Exit_Func()
