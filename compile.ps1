$CompileAgain = "Y"
do {
cmd /c compile.exe -f diablo2.sma
$CompileAgain = Read-Host "�������������� �����? (Y/N)"
}
while ($CompileAgain -eq "Y")