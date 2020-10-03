;------------------------------------------------------------------------------
;-----------------------Inialize HotClipper
;Set tray Icon, delete and rebuild the master include file, add hot strings.
;NOTE: that despite the fact the include file is built before it is included changes will take effect on the next load.
;------------------------------------------------------------------------------
#SingleInstance Force

TraySetIcon("HotClipper.ico")

global startingClipboard
global userSetSendC
global LibAlreadyOpen
global clipLibGui
global SearchTermEdit
global LV
global LVArray
global sBar
global TotalItems
global myGui
global iniFILE := "settings.ini"

global tray := A_TrayMenu
Tray.Delete()
Tray.Add()
Tray.Add("Manager", "ManagerWindow")
Tray.Add("About", "AboutWindow")
Tray.Add("Options", "OptionsWindow")
Tray.Add("Exit", "TrayExit")
Tray.Default := "Manager"
FileDelete A_WorkingDir . "\includeMaster.ahk"
rebuildMasterInclude()


;Static users settings, need to be moved to an .ini
userIniFile := "settings.ini"

iniSetSendC := IniRead(userIniFile, "Capture Settings", "Send Ctrl+C on Win+I" , 1)

userSetSendC := iniSetSendC

#Include *i includeMaster.ahk

;------------------------------------------------------------------------------
; -----------------------Re-Build The Master Include
; Hotstrings are stored in the master include file as opitonal *i includes to pervent errors. The rebuild is done at start and at add to clean up the include list.
;------------------------------------------------------------------------------
rebuildMasterInclude(){
	MasterDirChange := "#Include %A_ScriptDir%\MyClips"
	FileList := ""
	Loop Files, A_WorkingDir . "\MyClips\*.ahk"
		FileList .= "`n#Include *i " . A_LoopFileName
		
	FileDelete A_WorkingDir . "\includeMaster.ahk"
	FileAppend MasterDirChange, A_WorkingDir . "\includeMaster.ahk"
	FileAppend FileList, A_WorkingDir . "\includeMaster.ahk"
	return
}
;------------------------------------------------------------------------------
; Win+N Support GUI Playground
;------------------------------------------------------------------------------

#h::
{
	BuildManager()
	return
}

BuildManager() {
	LVArray := []
	;Prevent more then one Clip Library GUI
	if (LibAlreadyOpen==1) {
	clipLibGui.Destroy()
	}
	clipLibGui := GuiCreate(,"HotClipper - Manager")
	clipLibGui.BackColor := "FF7700"
	LibAlreadyOpen :=1
	SearchTermEdit := clipLibGui.add("Edit", "BackgroundBlack cWhite w700")
	LV := clipLibGui.Add("ListView", "BackgroundBlack cWhite -Multi r20 w700", "Name|HotString|Added|Notes|Details")
;	NewPlainTextClipButton := clipLibGui.Add("Button", "w80 BackgroundYellow" ,"New Text Entry")
	DeleteButton := clipLibGui.Add("Button", "w700 BackgroundRed" ,"Delete Selected")
	; clipLibGui OnEvents
	DeafultButton := clipLibGui.Add("Button", "w50 x-5000 y-5000 BackgroundGreen Default" ,"Default")

	LV.OnEvent("DoubleClick", "LV_DoubleClick")
	LV.OnEvent("ItemSelect", "LV_ItemSelect")

	DeafultButton.OnEvent("Click", "DeafultButton_Click")
	DeleteButton.OnEvent("Click", "DeleteButton_Click")


	SearchTermEdit.OnEvent("Change", "SearchTermChange")
	
	FileList := ""
	Loop Files A_WorkingDir . "\MyClips\*.ahk"
		FileList .= "`n" . A_LoopFileName

	;trim off the extra starting newline
	FileList := LTrim(Filelist, "`n")


	; Gather a list of file names from a folder and put them into the ListView:
	Loop Parse, FileList, "`n"
	{
		Loop read, A_WorkingDir . "\MyClips\" . A_LoopField
		{
			if InStr(A_LoopReadLine, "::")
				Field2 := A_LoopReadLine
				Field2 := Trim(Field2, "::")
			if InStr(A_LoopReadLine, "Date")
				Field3 := A_LoopReadLine
				Field3 := LTrim(Field3, "Date ")
			if InStr(A_LoopReadLine, "Note ")
				Field4 := A_LoopReadLine
				Field4 := LTrim(Field4, "Note")
			if InStr(A_LoopReadLine, "App ")
				Field5 := A_LoopReadLine
				Field5 := LTrim(Field5, "App")
		}
		LV.Add(, A_LoopField,Field2,Field3,Field4,Field5)
		LVArray.Push({"1":A_LoopField,"2":Field2,"3":Field3,"4":Field4,"5":Field5})
	}
	LV.ModifyCol  ; Auto-size each column to fit its contents.
	LV.ModifyCol(5,0) ; hide details column to show as tooltip
	TotalItems := LVArray.Length
	sBar := clipLibGui.Add("StatusBar", , "Total Clips: " . TotalItems) 
	clipLibGui.Show
	clipLibGui.OnEvent("Escape", "UserInputEscapeCibLibGui")
	return
}

