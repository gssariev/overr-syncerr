FROM mcr.microsoft.com/powershell:7.1.3-ubuntu-20.04

ENV BAZARR_API_KEY=""
ENV BAZARR_URL=""
ENV RADARR_API_KEY=""
ENV RADARR_URL=""
ENV SONARR_API_KEY=""
ENV SONARR_URL=""
ENV BAZARR_4K_API_KEY=""
ENV BAZARR_4K_URL=""
ENV RADARR_4K_API_KEY=""
ENV RADARR_4K_URL=""
ENV SONARR_4K_API_KEY=""
ENV SONARR_4K_URL=""
ENV PORT=8089
ENV LANGUAGE_MAP="{}"

# Copy the PowerShell script into the Docker image
COPY overr-sync.ps1 /overr-sync.ps1

# Set the entry point to run the PowerShell script
ENTRYPOINT ["pwsh", "/overr-sync.ps1"]
