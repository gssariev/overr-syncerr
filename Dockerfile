FROM mcr.microsoft.com/powershell:latest

RUN apt update && apt install -y docker.io

WORKDIR /app

COPY . .

ENTRYPOINT ["pwsh", "/app/overr-syncerr-main.ps1"]
