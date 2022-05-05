; Script generated by the HM NIS Edit Script Wizard.

; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "Web and Open Data Validator"
!define PRODUCT_VERSION "6.14.0"
!define PRODUCT_PUBLISHER "TPSGC-PWGSC"
!define PRODUCT_WEB_SITE "https://github.com/wet-boew/wet-boew-wpss"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\${PRODUCT_NAME}"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; MUI 1.67 compatible ------
!include "MUI.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Language Selection Dialog Settings
!define MUI_LANGDLL_REGISTRY_ROOT "${PRODUCT_UNINST_ROOT_KEY}"
!define MUI_LANGDLL_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "NSIS:Language"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "French"

; MUI end ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "C:\WPSS_Tool_Release\WPSS_Tool.exe"
InstallDir "$PROGRAMFILES\WPSS_Tool"
; InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show

Function .onInit
  !insertmacro MUI_LANGDLL_DISPLAY

;
; Check for Perl
;
${Switch} $LANGUAGE
${Case} ${LANG_ENGLISH}
  Banner::show /NOUNLOAD "Checking for Perl"
${Break}
${Case} ${LANG_FRENCH}
  Banner::show /NOUNLOAD "Recherche de Perl"
${Break}
${EndSwitch}
 
  nsExec::Exec 'perl.exe -version'
  Pop $0
  StrCmp $0 0 continueperl noperl
   noperl:
${Switch} $LANGUAGE
${Case} ${LANG_ENGLISH}
    MessageBox MB_OK "The installer can not find Perl on this computer"
${Break}
${Case} ${LANG_FRENCH}
    MessageBox MB_OK "L�installateur n�arrive pas � localiser Perl sur cet ordinateur"
${Break}
${EndSwitch}
    Abort
  continueperl:
    Banner::destroy
    Return
FunctionEnd

Section "Main Section" SEC01
  CreateDirectory "$SMPROGRAMS\Web and Open Data Validator"
  CreateShortCut "$SMPROGRAMS\Web and Open Data Validator\Web Tool.lnk" "$INSTDIR\wpss_tool.pl"
  CreateShortCut "$DESKTOP\Web Tool.lnk" "$INSTDIR\wpss_tool.pl"
  CreateShortCut "$SMPROGRAMS\Web and Open Data Validator\Open Data Tool.lnk" "$INSTDIR\open_data_tool.pl"
  CreateShortCut "$DESKTOP\Open Data Tool.lnk" "$INSTDIR\open_data_tool.pl"
  CreateShortCut "$SMPROGRAMS\Web and Open Data Validator\Uninstall.lnk" "$INSTDIR\uninst.exe"

