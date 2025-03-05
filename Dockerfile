FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

WORKDIR /app

COPY . .

ENTRYPOINT ["pwsh", "/app/overr-syncerr-main.ps1"]
