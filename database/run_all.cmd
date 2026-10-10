@echo off
chcp 65001 >nul
rem =====================================================================
rem  run_all.cmd  รันสคริปต์ฐานข้อมูลตามลำดับ: schema -> data -> logic -> queries
rem  วิธีใช้:   run_all.cmd [ชื่อเซิร์ฟเวอร์] [tests]
rem     ตัวอย่าง:  run_all.cmd                          (ใช้ LocalDB)
rem                 run_all.cmd .\SQLEXPRESS            (SQL Server Express)
rem                 run_all.cmd (localdb)\MSSQLLocalDB tests   (รันชุดทดสอบ+sanity ต่อท้าย)
rem  ใช้ Windows Authentication (-E), UTF-8 (-f 65001), QUOTED_IDENTIFIER ON (-I), หยุดเมื่อมี error (-b)
rem =====================================================================
setlocal
set SERVER=%~1
if "%SERVER%"=="" set SERVER=(localdb)\MSSQLLocalDB
set DB=CinemaTicketingDb
cd /d "%~dp0"

echo [0] สร้างฐานข้อมูล %DB% ถ้ายังไม่มี (เซิร์ฟเวอร์: %SERVER%)
sqlcmd -S "%SERVER%" -E -b -Q "IF DB_ID('%DB%') IS NULL CREATE DATABASE %DB%" || goto :fail

for %%F in (schema data logic queries) do (
  echo [run] %%F.sql
  sqlcmd -S "%SERVER%" -E -d %DB% -b -I -f 65001 -i %%F.sql || goto :fail
)

if /I "%~2"=="tests" (
  echo [run] sanity_checks.sql
  sqlcmd -S "%SERVER%" -E -d %DB% -b -I -f 65001 -i sanity_checks.sql || goto :fail
  echo [run] tests.sql
  sqlcmd -S "%SERVER%" -E -d %DB% -b -I -f 65001 -i tests.sql || goto :fail
)
echo เสร็จสมบูรณ์
exit /b 0
:fail
echo ล้มเหลว - ดูข้อความ error ด้านบน
exit /b 1
