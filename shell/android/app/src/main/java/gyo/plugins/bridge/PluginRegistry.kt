package gyo.plugins.bridge

import android.content.Context
import gyo.plugins.bridge.BridgeRegistry
import gyo.plugins.http.HttpBridge

/**
 * Registers every Gyo plugin the project has installed. gyo run, gyo build
 * and gyo install rewrite it; handlers of your own belong elsewhere.
 */
object PluginRegistry {
    fun registerAll(context: Context) {
        BridgeRegistry.register("http", HttpBridge(context))
    }
}
