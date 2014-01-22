ProjectParty
============

Bachelor project. Computer-Phone Multiplayer interactions via a games.

Build instructions (windows)
------------

1. Download and install visual studio 2012 or 2013 free licences can be gotten from msdn.

2. Download a windows SDK (7 or later)
    - It's only important to take C++ headers and C++ compilers when downloading.

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