package com.example.tiny_mines

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val players = mutableSetOf<MediaPlayer>()
    private var musicPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tiny_mines/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.7f
                    if (asset != null) playSound(asset, volume)
                    result.success(null)
                }
                "startLoop" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.4f
                    if (asset != null) startLoop(asset, volume)
                    result.success(null)
                }
                "stopLoop" -> {
                    stopLoop()
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun playSound(asset: String, volume: Float) {
        // Bound the number of overlapping effects.
        if (players.size >= MAX_PLAYERS) return
        runCatching {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val descriptor = assets.openFd(key)
            val player = MediaPlayer()
            try {
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .build(),
                )
                player.setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
                player.prepare()
                player.setVolume(volume, volume)
                player.setOnCompletionListener {
                    players.remove(it)
                    it.release()
                }
                players.add(player)
                player.start()
            } catch (error: Throwable) {
                players.remove(player)
                player.release()
                throw error
            } finally {
                descriptor.close()
            }
        }
    }

    // Releases the player if any step fails, so a broken asset never leaks a
    // MediaPlayer or a file handle.
    private fun openPlayer(asset: String, contentType: Int): MediaPlayer {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(contentType)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build(),
            )
            assets.openFd(key).use { descriptor ->
                player.setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
            }
            player.prepare()
            return player
        } catch (error: Exception) {
            player.release()
            throw error
        }
    }

    private fun startLoop(asset: String, volume: Float) {
        stopLoop()
        runCatching {
            val player = openPlayer(asset, AudioAttributes.CONTENT_TYPE_MUSIC)
            player.isLooping = true
            player.setVolume(volume, volume)
            musicPlayer = player
            player.start()
        }.onFailure {
            musicPlayer = null
        }
    }

    private fun stopLoop() {
        runCatching { musicPlayer?.stop() }
        musicPlayer?.release()
        musicPlayer = null
    }

    private fun disposeAudio() {
        stopLoop()
        players.toList().forEach { it.release() }
        players.clear()
    }

    private companion object {
        const val MAX_PLAYERS = 8
    }
}
