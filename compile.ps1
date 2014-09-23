$CompileAgain = "Y"
do {
cmd /c compile.exe -f diablo2.sma
$CompileAgain = Read-Host "Скомпилировать снова? (Y/N)"
}
while ($CompileAgain -eq "Y")