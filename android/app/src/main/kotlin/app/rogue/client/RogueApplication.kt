package app.rogue.client

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Keeps one Flutter engine (and therefore one Dart isolate) for the process.
 *
 * Rogue owns a single media_kit/libmpv player for the app lifetime. When the
 * Activity is destroyed and Flutter destroys its engine, the Dart isolate goes
 * away but libmpv's native threads keep the wake-up callback that points into
 * the freed isolate. The next mpv event then crashes in freed Dart memory
 * (`SIGSEGV` in libmpv.so / anon:dart-zone).
 *
 * Caching the engine means closing Rogue only detaches the view; the isolate,
 * player and callback stay valid while the process lives. The activity is
 * configured with `shouldDestroyEngineWithHost() = false`.
 */
class RogueApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "rogue-engine"
    }
}
