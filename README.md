# Libro

Libro is an app for listening audio materials from

- public domain audiobook sites such as [librivox][librivox] and 
[internet archive][archive] and,
- most WebDAV servers hosting audiobooks and music albums including NextCloud.

If you want to build a light-weight self-hosted WebDAV servers check biblio.

# Features

- Automatically fetches metadata from [librivox][librivox] and [internet archive][archive].
- You can download materials locally to get better streaming experience 
and to reduce the mobile data usage.

# [Screenshots][screenshots]

# Todos

* better download progress indicator
* refactor defaultThumbnailImage logic
* when adding book download cover image too

# Bugs

* in DAV Browser, the first trial of adding items fails sometimes then works thereafter.

[librivox]: https://librivox.org
[archive]: https://archinve.org
[screenshots]: screenshots

# Notes

* Due to AGP bugs in v8.6 and v8.7, current AGP version is set to v8.5.2 
```
plugins {
    ...
    id("com.android.application") version "8.5.2" apply false
    ...
}
```
in `settings.gradle.kts`.
See [discussions in this issue](https://github.com/ryanheise/just_audio/issues/1468).

* Due to the regression in Flutter tooling, NDK verion is set to 
```
ndkVersion = "27.0.12077973"
```
in `app/build.gradle.kts`.