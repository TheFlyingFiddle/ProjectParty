ProjectParty
============

Bachelor project. Computer-Phone Multiplayer interactions via a games.

Build instructions (windows)
------------

1. Download and install visual studio 2012 or 2013 free licences can be gotten from msdn.

2. Download a windows SDK (7 or later)
    - It's only important to take C++ headers and C++ compilers when downloading.
    - You should do this befoure you install DMD since you will need to reinstall it after you have the sdk.

3. Download the dmd compiler (dlang.org) version 2.064.2 or later
4. Clone this project.
5. Open the project solution file (.sln file) this should open visual studio. To compile and run the program click the green play button.

### Trouble shooting

Visual D is not that great at finding the microsoft linker. The following error might appear when first trying to build the program: mspdb110.dll not found. 

This can be fixed by the following steps.

1. Navigate to Tools->Options->Projects and Solutions
2. Select Visual D Settings->DMD Directories
3. Select x64
4. Uncheck the checkbox that says (override linker settings from dmd configutation)
5. If this does not work check the checkbox again and change the linker textfield from $(VCINSTALLDIR)\bin\link.exe to $(VCINSTALLDIR)\bin\amd64\link.exe 

Another problem in Visual D is that it does not handle the 8.1 SDK paths well. If you get the following error: 
LINK : fatal error LNK1181: cannot open input file 'user32.lib' and are using the 8.1 sdk you need to edit the sc.ini file.

1. Locate the sc.ini file. It is at %D_INSTAL_DIR%\dmd2\windows\bin\sc.ini by default.
2. At the bottom of the page there is the text ; Platform libraries (Windows SDK 8)
   change the path under that line to LIB=%LIB%;"%WindowsSdkDir%\Lib\winv6.3\um\x64"
