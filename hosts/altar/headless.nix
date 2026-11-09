{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrValues
    concatLists
    concatMapStringsSep
    mkAfter
    ;

  # Apple services with nothing to do on a machine that has no Apple ID, no
  # peripherals and nobody sitting at it. Everything the window server, the
  # Dock, Finder, screen capture and accessibility need stays untouched, so
  # agents can still drive the desktop.
  #
  # Labels are given without their `com.apple.` prefix.

  # Agents of the logged-in user.
  agents = {
    siri = [
      "Siri.agent"
      "SiriTTSTrainingAgent"
      "assistant_cdmd"
      "assistant_service"
      "assistantd"
      "parsecd"
      "siriactionsd"
      "siriappintentsd"
      "siriinferenced"
      "siriknowledged"
      "sirittsd"
      "suggestd"
    ];

    intelligence = [
      "GenerativeFunctions.agentstored"
      "ModelCatalogAgent"
      "campo"
      "duetexpertd"
      "generativeexperiencesd"
      "imageplaygroundd"
      "intelligencecontextd"
      "intelligenceflowd"
      "intelligenceplatformd"
      "intelligencetasksd"
      "knowledge-agent"
      "knowledgeconstructiond"
      "visualintelligenced"
    ];

    spotlight = [
      "Spotlight"
      "corespotlightd"
      "corespotlightservice"
      "hybridsearchd"
      "managedcorespotlightd"
      "mdworker.application"
      "mdworker.mail"
      "mdworker.shared"
      "mdworker.single.arm64"
      "mdworker.single.x86_64"
      "mdworker.sizing"
      "metadata.mdbulkimport"
      "metadata.mdflagwriter"
      "metadata.mdwrite"
      "spotlightknowledged"
      "spotlightknowledged.importer"
      "spotlightknowledged.updater"
    ];

    photos = [
      "cloudphotod"
      "mediaanalysisd"
      "mediastream.mstreamd"
      "photoanalysisd"
      "photolibraryd"
    ];

    ads = [
      "ap.adprivacyd"
      "ap.promotedcontentd"
      "tipsd"
    ];

    # AirDrop, Handoff, AirPlay, Sidecar, Universal Control.
    continuity = [
      "AMPDeviceDiscoveryAgent"
      "AirPlayUIAgent"
      "RapportUIAgent"
      "amp.mediasharingd"
      "cmio.ContinuityCaptureAgent"
      "coreservices.useractivityd"
      "ensemble"
      "intelligentroutingd"
      "mediacontinuityd"
      "rapportd"
      "sharingd"
      "sidecar-display-agent"
      "sidecar-relay"
      "tvremoted"
    ];

    findMy = [
      "findmy.findmylocateagent"
      "findmymacmessenger"
      "icloud.findmydeviced.findmydevice-user-agent"
      "icloud.searchpartyuseragent"
    ];

    # iMessage, FaceTime, Contacts, Calendar, Reminders.
    communication = [
      "AddressBook.AssistantService"
      "AddressBook.SourceSync"
      "AddressBook.abd"
      "CallHistoryPluginHelper"
      "CallHistorySyncHelper"
      "CommCenter"
      "StatusKitAgent"
      "avatarsd"
      "calaccessd"
      "callhistoryd"
      "callintelligenced"
      "cmfsyncagent"
      "contacts.donation-agent"
      "contacts.postersyncd"
      "contactsd"
      "dataaccess.dataaccessd"
      "facetimemessagestored"
      "identityservicesd"
      "idsfoundation.IDSRemoteURLConnectionAgent"
      "imagent"
      "remindd"
      "sociallayerd"
      "stickersd"
      "telephonyutilities.callservicesd"
    ];

    # HomeKit, Screen Time, widgets, Weather, News, Game Center, Translate.
    apps = [
      "GameController.gamecontrolleragentd"
      "GamePolicyAgent"
      "ScreenTimeAgent"
      "ScreenTimeSettingsAgent"
      "ThreadCommissionerService"
      "UsageTrackingAgent"
      "chronod"
      "gamed"
      "gamesaved"
      "homed"
      "homeenergyd"
      "homeeventsd"
      "newsd"
      "translationd"
      "weatherd"
    ];

    icloud = [
      "Maps.mapssyncd"
      "SafariBookmarksSyncAgent"
      "bird"
      "cksharingmanagementd"
      "cloudd"
      "cloudsettingssyncagent"
      "familycircled"
      "iCloudNotificationAgent"
      "iCloudUserNotificationsd"
      "icloudmailagent"
      "icloudwebd"
      "itunescloudd"
      "keychainsharingmessagingd"
      "protectedcloudstorage.protectedcloudkeysyncing"
      "security.cloudkeychainproxy3"
      "syncdefaultsd"
    ];

    bluetooth = [
      "BTServer.cloudpairing"
      "BTServer.le.agent"
      "bluetoothuserd"
    ];

    appStore = [
      "SoftwareUpdateNotificationManager"
      "appstoreagent"
      "appstorecomponentsd"
      "commerce"
    ];
  };

  daemons = {
    analytics = [
      "audioanalyticsd"
      "wifianalyticsd"
    ];

    continuity = [
      "nearbyd"
      "rapportd"
    ];

    findMy = [
      "findmy.findmybeaconingd"
      "findmymacd"
      "findmymacmessenger"
      "icloud.findmydeviced"
      "icloud.searchpartyd"
    ];

    apps = [
      "GameController.gamecontrollerd"
      "familycontrols"
      "gamepolicyd"
    ];

    icloud = [
      "cloudd"
    ];
  };

  targets =
    domain: groups:
    attrValues groups |> concatLists |> concatMapStringsSep "\n" (label: "${domain}/com.apple.${label}");

  disableServices = pkgs.writeShellScript "disable-launchd-services" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}:/usr/bin:/bin LC_ALL=C

    uid=$(id -u ${config.system.primaryUser})
    state=/var/db/launchd-disabled-services
    wanted=$(mktemp)
    trap 'rm -f "$wanted"' EXIT

    sort > "$wanted" <<EOF
    ${targets "gui/$uid" agents}
    ${targets "system" daemons}
    EOF

    # A service dropped from the lists goes back to launchd's defaults.
    if [ -e "$state" ]; then
      comm -23 "$state" "$wanted" | while read -r target; do
        launchctl enable "$target"
      done
    fi

    # launchd refuses to stop some protected services while they run; those
    # stay up until the next boot, where the disabled flag keeps them down.
    while read -r target; do
      launchctl disable "$target"
      launchctl bootout "$target" 2>/dev/null || true
    done < "$wanted"

    cp "$wanted" "$state"
  '';
in
{
  system.activationScripts.postActivation.text = mkAfter ''
    echo "disabling launchd services a headless host does not need..." >&2
    ${disableServices} || echo "warning: disabling launchd services failed" >&2
  '';

  # Updates are checked for and the security data ones still install, but
  # macOS and App Store updates are neither downloaded nor installed unasked.
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  system.defaults.CustomSystemPreferences = {
    "/Library/Preferences/com.apple.SoftwareUpdate".AutomaticDownload = false;
    "/Library/Preferences/com.apple.commerce".AutoUpdate = false;
  };
}
