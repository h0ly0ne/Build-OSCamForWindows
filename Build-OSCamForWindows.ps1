$currentPath = Get-Location

try
{
	Clear-Host
	
	Write-Host "AUTOMATED OSCAM COMPILER SCRIPT FOR WINDOWS"
	Write-Host
	Write-Host "The whole process is fully automated. You only need this script, internet access"
	Write-Host "and at least 2 GB free disk space in the temp directory."
	Write-Host
	Write-Host "OScam is compiled with all options enabled (only hardware specific components ommited)."
	Write-Host
	Write-Host "Some steps may take several minutes, please be patient."
	Write-Host

	$tempPath = (Join-Path -Path $PSScriptRoot -ChildPath Build-OScamForWindows)
	if (-not (Test-Path -Path $tempPath -PathType Container)) {
		New-Item -Path $tempPath -ItemType Directory | Out-Null
	}
	else {
		Remove-Item -LiteralPath $tempPath -Force -Recurse | Out-Null
		New-Item -Path $tempPath -ItemType Directory | Out-Null
	}
	Set-Location -Path $tempPath
	
	Write-Host "Current build directory: $tempPath"
@'
	:: set proxy if required (unfortunately Cygwin setup.exe does not have commandline options to specify proxy user credentials)
	set PROXY_HOST=
	set PROXY_PORT=8080

	:: change the URL to the closest mirror https://cygwin.com/mirrors.html
	set CYGWIN_MIRROR=https://mirrors.kernel.org/sourceware/cygwin/

	:: one of: auto,64,32 - specifies if 32 or 64 bit version should be installed or automatically detected based on current OS architecture
	set CYGWIN_ARCH=auto

	:: choose a user name under Cygwin
	set CYGWIN_USERNAME=root

	:: select the packages to be installed automatically via apt-cyg
	set CYGWIN_PACKAGES=libssl-devel=1.1.1w-1,openssl=1.1.1w-1,autoconf,autoconf-archive,automake,gcc-core,git,libtool,libusb-devel,libusb0,libusb1.0,libusb1.0-devel,make,mingw64-x86_64-gcc-core,wget,zip

	:: if set to 'yes' the local package cache created by cygwin setup will be deleted after installation/update
	set DELETE_CYGWIN_PACKAGE_CACHE=yes

	:: if set to 'yes' the apt-cyg command line package manager (https://github.com/kou1okada/apt-cyg) will be installed automatically
	set INSTALL_APT_CYG=no

	:: if set to 'yes' the bash-funk adaptive Bash prompt (https://github.com/vegardit/bash-funk) will be installed automatically
	set INSTALL_BASH_FUNK=no

	:: if set to 'yes' Node.js (https://nodejs.org/) will be installed automatically
	set INSTALL_NODEJS=no

	:: Use of the folder names found here https://nodejs.org/dist/ as version name.
	set NODEJS_VERSION=latest-v25.x

	:: one of: auto,64,32 - specifies if 32 or 64 bit version should be installed or automatically detected based on current OS architecture
	set NODEJS_ARCH=auto

	:: if set to 'yes' Ansible (https://github.com/ansible/ansible) will be installed automatically
	set INSTALL_ANSIBLE=no
	set ANSIBLE_GIT_BRANCH=stable-2.20

	:: if set to 'yes' AWS CLI (https://github.com/aws/aws-cli) will be installed automatically
	set INSTALL_AWS_CLI=no

	:: if set to 'yes' testssl.sh (https://testssl.sh/) will be installed automatically
	set INSTALL_TESTSSL_SH=no

	:: name of the GIT branch to install from, see https://github.com/drwetter/testssl.sh/
	set TESTSSL_GIT_BRANCH=3.2

	:: use ConEmu based tabbed terminal instead of Mintty based single window terminal, see https://conemu.github.io/
	set INSTALL_CONEMU=no
	set CON_EMU_OPTIONS=-Title cygwin-portable ^
	 -QuitOnClose

	:: if set to 'yes' the winpty (https://github.com/rprichard/winpty) will be installed automatically
	set INSTALL_WINPTY=no
	set WINPTY_VERSION=0.4.3

	:: add more path if required, but at the cost of runtime performance (e.g. slower forks)
	set "CYGWIN_PATH=%%SystemRoot%%\system32;%%SystemRoot%%"

	:: set Mintty options, see https://cdn.rawgit.com/mintty/mintty/master/docs/mintty.1.html#CONFIGURATION
	set MINTTY_OPTIONS=--Title cygwin-portable ^
	  -o Columns=160 ^
	  -o Rows=50 ^
	  -o BellType=0 ^
	  -o ClicksPlaceCursor=yes ^
	  -o CursorBlinks=yes ^
	  -o CursorColour=96,96,255 ^
	  -o CursorType=Block ^
	  -o CopyOnSelect=yes ^
	  -o RightClickAction=Paste ^
	  -o Font="Courier New" ^
	  -o FontHeight=10 ^
	  -o FontSmoothing=None ^
	  -o ScrollbackLines=10000 ^
	  -o Transparency=off ^
	  -o Term=xterm-256color ^
	  -o Charset=UTF-8 ^
	  -o Locale=C
'@ | Out-File -FilePath (-join($tempPath,'\cygwin-portable-installer-config.cmd')) -Force -Encoding ascii

    Write-Host
    Write-Host "Downloading latest Cygwin Portable Installer ... " -NoNewline
    Remove-Item -Force (-join($tempPath,'cygwin-portable-installer.cmd')) -ErrorAction SilentlyContinue

    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/h0ly0ne/cygwin-portable-installer/main/cygwin-portable-installer.cmd' -OutFile (-join($tempPath,'\cygwin-portable-installer.cmd')) -UseBasicParsing

    Write-Host "done."

    Write-Host 
    if ((-not (Test-Path -PathType container -Path (-join($tempPath,'\cygwin')))) -or (-not (Test-Path -PathType leaf -Path (-join($tempPath,'\cygwin-portable.cmd')))) -or (-not (Test-Path -PathType leaf -Path (-join($tempPath,'\cygwin-portable-updater.cmd'))))) {
        Write-Host "Installing Cygwin Portable ... " -NoNewline
        $p = Start-Process -FilePath (-join($tempPath,'\cygwin-portable-installer.cmd')) -Wait -PassThru 
        Write-Host "done. Exit code $($p.Exitcode)."
    } else {
        Remove-Item -Recurse -Force (-join($tempPath,'\cygwin')) -ErrorAction SilentlyContinue
        Write-Host "(Re)Installing Cygwin Portable ... " -NoNewline
        $p = Start-Process -FilePath (-join($tempPath,'\cygwin-portable-installer.cmd')) -Wait -PassThru 
        Write-Host "done. Exit code $($p.Exitcode)."
    }

    if ($p.ExitCode -ne 0) {
        Write-Host "Exit code not 0, exiting." -ForegroundColor red
        Set-Location $currentPath
        exit 1
    }

    $x = @'
        cd ~/

        echo "START TIMESTAMP: $(date --rfc-3339='seconds')"
        echo "======================================================================"

        echo
        echo "PREPARATIONS"
        echo "======================================================================"
        if [ "libdvbcsa-git" ]; then
            rm -r -f libdvbcsa-git
        fi
        if [ "oscam-git" ]; then
            rm -r -f oscam-git
        fi
        if [ "oscam-exe" ]; then
            rm -r -f oscam-exe
        fi
        if [ "oscam-zip" ]; then
            rm -r -f oscam-zip
        fi

        echo
        echo "GIT CHECKOUT LIBDVBCSA TRUNK"
        echo "======================================================================"
        git clone https://github.com/h0ly0ne/libdvbcsa libdvbcsa-git
        cd libdvbcsa-git

        echo
        echo "PATCH AND BUILD LIBDVBCSA"
        echo "======================================================================"
        if [ "libdvbcsa22.patch" ]; then
            rm -r -f libdvbcsa22.patch
        fi
        wget https://raw.githubusercontent.com/h0ly0ne/libdvbcsa/refs/heads/master/patches/libdvbcsa22.patch
        git config apply.whitespace nowarn
        git apply --verbose libdvbcsa22.patch
        autoupdate
        ./bootstrap
        ./configure --prefix=/usr --enable-static
        make
        make install
        cd ..

        echo
        echo "GIT CHECKOUT OSCAM TRUNK"
        echo "======================================================================"
        git clone https://git.streamboard.tv/common/oscam.git oscam-git
        cd oscam-git

        echo
        echo "DOWNLOAD OSCAM-EMU.PATCH"
        echo "======================================================================"
        if [ "oscam-emu.patch" ]; then
            rm -r -f oscam-emu.patch
        fi
        wget https://raw.githubusercontent.com/h0ly0ne/oscam-emu-patch/refs/heads/master/oscam-emu.patch

        echo
        echo "APPLY PATCH AND BUILD PATCHED OSCAM"
        echo "======================================================================"
        git apply --verbose oscam-emu.patch 
        make distclean
        ./config.sh --disable all
        ./config.sh --enable WEBIF WEBIF_LIVELOG WEBIF_JQUERY WITH_SSL WITH_COMPRESS_WEBIF HAVE_DVBAPI WITH_EXTENDED_CW READ_SDT_CHARSETS CS_ANTICASC WITH_DEBUG MODULE_MONITOR WITH_LB CS_CACHEEX CS_CACHEEX_AIO CW_CYCLE_CHECK CLOCKFIX MODULE_CAMD33 MODULE_CAMD35 MODULE_CAMD35_TCP MODULE_NEWCAMD MODULE_CCCAM MODULE_CCCSHARE MODULE_GBOX MODULE_RADEGAST MODULE_SCAM MODULE_SERIAL MODULE_CONSTCW MODULE_PANDORA MODULE_GHTTP MODULE_STREAMRELAY READER_NAGRA READER_NAGRA_MERLIN READER_IRDETO READER_CONAX READER_CRYPTOWORKS READER_SECA READER_VIACCESS READER_VIDEOGUARD READER_DRE READER_TONGFANG READER_BULCRYPT READER_GRIFFIN READER_DGCRYPT CARDREADER_PHOENIX CARDREADER_SC8IN1 CARDREADER_MP35 CARDREADER_SMARGO CARDREADER_STINGER WITH_EMU WITH_SOFTCAM
        make CONF_DIR=./ USE_SSL=1 USE_LIBCRYPTO=1 USE_LIBUSB=1 USE_PCSC=1 PCSC_LIB='-lwinscard' USE_LIBDVBCSA=1 LIBDVBCSA_LIB='/usr/lib/libdvbcsa.a'
        cd ..

        echo
        echo "COPY BUILT EXE FILES AND RENAME THEM"
        echo "======================================================================"
        mkdir ~/oscam-exe
        cd ~/oscam-exe
        rm -rf ~/oscam-git/Distribution/*.debug
        cp ~/oscam-git/Distribution/*cygwin* -t .
        for z in $(ls oscam*)
        do
            mv $z oscam.exe
        done
        for i in $(ls list_smargo*)
        do
            mv $i list_smargo.exe
        done

        echo
        echo "COPY DEPENDENT CYGWIN DLL FILES"
        echo "======================================================================"
        for i in $(ls *.exe)
        do
            cygcheck.exe "$(cygpath -u -a $i)" | while read -r x
            do
                if [[ $x =~ \\bin\\cyg.*\.dll ]]
                then
                    cp "$x" -t .
                fi
            done
        done

        echo
        echo "CREATE ZIP FILE"
        echo "======================================================================"
        mkdir ~/oscam-zip
        zip -9 ~/oscam-zip/${z}.zip *

        echo
        echo "END TIMESTAMP: $(date --rfc-3339='seconds')"
        echo "======================================================================"
'@

    Write-Host
    Write-Host "Downloading latest components and compiling them ... " -NoNewline
    if ($($PSVersionTable.PSEdition) -ieq 'Core') {
        Set-Content -Value (New-Object System.Text.UTF8Encoding $false).GetBytes(($x -ireplace "`r`n", "`n") + "`n") -AsByteStream -Path (-join($tempPath,'\cygwin\home\root\make.sh')) -Force -NoNewline
    } else {
        Set-Content -Value (New-Object System.Text.UTF8Encoding $false).GetBytes(($x -ireplace "`r`n", "`n") + "`n") -Encoding Byte -Path (-join($tempPath,'\cygwin\home\root\make.sh')) -Force -NoNewline
    }
    $p = Start-Process -FilePath (-join($tempPath,'\cygwin-portable.cmd')) -ArgumentList '-c "~/make.sh 2>&1 | tee /tmp/oscam-buildlog.txt"' -Wait -PassThru
    $p.WaitForExit()
    Write-Host "done. Exit code $($p.exitcode)."

    if ($p.ExitCode -ne 0) {
        Write-Host "Exit code not 0, exiting." -ForegroundColor red
        exit 1
    }

    Write-Host
    Write-Host "Creating oscam-info.txt, collecting oscam-buildlog.txt and adding to compressed file ... " -NoNewline
    $p = [System.Diagnostics.Process]::Start([System.Diagnostics.ProcessStartInfo] @{"FileName" = -join($tempPath,'\cygwin\home\root\oscam-exe\oscam.exe'); "Arguments" = '--build-info'; "UseShellExecute" = $false; "RedirectStandardOutput" = $true})
    $output = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()

    $output | Out-File -FilePath (-join($tempPath,'\cygwin\home\root\oscam-exe\oscam-info.txt'))
    if ([System.IO.File]::Exists((-join($tempPath,'\cygwin\tmp\oscam-buildlog.txt')))){
        Copy-Item -Path (-join($tempPath,'\cygwin\tmp\oscam-buildlog.txt')) -Destination (-join($tempPath,'\cygwin\home\root\oscam-exe\'))
    }
    Compress-Archive -Path (-join($tempPath,'\cygwin\home\root\oscam-exe\*'))  -Update -DestinationPath ((Get-ChildItem (-join($tempPath,'\cygwin\home\root\oscam-zip\*.zip')) | Select-Object -First 1).fullname)
    Write-Host "done. Exit code $($p.exitcode)."

    if ($p.ExitCode -ne 0) {
        Write-Host "Exit code not 0, exiting." -ForegroundColor red
        exit 1
    }

    Write-Host
    Write-Host "Cleanup local export locations, copy compiled zip and extract it ... " -NoNewline	
    if (-not [string]::IsNullOrEmpty($currentPath)) {
        if (Test-Path -PathType container -Path (-join($currentPath,'\oscam-exe'))) {
            Remove-Item -Path (-join($currentPath,'\oscam-exe')) -Recurse -Force
            New-Item -Path $currentPath -Name "oscam-exe" -ItemType "directory" | Out-Null
        } else {
            New-Item -Path $currentPath -Name "oscam-exe" -ItemType "directory" | Out-Null
        }
        
        if (-not (Test-Path -PathType container -Path (-join($currentPath,'\oscam-zip')))) {
            New-Item -Path $currentPath -Name "oscam-zip" -ItemType "directory" | Out-Null
        }

        $x = (Get-ChildItem -Path (Join-Path -Path $tempPath -ChildPath "cygwin\home\root\oscam-zip\*.zip") | Where-Object { ! $_.PSIsContainer } | Select-Object -First 1).fullname
        $y = Join-Path -Path (Join-Path -Path $currentPath -ChildPath "oscam-zip") -ChildPath (Split-Path $x -Leaf)

        Copy-Item -Path $x -Destination $y -Force
        Expand-Archive -Path $y -DestinationPath (Join-Path -Path $currentPath -ChildPath "oscam-exe") -Force

        Write-Host "done."
    }

    Write-Host
    Write-Host
    Write-Host "Find 'oscam.exe', required Cygwin DLLs, 'oscam-info.txt' (output of 'oscam.exe --build-info'),"
    Write-Host "and 'oscam-buildlog.txt' here:" 

    if (-not [string]::IsNullOrEmpty($currentPath)) {
        Write-Host ("  '" + (Join-Path -Path $currentPath -ChildPath "oscam-exe") + "'") 
    } else {
        Write-Host ("  '" + (Join-Path -Path $tempPath -ChildPath "oscam-exe") + "'") 
    }

    Write-Host
    Write-Host "Find a ZIP file containing all files required for redistribution here:" 

    if (-not [string]::IsNullOrEmpty($currentPath)) {
        Write-Host ("  '" + (Join-Path -Path $currentPath -ChildPath "oscam-zip") + "'") 
    } else {
        Write-Host ("  '" + (Join-Path -Path $tempPath -ChildPath "oscam-zip") + "'") 
    }

    Write-Host
    Write-Host
}
finally
{
    Set-Location $currentPath
}