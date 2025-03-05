FROM mcr.microsoft.com/powershell:7.1.3-ubuntu-20.04

RUN apt update && apt install -y docker.io

WORKDIR /app

COPY . .

ENTRYPOINT ["pwsh", "/app/overr-syncerr-main.ps1"]
