# Overr-Syncerr

Overr-Syncerr is a script designed to automate the management of subtitle synchronization issues across your media library. By leveraging **[Overseerr](https://overseerr.dev)** and **[Jellyseerr](https://github.com/Fallenbagel/jellyseerr)**'s built-in webhook and issue reporting functionality, this script allows users to specify the subtitles they need synchronized. It seamlessly integrates with your existing services such as **[Sonarr](https://sonarr.tv/)**, **[Radarr](https://radarr.video/)**, and **[Bazarr](https://www.bazarr.media)**, making the entire process of subtitle synchronization more automated.

<p align="center" >
  <a href="https://github.com/gssariev/overr-syncerr/releases"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Latest%20Release"></a>
  <picture><img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Stars"></picture>
  <a href="https://hub.docker.com/r/gsariev/overr-syncerr"><img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/gsariev/overr-syncerr?style=flat&logo=docker&logoColor=white&label=Docker%20Pulls"></a>
  <picture><img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/m/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Commits"></picture>
  <picture><img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues-closed/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white"></picture>
  <picture><img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white"></picture>
  <a href="https://github.com/gssariev/overr-syncerr/wiki"><img alt="Wiki" src="https://img.shields.io/badge/docs-wiki-forestgreen"></a>
</p>


## Current Features

- **Full Sonarr and Radarr Integration**: Easily fetch series and movie details from Sonarr and Radarr.
- **Bazarr Integration**: Synchronize subtitles using Bazarr, including support for 4K instances and HI subtitles.
- **Language Mapping**: Map keywords to language names based on webhook messages.
- **Subtitles**: Send 'sync', 'translate' and manual adjustment requests to Bazarr (using the 1st audio track + GSS).
- **Auto-reply & resolve issue**: Automatically reply to the reported subtitle issue in Overseerr upon subtitles synchronization and mark it as resolved.
- **Sync all episodes in season**: Submit all subtitles in a specific language to be synced by selecting 'All Episodes' when submitting the subtitle issue in Overseerr.

## Addititonal Features
- **Add User Label**: Create a personalised experience for your users by letting them see the media they want to see using labels. (Check the [Wiki](https://github.com/gssariev/overr-syncerr/wiki/4.-Adding-User-Label) on how to set it up)
- **Auto-labellingt**: Option to label requested media with the username of the requester in Plex (inspired by [Plex Requester Collection](https://github.com/manybothans/plex-requester-collections))
    
## Future plans

- **Wiki**: Updating the Wiki

## Known issues (WIP)

- **Discussions:** if discover any bugs or have a suggestion on how to improve the project, feel free to create a discussion or post an issue :)

## Getting Started

These instructions will help you set up and run Overr-Syncerr on your local machine.

### Prerequisites

- Docker installed on your machine.
- Docker Compose installed on your machine.

### Installation

1. **Pull the Docker image:**
   ```sh
   docker pull gsariev/overr-syncerr:latest
2. **Clone the repository:**
   ```sh
   git clone https://github.com/gssariev/overr-syncerr.git
   cd overr-syncerr
3. **Edit docker-compose.yml:**
```yaml
services:
  overr-syncerr:
    image: gsariev/overr-syncerr:latest
    container_name: overr-syncerr
    ports:
      - "8089:8089"
    environment:
    
      BAZARR_API_KEY: "YOUR_BAZARR_API_KEY"
      BAZARR_URL: "http://BAZARR_IP:BAZARR_PORT/api"
      
      RADARR_API_KEY: "YOUR_RADARR_API_KEY"
      RADARR_URL: "http://RADARR_IP:RADARR_PORT/api/v3"
      
      SONARR_API_KEY: "YOUR_SONARR_API_KEY"
      SONARR_URL: "http://SONARR_IP:SONARR_PORT/api/v3"
      
      BAZARR_4K_API_KEY: "YOUR_BAZARR_4K_API_KEY"
      BAZARR_4K_URL: "http://BAZARR_4K_IP:BAZARR_4K_PORT/api"
      
      RADARR_4K_API_KEY: "YOUR_RADARR_4K_API_KEY"
      RADARR_4K_URL: "http://RADARR_4K_IP:RADARR_4K_PORT/api/v3"
      
      SONARR_4K_API_KEY: "YOUR_SONARR_4K_API_KEY"
      SONARR_4K_URL: "http://SONARR_4K_IP:SONARR_4K_PORT/api/v3"

      # Enter your Jellyseerr API Key and URL instead if using Jellyseerr
      OVERSEERR_API_KEY: "YOUR_OVERSEERR_API"
      OVERSEERR_URL: "http://YOUR_OVERSEERR_URL:OVERSEERR_PORT/api/v1"

      PLEX_TOKEN: "YOUR_PLEX_TOKEN"
      PLEX_HOST: "http://YOUR_PLEX_SERVER_URL:PLEX_SERVER_PORT"

      #Library names for getting library IDs and adding user-label to media. Example below:
      ANIME_LIBRARY_NAME: "Anime"
      MOVIES_LIBRARY_NAME: "Movies"
      SERIES_LIBRARY_NAME: "Series"

      #Optional auto-labeling of requested media in Plex using requester username
      #Default is set to 'false'
      ENABLE_MEDIA_AVAILABLE_HANDLING: false

      PORT: 8089
      
      #Map specific keywords to your subtitle languages. Examples below:
      LANGUAGE_MAP: '{"da":"Danish",
      "en":"English",
      "bg":"Bulgarian",
      "dansk":"Danish",
      "english":"English",
      "danske":"Danish",
      "eng":"English"}'

      SYNC_KEYWORDS: '["sync", "out of sync", "messed up", "synchronization"]' # Replace with your actual sync keywords

      restart: unless-stopped
```
   
4. **Run the Docker container using Docker Compose:**
   Use Docker Compose to build and run the container.
   ```sh
   docker-compose up --build

The container listens for webhooks on the port you've specified. Ensure Overseerr is configured to send webhook requests to the following endpoint: **http://your-ip-address:your-port/**

### Overseerr Webhook

In your Overseerr instance go to:

1. Settings -> Notificaitons -> Webhook
2. Enable the webhook agent and paste the endpoint **http://your-ip-address:your-port/** into the Webhook URL field
3. Make sure 'Issue Reported' is ticked
4. Test to see if the webhook notificaiton is sent
5. Save Changes

### Usage

#### Subtitle sync
1. In Overserr, navigate to the media that has unsynced subtitles
2. Report a 'Subtitle' issue
3. Mention the langauge of the subtitles (using the specific pre-mapped keywords), if the media is 4K and if the subtitles are HI or not, and if the media needs to be synced (using the specific pre-mapped sync keywords)
4. Bazarr will start syncing the subtitles to the first audio track
5. Upon completion, Overseerr will reply to the created subtitle issue and mark it as resolved

#### Plex Label
1. In Overseerr, navigate to the media that you want to add your label to
2. Report a 'Other' issue type
3. In the issue message, type: Add to library
4. Once the label has been added, Overseerr will reply to the created issue mark it as resolved

## Contributors

Big thank you to the people helping furher develop this project!

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kirsch33"><img src="https://avatars1.githubusercontent.com/u/37373320?v=4?s=100" width="100px;" alt="sct"/><br /><sub><b>kirsch33</b></sub></a><br /><a href="https://github.com/gssariev/overr-syncerr/tree/kirsch33-patch-1" title="Code">💻</a> </td> 
    </tr>
    </tbody>
</table>



   




