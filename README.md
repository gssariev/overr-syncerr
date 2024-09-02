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
- **Auto-reply & resolve issue**: Automatically reply to the reported subtitle issue in Overseerr/Jellyseerr upon subtitles synchronization and mark it as resolved.
- **Sync all episodes in season**: Submit all subtitles in a specific language to be synced by selecting 'All Episodes' when submitting the subtitle issue.

## Addititonal Features
- **Add User Label**: Create a personalised experience for your users by letting them see the media they want to see using labels. (Check the [Wiki](https://github.com/gssariev/overr-syncerr/wiki/4.-Adding-User-Label) on how to set it up)
- **Auto-labelling**: Option to label available requested media with the username of the requester in Plex (inspired by [Plex Requester Collection](https://github.com/manybothans/plex-requester-collections))    

## Known issues (WIP)

- **Discussions:** if discover any bugs or have a suggestion on how to improve the project, feel free to create a discussion or post an issue :)

## Getting Started

Refer to the official Overr-Syncerr docs at - https://docs.overrsyncerr.info

### Want to help?
- Looking for someone who can make a Unraid template
- Help with translations/localisation

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



   




