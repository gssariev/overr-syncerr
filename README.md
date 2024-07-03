# Overr-Syncerr

Overr-Syncerr is a script designed to automate the management of subtitle synchronization issues across your media library. By leveraging **[Overseerr](https://overseerr.dev)**'s built-in webhook and issue reporting functionality, this script allows users to specify the subtitles they need synchronized. It seamlessly integrates with your existing services such as **[Sonarr](https://sonarr.tv/)**, **[Radarr](https://radarr.video/)**, and **[Bazarr](https://www.bazarr.media)**, making the entire process of subtitle more automated.

## Current Features

- **Full Sonarr and Radarr Integration**: Easily fetch series and movie details from Sonarr and Radarr.
- **Bazarr Integration**: Retrieve and synchronize subtitles from Bazarr, including support for 4K media and HI subtitles.
- **Language Mapping**: Map keywords to langauge names based on webhook messages.
- **Audio Sync**: Uses the first audio track to sync subtitles to.

## Future plans

- **Auto-reply and resolve issue**: Automatically reply to the reported subtitle issue in Overseerr upon subtitles synchronization and mark it as resolved.

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
   Open the docker-compose.yml file and replace the placeholders with your actual API keys, URLs, Ports and map keywords to the subtitle languages you use in Bazarr (look at the example structure in the docker-compose)
4. **Run the Docker container using Docker Compose:**
   Use Docker Compose to build and run the container.
   ```sh
   docker-compose up --build

The container listens for webhooks on the port you've specified. Ensure Overseerr is configured to send webhook requests to the following endpoint: **http://your-docker-host:your-port/**

### Overseerr Webhook

In your Overseerr instance go to:

1. Settings -> Notificaitons -> Webhook
2. Enable the webhook agent and paste the endpoint **http://your-docker-host:your-port/** into the Webhook URL field
3. Make sure 'Issue Reported' is ticked
4. Test to see if the webhook notificaiton is sent
5. Save Changes

### Usage

1. In Overserr, navigate to the media that has unsynced subtitles
2. Report a subtitle issue
3. Mention the langauge of the subtitles (using the specific pre-mapped keywords), if the media is 4K and if the subtitles are HI or not.
4. Wait for the subtitles to be synced

As long as the issue message contains keywords that have been mapped to match the desired language, the contents of the message can be anything (see preview examples).

**ALWAYS SPECIFY THE SEASON AND EPISODE FOR SERIES**

The time varies based on your system, but in my tests - 1080p media takes less than 5 min while 4K could take less than 10 min.

## Preview

### Movies
<img src="./previews/movies.gif">

### Series
<img src="./previews/series.gif">


## License
This project is licensed under the MIT License - see the LICENSE file for details.
   