SetOutPath "$INSTDIR\bin"
File "C:\WPSS_Tool\bin\*.*"
SetOutPath "$INSTDIR\bin\csv-validator"
File "C:\WPSS_Tool\bin\csv-validator\*.*"
SetOutPath "$INSTDIR\bin\csv-validator\bin"
File "C:\WPSS_Tool\bin\csv-validator\bin\*.*"
SetOutPath "$INSTDIR\bin\csv-validator\lib"
File "C:\WPSS_Tool\bin\csv-validator\lib\*.*"
SetOutPath "$INSTDIR\bin\epubcheck"
File "C:\WPSS_Tool\bin\epubcheck\*.*"
SetOutPath "$INSTDIR\bin\epubcheck\lib"
File "C:\WPSS_Tool\bin\epubcheck\lib\*.*"
SetOutPath "$INSTDIR\bin\feedvalidator"
File "C:\WPSS_Tool\bin\feedvalidator\*.*"
SetOutPath "$INSTDIR\bin\feedvalidator\formatter"
File "C:\WPSS_Tool\bin\feedvalidator\formatter\*.*"
SetOutPath "$INSTDIR\bin\feedvalidator\i18n"
File "C:\WPSS_Tool\bin\feedvalidator\i18n\*.*"
SetOutPath "$INSTDIR\bin\pdfchecker"
File "C:\WPSS_Tool\bin\pdfchecker\*.*"
SetOutPath "$INSTDIR\bin\pdfchecker\pyPdf"
File "C:\WPSS_Tool\bin\pdfchecker\pyPdf\*.*"
SetOutPath "$INSTDIR\conf"
File "C:\WPSS_Tool\conf\*.*"
SetOutPath "$INSTDIR\python"
File "C:\WPSS_Tool\python\*.*"
SetOutPath "$INSTDIR\lib\CLI"
File "C:\WPSS_Tool\lib\CLI\*.*"
SetOutPath "$INSTDIR\lib\CSS\Adaptor"
File "C:\WPSS_Tool\lib\CSS\Adaptor\*.*"
SetOutPath "$INSTDIR\lib\CSS\Parse"
File "C:\WPSS_Tool\lib\CSS\Parse\*.*"
SetOutPath "$INSTDIR\lib\CSS"
File "C:\WPSS_Tool\lib\CSS\*.*"
SetOutPath "$INSTDIR\lib\File"
File "C:\WPSS_Tool\lib\File\*.*"
SetOutPath "$INSTDIR\lib\GUI"
File "C:\WPSS_Tool\lib\GUI\*.*"
SetOutPath "$INSTDIR\lib\Lingua\EN"
File "C:\WPSS_Tool\lib\Lingua\EN\*.*"
SetOutPath "$INSTDIR\lib\Image\Info\SVG"
File "C:\WPSS_Tool\lib\Image\Info\SVG\*.*"
SetOutPath "$INSTDIR\lib\Image\Info"
File "C:\WPSS_Tool\lib\Image\Info\*.*"
SetOutPath "$INSTDIR\lib\Image"
File "C:\WPSS_Tool\lib\Image\*.*"
SetOutPath "$INSTDIR\lib\Image\ExifTool"
File "C:\WPSS_Tool\lib\Image\ExifTool\*.*"
SetOutPath "$INSTDIR\lib\Image\ExifTool\Charset"
File "C:\WPSS_Tool\lib\Image\ExifTool\Charset\*.*"
SetOutPath "$INSTDIR\lib\Image\ExifTool\Lang"
File "C:\WPSS_Tool\lib\Image\ExifTool\Lang\*.*"
SetOutPath "$INSTDIR\lib\LWP\RobotUA"
File "C:\WPSS_Tool\lib\LWP\RobotUA\*.*"
SetOutPath "$INSTDIR\lib\Text"
File "C:\WPSS_Tool\lib\Text\*.*"
SetOutPath "$INSTDIR\lib"
File "C:\WPSS_Tool\lib\*.*"
SetOutPath "$INSTDIR\LM"
File "C:\WPSS_Tool\LM\*.*"
SetOutPath "$INSTDIR\documents\licenses"
File "C:\WPSS_Tool\documents\licenses\*.*"
SetOutPath "$INSTDIR\documents\licenses\doc"
File "C:\WPSS_Tool\documents\licenses\doc\*.*"
SetOutPath "$INSTDIR\documents"
File "C:\WPSS_Tool\documents\*.*"
SetOutPath "$INSTDIR\nsgmls\bin"
File "C:\WPSS_Tool\nsgmls\bin\*.*"
SetOutPath "$INSTDIR\nsgmls\doc"
File "C:\WPSS_Tool\nsgmls\doc\*.*"
SetOutPath "$INSTDIR\nsgmls\pubtext"
File "C:\WPSS_Tool\nsgmls\pubtext\*.*"
SetOutPath "$INSTDIR"
File "C:\WPSS_Tool\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib"
File "C:\WPSS_Tool\wdg\sgml-lib\*.*"
File "C:\WPSS_Tool\wdg\sgml-lib\catalog"
SetOutPath "$INSTDIR\wdg\sgml-lib\xhtml1"
File "C:\WPSS_Tool\wdg\sgml-lib\xhtml1\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\xhtml-basic10"
File "C:\WPSS_Tool\wdg\sgml-lib\xhtml-basic10\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\xhtml11"
File "C:\WPSS_Tool\wdg\sgml-lib\xhtml11\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\mathml2"
File "C:\WPSS_Tool\wdg\sgml-lib\mathml2\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\mathml2\html"
File "C:\WPSS_Tool\wdg\sgml-lib\mathml2\html\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\mathml2\iso8879"
File "C:\WPSS_Tool\wdg\sgml-lib\mathml2\iso8879\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\mathml2\iso9573-13"
File "C:\WPSS_Tool\wdg\sgml-lib\mathml2\iso9573-13\*.*"
SetOutPath "$INSTDIR\wdg\sgml-lib\mathml2\mathml"
File "C:\WPSS_Tool\wdg\sgml-lib\mathml2\mathml\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14"
File "C:\WPSS_Tool\Win32-GUI-1.14\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\build_tools"
File "C:\WPSS_Tool\Win32-GUI-1.14\build_tools\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\docs"
File "C:\WPSS_Tool\Win32-GUI-1.14\docs\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\docs\GUI"
File "C:\WPSS_Tool\Win32-GUI-1.14\docs\GUI\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\docs\GUI\Reference"
File "C:\WPSS_Tool\Win32-GUI-1.14\docs\GUI\Reference\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\docs\GUI\Tutorial"
File "C:\WPSS_Tool\Win32-GUI-1.14\docs\GUI\Tutorial\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\docs\GUI\UserGuide"
File "C:\WPSS_Tool\Win32-GUI-1.14\docs\GUI\UserGuide\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\samples"
File "C:\WPSS_Tool\Win32-GUI-1.14\samples\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\scripts"
File "C:\WPSS_Tool\Win32-GUI-1.14\scripts\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_AxWindow"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_AxWindow\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_AxWindow\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_AxWindow\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_AxWindow\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_AxWindow\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_BitmapInline"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_BitmapInline\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_BitmapInline\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_BitmapInline\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI-Constants"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI-Constants\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI-Constants\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI-Constants\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI-Constants\hash"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI-Constants\hash\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI-Constants\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI-Constants\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DIBitmap"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DIBitmap\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DIBitmap\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DIBitmap\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DIBitmap\extlib"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DIBitmap\extlib\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DIBitmap\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DIBitmap\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DropFiles"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DropFiles\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DropFiles\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DropFiles\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_DropFiles\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_DropFiles\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Grid"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Grid\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Grid\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Grid\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Grid\MFCGrid"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Grid\MFCGrid\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Grid\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Grid\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_ReleaseNotes"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_ReleaseNotes\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_ReleaseNotes\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_ReleaseNotes\t\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Scintilla"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Scintilla\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Scintilla\demos"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Scintilla\demos\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Scintilla\Include"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Scintilla\Include\*.*"
SetOutPath "$INSTDIR\Win32-GUI-1.14\Win32-GUI_Scintilla\t"
File "C:\WPSS_Tool\Win32-GUI-1.14\Win32-GUI_Scintilla\t\*.*"
SetOutPath "$INSTDIR\Win32\IE"
File "C:\WPSS_Tool\Win32\IE\*.*"
SetOutPath "$INSTDIR"
SectionEnd

