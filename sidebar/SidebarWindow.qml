import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// =============================================================================
// Nothing OS Dot-Matrix Music Sidebar / Peek Drawer (Ctrl + Super + S)
// Allows peeking at whatever music or YouTube video is playing without switching
// windows or workspaces, adjusting volume/brightness, switching players, and
// saving favorite songs to playlist.
// =============================================================================
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:sidebar"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore

    anchors {
        top: true
        bottom: true
        right: true
        left: true
    }

    color: "transparent"

    property bool isOpen: false
    visible: isOpen || drawerCard.x < root.width

    // =========================================================================
    // Typography System (Official Nothing OS Fonts)
    // =========================================================================
    FontLoader { id: fontNdot55; source: Qt.resolvedUrl("../assets/fonts/Ndot55-Regular.otf") }
    FontLoader { id: fontNdot57; source: Qt.resolvedUrl("../assets/fonts/Ndot57-Regular.otf") }
    FontLoader { id: fontNType;  source: Qt.resolvedUrl("../assets/fonts/NType82-Regular.otf") }
    FontLoader { id: fontNMono;  source: Qt.resolvedUrl("../assets/fonts/LetteraMonoLL-Regular.otf") }

    // =========================================================================
    // Multi-Player Support (Spotify, YouTube in Brave/Chrome/Firefox, VLC, etc.)
    // =========================================================================
    readonly property var playerList: {
        var list = [];
        var vals = Mpris.players.values;
        if (vals) {
            for (var i = 0; i < vals.length; i++) {
                list.push(vals[i]);
            }
        }
        return list;
    }

    property int selectedPlayerIdx: 0

    // Auto-select currently playing player if current one is paused/stopped
    readonly property var activePlayer: {
        if (!playerList || playerList.length === 0) return null;
        if (selectedPlayerIdx >= 0 && selectedPlayerIdx < playerList.length)
            return playerList[selectedPlayerIdx];
        return playerList[0];
    }

    function formatPlayerName(identity, entry): string {
        var str = ((identity || entry || "") + "").toLowerCase();
        if (str.indexOf("spotify") !== -1) return "SPOTIFY";
        if (str.indexOf("brave") !== -1) return "YOUTUBE · BRAVE";
        if (str.indexOf("chrome") !== -1) return "YOUTUBE · CHROME";
        if (str.indexOf("firefox") !== -1) return "YOUTUBE · FIREFOX";
        if (str.indexOf("vlc") !== -1) return "VLC";
        return (identity || entry || "MEDIA").toUpperCase();
    }

    // Auto-switch to active player when opened
    function autoPickActivePlayer(): void {
        if (!playerList || playerList.length === 0) return;
        for (var i = 0; i < playerList.length; i++) {
            if (playerList[i].playbackState === MprisPlaybackState.Playing) {
                root.selectedPlayerIdx = i;
                return;
            }
        }
    }

    // =========================================================================
    // Pipewire Audio & Brightness Integrations
    // =========================================================================
    readonly property PwNode audioSink: Pipewire.defaultAudioSink
    readonly property bool audioReady: audioSink !== null && audioSink.ready && audioSink.audio !== null
    readonly property real volumeLevel: audioReady ? audioSink.audio.volume : 0.0
    readonly property bool isMuted: audioReady ? audioSink.audio.muted : false
    readonly property int volumePercent: isMuted ? 0 : Math.round(volumeLevel * 100)
    PwObjectTracker { objects: audioSink !== null ? [audioSink] : [] }

    property real brightnessLevel: 0.36
    readonly property int brightnessPercent: Math.round(brightnessLevel * 100)

    // Dynamic stats (lyrics, album color, timestamps)
    property var stats: ({
        "lyrics": [],
        "album_color": "#282426",
        "track_position": 0.0,
        "track_duration": 0.0,
        "track_progress": 0.0,
        "position_str": "0:00",
        "duration_str": "--:--"
    })

    // Saved playlist items
    property var playlistItems: []
    property bool isCurrentTrackSaved: false
    property string toastMessage: ""

    // Drawer dimensions
    readonly property int drawerW: 380
    readonly property int cardRadius: 24

    function open(): void {
        root.isOpen = true;
        autoPickActivePlayer();
        refreshStats();
        refreshPlaylist();
        queryBrightness();
    }

    function close(): void {
        root.isOpen = false;
    }

    function toggle(): void {
        if (root.isOpen) root.close();
        else root.open();
    }

    // =========================================================================
    // IPC Handler: qs -p ... ipc call sidebar toggle/open/close
    // =========================================================================
    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    // =========================================================================
    // Background Processes (Stats & Playlist)
    // =========================================================================
    Process {
        id: statsProc
        command: ["python3", Quickshell.shellDir + "/widgets/stats.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed) {
                        root.stats = parsed;
                        checkCurrentSaved();
                    }
                } catch (e) {}
            }
        }
    }

    function refreshStats(): void {
        if (!statsProc.running) statsProc.running = true;
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.isOpen
        onTriggered: root.refreshStats()
    }

    // Playlist CLI helper
    Process {
        id: listPlaylistProc
        command: ["python3", Quickshell.shellDir + "/sidebar/playlist.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.playlistItems = JSON.parse(text) || [];
                    checkCurrentSaved();
                } catch (e) {}
            }
        }
    }

    function refreshPlaylist(): void {
        if (!listPlaylistProc.running) listPlaylistProc.running = true;
    }

    function checkCurrentSaved(): void {
        var title = "";
        var artist = "";
        if (root.activePlayer) {
            title = root.activePlayer.trackTitle || "";
            if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
            else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
                artist = root.activePlayer.trackArtists[0];
        }
        title = title.trim().toLowerCase();
        artist = artist.trim().toLowerCase();

        if (!title || title === "no track playing") {
            root.isCurrentTrackSaved = false;
            return;
        }

        var found = false;
        for (var i = 0; i < root.playlistItems.length; i++) {
            var it = root.playlistItems[i];
            if ((it.title || "").trim().toLowerCase() === title &&
                (!artist || (it.artist || "").trim().toLowerCase() === artist)) {
                found = true;
                break;
            }
        }
        root.isCurrentTrackSaved = found;
    }

    function toggleSaveCurrentTrack(): void {
        if (!root.activePlayer || !root.activePlayer.trackTitle) {
            showToast("No active track playing");
            return;
        }
        var title = root.activePlayer.trackTitle || "";
        var artist = "";
        if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
        else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
            artist = root.activePlayer.trackArtists[0];
        var album = root.activePlayer.trackAlbum || "";
        var artUrl = root.activePlayer.trackArtUrl || "";
        var url = (root.activePlayer.trackUrl || "");
        var duration = root.stats.duration_str || "";

        if (root.isCurrentTrackSaved) {
            // Remove
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/sidebar/playlist.py", "remove", title, artist]);
            root.isCurrentTrackSaved = false;
            showToast("Removed from My Playlist");
        } else {
            // Add
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/sidebar/playlist.py", "add", title, artist, album, artUrl, url, duration]);
            root.isCurrentTrackSaved = true;
            showToast("✓ Added to My Playlist");
        }
        playlistRefreshTimer.restart();
    }

    Timer {
        id: playlistRefreshTimer
        interval: 300
        repeat: false
        onTriggered: root.refreshPlaylist()
    }

    function removePlaylistTrack(id: string): void {
        Quickshell.execDetached(["python3", Quickshell.shellDir + "/sidebar/playlist.py", "remove", id]);
        showToast("Track removed from My Playlist");
        playlistRefreshTimer.restart();
    }

    function playPlaylistTrack(urlOrUri: string): void {
        Quickshell.execDetached(["python3", Quickshell.shellDir + "/sidebar/playlist.py", "play", urlOrUri]);
        showToast("Playing track in Spotify...");
    }

    function showToast(msg: string): void {
        root.toastMessage = msg;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2200
        onTriggered: root.toastMessage = ""
    }

    // Brightness query
    Process {
        id: queryBrightnessProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim();
                var parts = out.split(",");
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3].replace("%", "").trim());
                    if (!isNaN(pct)) root.brightnessLevel = pct / 100.0;
                }
            }
        }
    }

    function queryBrightness(): void {
        if (!queryBrightnessProc.running) queryBrightnessProc.running = true;
    }

    // =========================================================================
    // Backdrop Scrim (Click outside or Escape to close)
    // =========================================================================
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: root.close()
    }

    // =========================================================================
    // Main Floating Drawer Card (Right Edge)
    // Zero sharp corner leaks (100% round 24px mask & radius)
    // =========================================================================
    Item {
        id: drawerCard
        width: root.drawerW
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 16
        anchors.bottomMargin: 16

        // Smooth Slide In/Out from Right Screen Edge
        x: root.isOpen ? (root.width - width - 16) : root.width + 20
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Prevent click-through to backdrop
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: (event) => { event.accepted = true; }
        }

        // 1. Frosted Glass Base Layer (Clean 24px Rounded Corners)
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: root.cardRadius
            color: Qt.rgba(0.08, 0.08, 0.09, 0.80)
            border.width: 1
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
        }

        // 2. Ambient Dynamic Album Glow (Radius 24px, zero corner leak)
        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: {
                        var c = Qt.color(root.stats && root.stats.album_color ? root.stats.album_color : "#282426");
                        return Qt.rgba(c.r, c.g, c.b, 0.28);
                    }
                }
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop {
                    position: 1.0
                    color: {
                        var c2 = Qt.color(root.stats && root.stats.album_color ? root.stats.album_color : "#282426");
                        return Qt.rgba(c2.r, c2.g, c2.b, 0.18);
                    }
                }
            }
        }

        // 3. Specular Shine Layer (Radius 24px - Eliminates sharp top-left corner!)
        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: "transparent"
            border.width: 0
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1.0, 1.0, 1.0, 0.08) }
                GradientStop { position: 0.25; color: Qt.rgba(1.0, 1.0, 1.0, 0.01) }
                GradientStop { position: 1.00; color: "transparent" }
            }
        }

        // =====================================================================
        // Drawer Content Column
        // =====================================================================
        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // 1. TOP HEADER (Branding, Dot Indicator, Close Button)
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                            ? "#FF3B30"
                            : Qt.rgba(1, 1, 1, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "NOW PLAYING"
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                        font.bold: true
                        color: "#FFFFFF"
                        font.family: fontNMono.name || "Fira Sans"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "· SIDEBAR"
                        font.pixelSize: 9
                        font.letterSpacing: 1.0
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: fontNMono.name || "Fira Sans"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Close Button (✕)
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: closeBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // 2. QUICK SLIDERS CARD (Volume & Brightness - Nothing OS Style)
            Rectangle {
                width: parent.width
                height: 74
                radius: 16
                color: Qt.rgba(1.0, 1.0, 1.0, 0.05)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Volume Slider Row
                    Row {
                        width: parent.width
                        height: 22
                        spacing: 10

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.isMuted
                                ? Qt.resolvedUrl("../assets/volume-mute-dot.svg")
                                : Qt.resolvedUrl("../assets/volume-dot.svg")
                            sourceSize: Qt.size(16, 16)
                        }

                        // Track
                        Rectangle {
                            width: parent.width - 16 - 40 - 20
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.16)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(6, parent.width * (root.isMuted ? 0 : root.volumeLevel))
                                radius: 3
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (!root.audioReady) return;
                                    var pct = Math.max(0.0, Math.min(1.0, mouse.x / width));
                                    root.audioSink.audio.muted = false;
                                    root.audioSink.audio.volume = pct;
                                }
                            }
                        }

                        Text {
                            width: 40
                            text: root.isMuted ? "MUTE" : (root.volumePercent + "%")
                            font.pixelSize: 11
                            font.family: fontNdot57.name || "Fira Sans"
                            color: root.isMuted ? Qt.rgba(1, 1, 1, 0.5) : "#FFFFFF"
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Brightness Slider Row
                    Row {
                        width: parent.width
                        height: 22
                        spacing: 10

                        // Sun dot icon
                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [
                                    {x: 8, y: 5.5, r: 0.9}, {x: 8, y: 10.5, r: 0.9},
                                    {x: 5.5, y: 8, r: 0.9}, {x: 10.5, y: 8, r: 0.9},
                                    {x: 8, y: 2.5, r: 0.8}, {x: 8, y: 13.5, r: 0.8},
                                    {x: 2.5, y: 8, r: 0.8}, {x: 13.5, y: 8, r: 0.8}
                                ]
                                Rectangle {
                                    x: modelData.x - modelData.r
                                    y: modelData.y - modelData.r
                                    width: modelData.r * 2
                                    height: modelData.r * 2
                                    radius: modelData.r
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        // Track
                        Rectangle {
                            width: parent.width - 16 - 40 - 20
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.16)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(6, parent.width * root.brightnessLevel)
                                radius: 3
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    var pct = Math.max(1, Math.min(100, Math.round((mouse.x / width) * 100)));
                                    root.brightnessLevel = pct / 100.0;
                                    Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", pct + "%"]);
                                }
                            }
                        }

                        Text {
                            width: 40
                            text: root.brightnessPercent + "%"
                            font.pixelSize: 11
                            font.family: fontNdot57.name || "Fira Sans"
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // 3. MULTI-PLAYER SWITCHER TABS (Spotify vs YouTube / Brave)
            Row {
                width: parent.width
                spacing: 8
                visible: root.playerList.length > 1

                Repeater {
                    model: root.playerList

                    Rectangle {
                        height: 26
                        width: Math.min(160, playerTabLabel.width + 24)
                        radius: 13
                        color: (root.selectedPlayerIdx === index)
                            ? Qt.rgba(1.0, 1.0, 1.0, 0.20)
                            : Qt.rgba(1.0, 1.0, 1.0, 0.06)
                        border.width: 1
                        border.color: (root.selectedPlayerIdx === index)
                            ? Qt.rgba(1.0, 1.0, 1.0, 0.36)
                            : Qt.rgba(1.0, 1.0, 1.0, 0.10)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: (modelData.playbackState === MprisPlaybackState.Playing)
                                    ? "#FF3B30"
                                    : Qt.rgba(1, 1, 1, 0.40)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: playerTabLabel
                                text: root.formatPlayerName(modelData.identity, modelData.desktopEntry)
                                font.pixelSize: 9
                                font.letterSpacing: 0.8
                                font.bold: root.selectedPlayerIdx === index
                                color: (root.selectedPlayerIdx === index) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                                font.family: fontNMono.name || "Fira Sans"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedPlayerIdx = index;
                            }
                        }
                    }
                }
            }

            // 4. MAIN MUSIC / VIDEO PLAYER CARD (Album Art, Title, Artist, Lyrics, Controls, + Button)
            Rectangle {
                width: parent.width
                height: 220
                radius: 18
                color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

                // Top Area: Album Art / Video Thumbnail (Left) + Title/Artist/Lyrics (Right)
                Row {
                    id: playerTopRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 14

                    // Album / Video Thumbnail
                    Rectangle {
                        width: 82
                        height: 82
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.4)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: (root.activePlayer && root.activePlayer.trackArtUrl)
                                ? root.activePlayer.trackArtUrl
                                : Qt.resolvedUrl("../assets/album.jpg")
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }
                    }

                    // Track / Video Metadata & Lyrics
                    Column {
                        width: parent.width - 82 - 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Player Source Badge
                        Text {
                            text: root.activePlayer ? root.formatPlayerName(root.activePlayer.identity, root.activePlayer.desktopEntry) : "MEDIA"
                            font.pixelSize: 8
                            font.letterSpacing: 1.0
                            font.bold: true
                            color: "#FF3B30"
                            font.family: fontNMono.name || "Fira Sans"
                        }

                        // Title
                        Text {
                            width: parent.width
                            text: (root.activePlayer && root.activePlayer.trackTitle)
                                ? root.activePlayer.trackTitle
                                : "No Media Playing"
                            font.pixelSize: 15
                            font.bold: true
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            font.family: fontNType.name || "Fira Sans"
                        }

                        // Artist / Channel
                        Text {
                            width: parent.width
                            text: {
                                var artist = "";
                                if (root.activePlayer) {
                                    if (root.activePlayer.trackArtist) artist = root.activePlayer.trackArtist;
                                    else if (root.activePlayer.trackArtists && root.activePlayer.trackArtists.length > 0)
                                        artist = root.activePlayer.trackArtists[0];
                                    else if (root.activePlayer.identity) artist = root.activePlayer.identity;
                                }
                                return (artist ? artist : "—").toUpperCase();
                            }
                            font.pixelSize: 10
                            font.letterSpacing: 0.8
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                            elide: Text.ElideRight
                            font.family: fontNMono.name || "Fira Sans"
                        }

                        // Synced Lyric Snippet (for Spotify/music tracks)
                        Text {
                            width: parent.width
                            text: (root.stats && root.stats.lyrics && root.stats.lyrics.length > 0)
                                ? root.stats.lyrics[0].text
                                : ""
                            font.pixelSize: 11
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                            font.italic: true
                            elide: Text.ElideRight
                            font.family: fontNType.name || "Fira Sans"
                            visible: text !== "" && root.formatPlayerName(root.activePlayer ? root.activePlayer.identity : "", "").indexOf("SPOTIFY") !== -1
                        }
                    }
                }

                // Progress Timeline
                Item {
                    id: scrubberRow
                    anchors.top: playerTopRow.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: root.stats.position_str || "0:00"
                        font.pixelSize: 9
                        font.family: fontNMono.name || "Fira Sans"
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.60)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        text: root.stats.duration_str || "--:--"
                        font.pixelSize: 9
                        font.family: fontNMono.name || "Fira Sans"
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.60)
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 13
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 1.5
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.16)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(3, parent.width * (root.stats.track_progress || 0.0))
                            radius: 1.5
                            color: "#FFFFFF"
                        }
                    }
                }

                // Media Controls & Add to Playlist (+) Button
                Row {
                    anchors.top: scrubberRow.bottom
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    // TOMBOL '+' (Save to My Playlist)
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.isCurrentTrackSaved
                            ? Qt.rgba(1.0, 0.23, 0.19, 0.25)
                            : (addBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                        border.width: 1
                        border.color: root.isCurrentTrackSaved
                            ? "#FF3B30"
                            : Qt.rgba(1, 1, 1, 0.24)
                        scale: addBtnArea.pressed ? 0.90 : 1.0

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: root.isCurrentTrackSaved
                                ? Qt.resolvedUrl("../assets/check-dot.svg")
                                : Qt.resolvedUrl("../assets/plus-dot.svg")
                            sourceSize: Qt.size(18, 18)
                        }

                        MouseArea {
                            id: addBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleSaveCurrentTrack()
                        }
                    }

                    // Previous Button (Direct to active player!)
                    Item {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: Qt.resolvedUrl("../assets/media-prev-dot.svg")
                            sourceSize: Qt.size(40, 40)
                            opacity: prevBtnArea.containsMouse ? 1.0 : 0.85
                            scale: prevBtnArea.pressed ? 0.90 : 1.0
                        }

                        MouseArea {
                            id: prevBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoPrevious) {
                                    root.activePlayer.previous();
                                } else {
                                    Quickshell.execDetached(["playerctl", "previous"]);
                                }
                            }
                        }
                    }

                    // Play / Pause Capsule (Controls selected player: Spotify OR YouTube!)
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: playBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.32)
                        scale: playBtnArea.pressed ? 0.92 : 1.0

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                                ? Qt.resolvedUrl("../assets/media-pause-dot.svg")
                                : Qt.resolvedUrl("../assets/media-play-dot.svg")
                            sourceSize: Qt.size(44, 44)
                        }

                        MouseArea {
                            id: playBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canControl) {
                                    root.activePlayer.playPause();
                                } else {
                                    Quickshell.execDetached(["playerctl", "play-pause"]);
                                }
                            }
                        }
                    }

                    // Next Button (Direct to active player!)
                    Item {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: Qt.resolvedUrl("../assets/media-next-dot.svg")
                            sourceSize: Qt.size(40, 40)
                            opacity: nextBtnArea.containsMouse ? 1.0 : 0.85
                            scale: nextBtnArea.pressed ? 0.90 : 1.0
                        }

                        MouseArea {
                            id: nextBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoNext) {
                                    root.activePlayer.next();
                                } else {
                                    Quickshell.execDetached(["playerctl", "next"]);
                                }
                            }
                        }
                    }
                }
            }

            // 5. "MY PLAYLIST" SAVED SONGS SECTION (Persistent List)
            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "MY PLAYLIST"
                        font.pixelSize: 11
                        font.letterSpacing: 1.2
                        font.bold: true
                        color: "#FFFFFF"
                        font.family: fontNMono.name || "Fira Sans"
                    }

                    Text {
                        text: "(" + root.playlistItems.length + ")"
                        font.pixelSize: 10
                        font.family: fontNdot55.name || "Fira Sans"
                        color: Qt.rgba(1, 1, 1, 0.50)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SAVED SONGS"
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: fontNMono.name || "Fira Sans"
                }
            }

            // Scrollable Saved Tracks List
            Rectangle {
                width: parent.width
                height: 230
                radius: 18
                color: Qt.rgba(1.0, 1.0, 1.0, 0.04)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                clip: true

                // Empty State Placeholder
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: root.playlistItems.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "NO SAVED TRACKS YET"
                        font.pixelSize: 11
                        font.letterSpacing: 1.0
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font.family: fontNMono.name || "Fira Sans"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Click the '+' button above to save songs"
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.family: fontNType.name || "Fira Sans"
                    }
                }

                // ListView for Saved Items
                ListView {
                    id: playlistListView
                    anchors.fill: parent
                    anchors.margins: 8
                    model: root.playlistItems
                    spacing: 6
                    clip: true
                    visible: root.playlistItems.length > 0

                    delegate: Rectangle {
                        width: playlistListView.width
                        height: 48
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Number / Dot
                            Text {
                                text: (index + 1) < 10 ? ("0" + (index + 1)) : (index + 1)
                                font.pixelSize: 10
                                font.family: fontNMono.name || "Fira Sans"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                            }

                            // Track Info
                            Column {
                                width: parent.width - 18 - 26 - 26 - 24
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modelData.title || ""
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    font.family: fontNType.name || "Fira Sans"
                                }

                                Text {
                                    width: parent.width
                                    text: (modelData.artist || "").toUpperCase()
                                    font.pixelSize: 9
                                    font.letterSpacing: 0.5
                                    color: Qt.rgba(1, 1, 1, 0.60)
                                    elide: Text.ElideRight
                                    font.family: fontNMono.name || "Fira Sans"
                                }
                            }

                            // Play / Open in Spotify
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                color: playItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.20)

                                Image {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    source: Qt.resolvedUrl("../assets/media-play-dot.svg")
                                    sourceSize: Qt.size(26, 26)
                                }

                                MouseArea {
                                    id: playItemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var target = modelData.spotify_uri || modelData.url || "";
                                        root.playPlaylistTrack(target);
                                    }
                                }
                            }

                            // Remove Button (✕) — Fixed & fully clickable!
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                color: delItemArea.containsMouse ? Qt.rgba(1, 0.23, 0.19, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: delItemArea.containsMouse ? "#FF3B30" : Qt.rgba(1, 1, 1, 0.14)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: delItemArea.containsMouse ? "#FF453A" : Qt.rgba(1, 1, 1, 0.65)
                                }

                                MouseArea {
                                    id: delItemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.removePlaylistTrack(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Keyboard Hint Footer
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PRESS CTRL + SUPER + S OR ESC TO CLOSE"
                font.pixelSize: 9
                font.letterSpacing: 1.0
                color: Qt.rgba(1.0, 1.0, 1.0, 0.30)
                font.family: fontNMono.name || "Fira Sans"
            }
        }

        // =====================================================================
        // Toast Notification Pill ("✓ Added to My Playlist")
        // =====================================================================
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            width: toastText.width + 28
            height: 32
            radius: 16
            color: "#18181A"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.28)
            visible: root.toastMessage !== ""
            opacity: root.toastMessage !== "" ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: root.toastMessage
                font.pixelSize: 11
                font.bold: true
                color: "#FFFFFF"
                font.family: fontNMono.name || "Fira Sans"
            }
        }
    }
}
