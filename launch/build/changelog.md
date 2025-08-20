
This patch release contains the following bug fixes:

### Runtime

| Type | Issue | Change |
|-|-|-|
| | | |
| *Bug Fixes* | [4881](https://github.com/openhab/openhab-core/pull/4881) | Fix persistence threshold filter with UoM |
|  | [4896](https://github.com/openhab/openhab-core/pull/4896) | Fix NPE in FolderObserver |
|  | [4917](https://github.com/openhab/openhab-core/pull/4917) | Map chart interpolation parameter into sitemap JSON response |
|  | [4922](https://github.com/openhab/openhab-core/pull/4922) | AbstractScriptModuleHandler: Recompile scripts on dependency change |

### Add-ons

| Add-on | Type | Issue | Change |
|-|-|-|-|
| | | | |
| **amazoneechocontrol** | *Bug Fixes* | [19182](https://github.com/openhab/openhab-addons/pull/19182) | Adapt to changed API |
| | | | |
| **amberelectric** | *Bug Fixes* | [19139](https://github.com/openhab/openhab-addons/pull/19139) | Fix Controlled Load Price |
| | | | |
| **anthem** | *Bug Fixes* | [19082](https://github.com/openhab/openhab-addons/pull/19082) | Fix duplicate channel |
| | | | |
| **avmfritz** | *Bug Fixes* | [19118](https://github.com/openhab/openhab-addons/pull/19118) | Fix boost and window open modes |
| | | | |
| **bluetooth.bluez** | *Bug Fixes* | [19071](https://github.com/openhab/openhab-addons/pull/19071) | Fix missing data in bindings due to event routing issue |
| | | | |
| **denonmarantz** | *Bug Fixes* | [19022](https://github.com/openhab/openhab-addons/pull/19022) | Fix zone 3 input source update |
| | | | |
| **ecotouch** | *Bug Fixes* | [18870](https://github.com/openhab/openhab-addons/pull/18870) | Fix upgrade instructions |
| | | | |
| **electroluxappliance** | *Bug Fixes* | [19021](https://github.com/openhab/openhab-addons/pull/19021) | Improve JWT handling |
| | | | |
| **exec** | *Bug Fixes* | [19152](https://github.com/openhab/openhab-addons/pull/19152) | Prevent deadlock |
| | | | |
| **fronius** | *Bug Fixes* | [18872](https://github.com/openhab/openhab-addons/pull/18872) | Fix battery control not working for firmware >= 1.36.x |
|  |  | [18907](https://github.com/openhab/openhab-addons/pull/18907) | Fix unhandled exception on jsonParse for inverters that don't support version info api |
| | | | |
| **homematic** | *Bug Fixes* | [18886](https://github.com/openhab/openhab-addons/pull/18886) | Improve error message when command sending fails |
|  |  | [19141](https://github.com/openhab/openhab-addons/pull/19141) | Fix premature end of discovery |
| | | | |
| **insteon** | *Bug Fixes* | [18894](https://github.com/openhab/openhab-addons/pull/18894) | Fix thermostat system mode status mapping |
| | | | |
| **jsscripting** | *Bug Fixes* | [19195](https://github.com/openhab/openhab-addons/pull/19195) | Upgrade openhab-js to 5.11.3 |
| | | | |
| **linky** | *Bug Fixes* | [19142](https://github.com/openhab/openhab-addons/pull/19142) | Fix userInfo url changes |
| | | | |
| **lutron** | *Bug Fixes* | [18975](https://github.com/openhab/openhab-addons/pull/18975) | Fix comparison bug |
| | | | |
| **matter** | *Bug Fixes* | [19112](https://github.com/openhab/openhab-addons/pull/19112) | General Updates |
| | | | |
| **mercedesme** | *Enhancements* | [18984](https://github.com/openhab/openhab-addons/pull/18984) | internal websocket rework |
|  | *Bug Fixes* | [19099](https://github.com/openhab/openhab-addons/pull/19099) | Improve HTTP 429 handling and implement new authorization flow |
| | | | |
| **misc** | *Bug Fixes* | [19133](https://github.com/openhab/openhab-addons/pull/19133) | Make dedicated thread pools for Exec and Chromecast bindings |
| | | | |
| **orbitbhyve** | *Bug Fixes* | [19056](https://github.com/openhab/openhab-addons/pull/19056) | Fix inability to set rain delay |
| | | | |
| **ring** | *Bug Fixes* | [19102](https://github.com/openhab/openhab-addons/pull/19102) | Fix for passwords with special characters |
| | | | |
| **rotel** | *Bug Fixes* | [18966](https://github.com/openhab/openhab-addons/pull/18966) | Fix search of key for ASCII mode |
| | | | |
| **sonos** | *Enhancements* | [19103](https://github.com/openhab/openhab-addons/pull/19103) | Ignore Sonos Boost and any Sub including Sonos Sub 4 |
|  |  | [19162](https://github.com/openhab/openhab-addons/pull/19162) | Add support for Sonos Arc Ultra |
|  |  | [19168](https://github.com/openhab/openhab-addons/pull/19168) | Enhance logging for playback of notifications |
| | | | |
| **surepetcare** | *Bug Fixes* | [19106](https://github.com/openhab/openhab-addons/pull/19106) | Fix hubRssi `NullPointerException` |
| | | | |
| **tibber** | *Bug Fixes* | [19111](https://github.com/openhab/openhab-addons/pull/19111) | Add support for average channel |
| | | | |
| **tr064** | *Bug Fixes* | [18976](https://github.com/openhab/openhab-addons/pull/18976) | Fix channel type |
| | | | |
| **zwavejs** | *Bug Fixes* | [19003](https://github.com/openhab/openhab-addons/pull/19003) | Fix humidity unit detection |
|  |  | [19036](https://github.com/openhab/openhab-addons/pull/19036) | Fix Channel configuration overwrite |

### User Interfaces

| UI | Type | Issue | Change |
|-|-|-|-|
| | | | |
| **Basic UI** | *Bug Fixes* | [3331](https://github.com/openhab/openhab-webui/pull/3331) | Recalculate widths for multiline buttons in dynamic Frames |
| | | | |
| **Main UI** | *Bug Fixes* | [3254](https://github.com/openhab/openhab-webui/pull/3254) | Use versioned branch for add-on & sidebar docs |
|  |  | [3256](https://github.com/openhab/openhab-webui/pull/3256) | oh-slider-item: Respect `ignoreDisplayState` config & Improve docs |
|  |  | [3257](https://github.com/openhab/openhab-webui/pull/3257) | oh-slider: Fix display state with decimal comma parsed to integer |
|  |  | [3266](https://github.com/openhab/openhab-webui/pull/3266) | Config description: Fix external links not opening correctly |
|  |  | [3298](https://github.com/openhab/openhab-webui/pull/3298) | Sitemap edit: Fix quotes for icon value not allowed |
|  |  | [3299](https://github.com/openhab/openhab-webui/pull/3299) | Sitemap edit: Fix validation errors for valid buttongrid |
|  |  | [3300](https://github.com/openhab/openhab-webui/pull/3300) | Sitemap edit: Fix save button not working due to JSON error |
|  |  | [3306](https://github.com/openhab/openhab-webui/pull/3306) | Sitemap parser: Further fixes for icon rules |
|  |  | [3307](https://github.com/openhab/openhab-webui/pull/3307) | Semantic tags page: Fix page refresh & delete synonym bugs  |
|  |  | [3311](https://github.com/openhab/openhab-webui/pull/3311) | Addon Config: Fix dirty checking |
|  |  | [3313](https://github.com/openhab/openhab-webui/pull/3313) | Developer Sidebar: Add rule.trigger.configuration.groupName to the search |
|  |  | [3320](https://github.com/openhab/openhab-webui/pull/3320) | Sitemap editor: fix missing row parameter |
|  |  | [3321](https://github.com/openhab/openhab-webui/pull/3321) | Fix ECharts animation regression |
