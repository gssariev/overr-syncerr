FROM mcr.microsoft.com/powershell:7.1.3-ubuntu-20.04

WORKDIR /app

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
ENV OVERSEERR_API_KEY=""
ENV OVERSEERR_URL=""
ENV PORT=8089
ENV LANGUAGE_MAP="{}"
ENV SYNC_KEYWORDS='[]'
ENV PLEX_TOKEN=""
ENV PLEX_HOST=""
ENV ANIME_LIBRARY_NAME=""
ENV MOVIES_LIBRARY_NAME=""
ENV SERIES_LIBRARY_NAME=""

COPY . .

ENTRYPOINT ["pwsh", "/app/overr-syncerr-main.ps1"]