; search system 
SearchTermChange(*) {
global NewSearchTerm := SearchTermEdit.value

LV.Delete ; clear the List View for the new results

;build the results and and them to the List View
For Each, RowName In LVArray
{
   If (NewSearchTerm != "")
   {
		If (InStr(RowName.1, NewSearchTerm,false) != 0){
         LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
        }Else if (InStr(RowName.2, NewSearchTerm,false) != 0)
	   {LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
	   }Else if (InStr(RowName.3, NewSearchTerm,false) != 0)
	   {LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
	   }Else if (InStr(RowName.4, NewSearchTerm,false) != 0)
	   {LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
	   }
	   ;Uncommonent to also match Detials column.
	   ;Else if (InStr(RowName.5, NewSearchTerm,false) != 0)
	   ;{LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
	   ;}
   }
   Else
		LV.Add(, RowName.1, RowName.2,RowName.3,RowName.4,RowName.5)
}

Items := LV.GetCount() 
sBar.SetText("    " Items " of " TotalItems)
LV.Move(,true)
return
}

DeafultButton_Click(GuiCtrlObj, Info) {
	global SelectedLVItem
    SelectedLVItem := StrReplace(SelectedLVItem,".ahk",".clip")
    FileToRead := A_WorkingDir . "\MyClips\" . SelectedLVItem
	ClipData := FileRead(FileToRead, "RAW")
	Clipboard := ClipboardAll(ClipData)
    
    ToolTip("Loaded: " . SelectedLVItem)
    LibAlreadyOpen := 0
    clipLibGui.Destroy()
	
	SetTimer "Kill_ToolTip", 1000 ;after 1second
return
}


DeleteButton_Click(*){
	global SelectedLVItem
	SelectedLVItemToClip := StrReplace(SelectedLVItem,".ahk",".clip")
	FileRecycle  A_WorkingDir . "\MyClips\" SelectedLVItem
	FileRecycle  A_WorkingDir . "\MyClips\" SelectedLVItemToClip
	BuildManager()
return
}

LV_ItemSelect(LV,RowNumber,JunkThree) {
global SelectedLVItem := LV.GetText(RowNumber , 1)
return
}
LV_DoubleClick(LV, RowNumber) {
    RetrievedText := LV.GetText(RowNumber , 1)
    RetrievedText := StrReplace(RetrievedText,".ahk",".clip")
    FileToRead := A_WorkingDir . "\MyClips\" . RetrievedText
	ClipData := FileRead(FileToRead, "RAW")
	Clipboard := ClipboardAll(ClipData)
    
    ToolTip("Loaded: " . RetrievedText)
    LibAlreadyOpen := 0
    clipLibGui.Destroy()
	
SetTimer "Kill_ToolTip", 1000 ;after 1second
return
}

UserInputEscapeCibLibGui(*){
	LibAlreadyOpen := 0
    clipLibGui.Destroy()
	return
}
UserInputEscapemyGui(*){
    myGui.Destroy()
	return
}
UserInputEscapeOGui(*){
    OGui.Destroy()
	return
}

Kill_Tooltip(){
	ToolTip()
	return
}

;------------------------------------------------------------------------------
; Win+i Capture Clip file and enter save GUI
;------------------------------------------------------------------------------
#i::
{
	
	startingClipboard := Clipboard
	if userSetSendC == 1
		Send "{Ctrl down}c{Ctrl up}"
	global ClipName
	global ClipHotstring
	global ClipNameEdit
	global ClipHotstringEdit
	global UserNotesEdit
	

	;Make GUI to get ClipName and ClipHotstring
	myGui := GuiCreate(,"HotClipper - Add New Clip")
	myGui.BackColor := "ffaa00"
	myGui.Add("Text",, "Clip && File Name: (NO: /\:*?<>| )")
	ClipNameEdit := myGui.AddEdit("vClipName w165")
	myGui.Add("Text",, "Enter Hotstring: (optional)")
	ClipHotstringEdit := myGui.AddEdit("vClipHotstring w165")
	myGui.Add("Text",, "Notes:")
	UserNotesEdit := myGui.AddEdit("vUserNotes w165")
	saveButton :=myGui.Add("Button","Default w165 Backgroundffaa00", "SAVE")
	myGui.Add("Text",Center, "HotClipper will RELOAD on SAVE")
	saveButton.OnEvent("Click", "ButtonSAVE")
	myGui.Show
	myGui.OnEvent("Escape", "UserInputEscapemyGui")
	return
}