Section -Installpl
;
; Run WPSS Install program
;
  nsexec::exectolog '"cmd.exe" /c "$INSTDIR\install.pl"'
  Pop $0
  StrCmp $0 0 continueinstall noinstall
  noinstall:
    MessageBox MB_OK "Failed to install Web and Open Data Validator"
    Abort

  continueinstall:
; MessageBox MB_OK "You have successfully initialized the Web and Open Data Validator"
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
;  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\wpss_tool.pl"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
;  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd


Function un.onUninstSuccess
  HideWindow
${Switch} $LANGUAGE
${Case} ${LANG_ENGLISH}
  MessageBox MB_ICONINFORMATION|MB_OK "Web and Open Data Validator was successfully removed from your computer."
${Break}
${Case} ${LANG_FRENCH}
  MessageBox MB_ICONINFORMATION|MB_OK "Le Validateur web et donn�es ouvertes a �t� supprim� de votre ordinateur."
${Break}
${EndSwitch}
FunctionEnd

Function un.onInit
!insertmacro MUI_UNGETLANGUAGE
${Switch} $LANGUAGE
${Case} ${LANG_ENGLISH}
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove Web and Open Data Validator and all of its components?" IDYES +2
  Abort
${Break}
${Case} ${LANG_FRENCH}
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Souhaitez-vous r�ellement supprimer totalement le Validateur web et donn�es ouvertes et tous ses composants?" IDYES +2
  Abort
${Break}
${EndSwitch}
FunctionEnd

Section Uninstall
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\conf"
  RMDir /r "$INSTDIR\python"
  RMDir /r "$INSTDIR\lib"
  RMDir /r "$INSTDIR\LM"
  RMDir /r "$INSTDIR\documents"
  RMDir /r "$INSTDIR\nsgmls"
  RMDir /r "$INSTDIR\wdg"
  RMDir /r "$INSTDIR\Win32-GUI-1.14"
  RMDir /r "$INSTDIR\Win32"
  RMDir /r "$INSTDIR\logs"
  RMDir /r "$INSTDIR\results"
  RMDir /r "$INSTDIR\profiles"
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"
  RMDir "c:\wpss_tool_temp"

  Delete "$DESKTOP\Web Tool.lnk"
  Delete "$DESKTOP\Open Data Tool.lnk"

  Delete "$SMPROGRAMS\Web and Open Data Validator\Uninstall.lnk"
  Delete "$SMPROGRAMS\Web and Open Data Validator\Web Tool.lnk"
  Delete "$SMPROGRAMS\Web and Open Data Validator\Open Data Tool.lnk"
  RMDir  "$SMPROGRAMS\Web and Open Data Validator"
  Delete "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Web and Open Data Validator\Uninstall.lnk"
  Delete "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Web and Open Data Validator\Web Tool.lnk"
  Delete "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Web and Open Data Validator\Open Data Tool.lnk"
  RMDir  "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Web and Open Data Validator"

;  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
;  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"

  SetAutoClose true
SectionEnd
