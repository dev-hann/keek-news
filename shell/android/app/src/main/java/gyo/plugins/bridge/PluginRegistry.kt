package gyo.plugins.bridge

import android.content.Context
import gyo.plugins.app_launcher.AppLauncherBridge
import gyo.plugins.bridge.BridgeRegistry
import gyo.plugins.device_info.DeviceInfoBridge
import gyo.plugins.http.HttpBridge
import gyo.plugins.media.MediaBridge

/**
 * Registers every Gyo plugin the project has installed. gyo run, gyo build
 * and gyo install rewrite it; handlers of your own belong elsewhere.
 */
object PluginRegistry {
    fun registerAll(context: Context) {
        BridgeRegistry.register("app_launcher", AppLauncherBridge(context))
        BridgeRegistry.register("device_info", DeviceInfoBridge(context))
        BridgeRegistry.register("http", HttpBridge(context))
        BridgeRegistry.register("media", MediaBridge(context))
    }
}