ButtonSAVE(*)
{
	;get the values from the forum fields.
	global ClipName := RegExReplace(ClipNameEdit.value, "`"|\*|\?|\||/|:|<|>|\\" , Replacement := "_")
	global ClipHotstring := ClipHotstringEdit.value 
	global UserNotes := UserNotesEdit.value 


	;Save Clipboard contents to a file with the name enter by the user.
	FileDelete A_WorkingDir . "\MyClips\" ClipName . ".clip"
	FileAppend ClipboardAll(), A_WorkingDir . "\MyClips\" . ClipName . ".clip"

	;Generate timestamp
	TimeStamp := FormatTime(A_Now, "yy-MM-dd")

if (ClipHotstring == ""){
	;This is what's going to go into the new hotstring script.
	NewScriptTMP := "/*`nDate " . TimeStamp . "`nApp " . WinGetTitle("A") . "`nNote " . UserNotes . "`n*/`n;::"
}Else{
	;This is what's going to go into the new hotstring script.
	NewScriptTMP := "/*`nDate " . TimeStamp . "`nApp " . WinGetTitle("A") . "`nNote " . UserNotes . "`n*/`n::" . ClipHotstring . "::`nFileToRead := A_WorkingDir . `"\MyClips\" . ClipName . ".clip`"`nstartingClipboard := Clipboard`nClipData := FileRead(FileToRead, `"RAW`")`nClipboard := ClipboardAll(ClipData)`nSleep 200`nSend `"{Ctrl down}v{Ctrl up}`"`nclipboard := startingClipboard`nReturn"
}
	;This is what's going to be apended to this script.
	AppenedTMP :="`n#Include *i " . ClipName . ".ahk"

	;Delete the file if it exists then make the script file.
	FileDelete A_WorkingDir . "\MyClips\" . ClipName . ".ahk"
	FileAppend NewScriptTMP, A_WorkingDir . "\MyClips\" . ClipName . ".ahk"

	;Rebuild the master include file and re-load the script:
	rebuildMasterInclude()
	if userSetSendC == 1
		clipboard := startingClipboard
	Reload
	return
}

OptionsWindow(*) {
	global opt1
	global OGui
	OGui := GuiCreate(,"HotClipper - Add New Clip")
	OGui.BackColor := "ffaa00"
	OGui.Add("Text",, "Options are saved on change")
	opt1 := OGui.Add("CheckBox", "vopt1", "Send Ctrl+C with Win+I?")
	opt1Value := IniRead(iniFILE, "Capture Settings", "Send Ctrl+C on Win+I" , 1)
	opt1.Value := opt1Value
	opt1.OnEvent("Click", "opt1CHECK")
	OGui.SHOW
	OGui.OnEvent("Escape", "UserInputEscapeOGui")

	return
}
opt1CHECK(*){
	global opt1
	global OGui
	NewVlaue := opt1.Value
	IniWrite NewVlaue, iniFILE, "Capture Settings", "Send Ctrl+C on Win+I"
	return
}
AboutWindow(*) {
	msgbox "HotClipper Version 1.0.1 Oct 2020"
	return
}
ManagerWindow(*) {
	BuildManager()
	return
}
TrayExit(*) {
	ExitApp 
	return
}

#If WinActive("HotClipper - Manager")
{
	Down::
	 {
		FocusedHwnd := ControlGetFocus("A")
		FocusedClassNN := ControlGetClassNN(FocusedHwnd)
		if (FocusedClassNN ="Edit1"){
		ControlFocus "SysListView321" , "HotClipper - Manager"
		return
		}
		Else {
			 Down::Down
		return
		}
	 return
	}
	Del::
	 {
		FocusedHwnd := ControlGetFocus("A")
		FocusedClassNN := ControlGetClassNN(FocusedHwnd)
		if (FocusedClassNN ="SysListView321"){
		global SelectedLVItem
		Result := MsgBox("Delete:" . SelectedLVItem . "?",, "YesNo")
		if Result = "Yes"
			DeleteButton_Click()
		else
		return
		}
		Else {
			 Del::Del
		return
		}
	return
	}
}