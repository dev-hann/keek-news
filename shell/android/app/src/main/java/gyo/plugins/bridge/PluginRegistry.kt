package gyo.plugins.bridge

import android.content.Context
import gyo.plugins.bridge.BridgeRegistry
import gyo.plugins.http.HttpBridge

object PluginRegistry {
    fun registerAll(context: Context) {
        BridgeRegistry.register("http", HttpBridge(context))
    }
}
