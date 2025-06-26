# Overr-Syncerr

This project was created to improve my Plex experience—and that of my users—by giving them just enough control to solve one of the biggest challenges: subtitles. Over time, it has expanded to include features like automatic media labeling, better translations, and, most recently, personalized audio preferences. Now, users can have their preferred language, codec, and channel count automatically selected, ensuring the best audio experience while reducing unnecessary transcoding.
While this project is designed around my setup, you're welcome to adapt it to fit your own needs!

Overr-Syncerr is a script designed to automate the management of subtitle synchronization issues across your media library. By leveraging **[Overseerr](https://overseerr.dev)** and **[Jellyseerr](https://github.com/Fallenbagel/jellyseerr)**'s built-in webhook and issue reporting functionality, this script allows users to specify the subtitles they need synchronized. It seamlessly integrates with your existing services such as **[Sonarr](https://sonarr.tv/)**, **[Radarr](https://radarr.video/)**, and **[Bazarr](https://www.bazarr.media)**, making the entire process of subtitle synchronization more automated.

<p align="center">
  <img src="https://github.com/user-attachments/assets/3e44a171-67f8-47f5-b7f3-4fedbf0756c1" alt="Overr-Syncerr_logo" width="200">
</p>

<p align="center" >
  <a href="https://github.com/gssariev/overr-syncerr/releases"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Latest%20Release"></a>
  <picture><img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Stars"></picture>
  <a href="https://hub.docker.com/r/gsariev/overr-syncerr"><img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/gsariev/overr-syncerr?style=flat&logo=docker&logoColor=white&label=Docker%20Pulls"></a>
  <picture><img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/m/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white&label=Commits"></picture>
  <picture><img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues-closed/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white"></picture>
  <picture><img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues/gssariev/overr-syncerr?style=flat&logo=github&logoColor=white"></picture>
  <a href="https://docs.overrsyncerr.info"><img alt="Wiki" src="https://img.shields.io/badge/docs-wiki-forestgreen"></a>
</p>

## Getting Started

Refer to the official Overr-Syncerr docs at - https://wiki.overrsyncerr.info

## IMPORTANT ##
**Enable Overseer Request Monitor **AFTER** you've run the script to generate subtitle and audio preferences jsons to ensure that the correct settings get applied.**

## Current Features

- **Full Sonarr and Radarr Integration**: Easily fetch series and movie details from Sonarr and Radarr.
- **Bazarr Integration**: Synchronize subtitles using Bazarr, including support for 4K instances and HI subtitles.
- **Language Mapping**: Map keywords to language names based on webhook messages.
- **Subtitles**: Send 'sync', 'translate' and manual adjustment requests to Bazarr (using the 1st audio track + GSS).
- **Auto-reply & resolve issue**: Automatically reply to the reported subtitle issue in Overseerr/Jellyseerr upon subtitles synchronization and mark it as resolved.
- **Sync all episodes in season**: Submit all subtitles in a specific language to be synced by selecting 'All Episodes' when submitting the subtitle issue.
- **User Audio Preference:** set preffered audio track based on language, codec and channel per user automatically once media becomes available
- **User Subtitle Preference:** set preffered subtitle track based on language, codec, forced or hearing impaired properties per user automatically once media becomes available
- **Auto-labelling**: Option to label available requested media with the username of the requester in Plex (inspired by [Plex Requester Collection](https://github.com/manybothans/plex-requester-collections))
- **Translate Subs Using GPT**: Option to use OpenAI GPT instead of Google Translate for subtitle translation **OpenAI API Key Required**

## MEDIUX Specific Features

### Filters
- **Preferred Creator**: specify the creator or list of creators that sets and/or collections should be filtered by
- **Artwork Type**: specifically if you want to fetch only posters, season posters or title cards, a mix of either or all
- **Clean Version**: specify if you want to prioritse "Clean Version"-type sets over regular sets (if availalbe)

### Artwork
- **Movies**: automatically fetch and apply movie artwork when marked as available in Overseerr/Jellyseerr
- **TV**: automatically fetch and apply shows, season and title card artwork when marked as available in Overseerr/Jellyseerr
- **Track Missing Artwork**: store missing artwork information for media in your Plex library and periodically check for availability and update it once/if artwork becomes available. Configure the schedule (CRON) and number of days check should be performed. Media that is still missing artwork after the specified days will no longer be processed.
- **Kometa Support**: automatically remove the 'Overlay' Kometa label from media when artwork is applied, so that Kometa can re-apply overlays for that media

### Additional Mediux Config
- **Plex Webhook**: it's recommended to configue Overr-Syncerr as a payload receiver for Plex webhooks for tracking and applying episode title cards and season posters for incomplete/airing shows

### To Be Implemented
- **Backdrop artwork**
- **Collection poster artowrk**

## Known issues (WIP)

- If you've encountered and issue or have a suggestions, you're welcome to post about it :)

## Contributors

Big thank you to the people helping furher develop this project!

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kirsch33"><img src="https://avatars1.githubusercontent.com/u/37373320?v=4?s=100" width="100px;"/><br /><sub><b>kirsch33</b></sub></a><br /><a href="https://github.com/gssariev/overr-syncerr/tree/kirsch33-patch-1" title="Code">💻</a> </td> 
    </tr>
    </tbody>
<tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/nwithan8"><img src="https://avatars.githubusercontent.com/u/17054780?v=4?s=100" width="100px;"/><br /><sub><b>nwithan8</b></sub></a><br /><a href="https://github.com/nwithan8/unraid_templates" title="Unraid Template">💻</a> </td> 
    </tr>
    </tbody>
  
</table>



   




