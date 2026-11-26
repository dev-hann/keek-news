package gyo.plugins.http

import android.util.Base64
import android.util.Log
import gyo.plugins.bridge.BridgeHandler
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Generic HTTP relay for the web layer: performs a GET with caller-supplied
 * headers and returns the raw body as base64, so the web side owns charset
 * decoding and parsing. Redirects are not followed so the caller sees them.
 *
 * method "request": data { url: String, headers?: Map<String, String> }
 * returns { status, contentType, bodyBase64, elapsedMs }
 */
class HttpBridge : BridgeHandler {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .followRedirects(false)
        .followSslRedirects(false)
        .build()

    override fun handle(method: String, data: JSONObject): Any? {
        if (method != "request") {
            throw IllegalArgumentException("Unknown method: $method")
        }
        val url = data.getString("url")
        val builder = Request.Builder().url(url).get()
        data.optJSONObject("headers")?.let { headers ->
            headers.keys().forEach { name -> builder.header(name, headers.getString(name)) }
        }

        val started = System.nanoTime()
        client.newCall(builder.build()).execute().use { response ->
            val bytes = response.body?.bytes() ?: ByteArray(0)
            val elapsedMs = (System.nanoTime() - started) / 1_000_000
            Log.d("HttpBridge", "$url -> ${response.code}, ${bytes.size} bytes in $elapsedMs ms")
            return JSONObject()
                .put("status", response.code)
                .put("contentType", response.header("Content-Type"))
                .put("bodyBase64", Base64.encodeToString(bytes, Base64.NO_WRAP))
                .put("elapsedMs", elapsedMs)
        }
    }
}
