FROM mcr.microsoft.com/powershell:7.1.3-ubuntu-20.04

WORKDIR /app

COPY . .

ENTRYPOINT ["pwsh", "/app/overr-syncerr-main.ps1"]
