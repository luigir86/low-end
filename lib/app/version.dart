/// The app's version, the same as `version:` in pubspec.yaml (a test keeps
/// them equal): shown in About, so that the player can tell which update
/// the phone or the browser is running.
const appVersion = '1.6.3+13';

/// The commit a web build was made from, passed by the deploy workflow
/// (.github/workflows/web.yml); empty in the Android app.
const appBuild = String.fromEnvironment('LOW_END_BUILD');

/// What About shows: "1.6.3+13", and on the web "1.6.2+12 · web 5eea2dc".
String get appVersionLabel => appBuild.isEmpty
    ? appVersion
    : '$appVersion · web ${appBuild.length > 7 ? appBuild.substring(0, 7) : appBuild}';
