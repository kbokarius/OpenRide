package dev.digitalducktape.openride

import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import dev.digitalducktape.openride.games.GameHostActivity
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Lane Smash's launcher. The persistent Godot task owns the entire riding experience. */
class MainActivity : ComponentActivity() {
    private var opening = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
        showStatus("Loading Lane Smash…")
        openLaneSmash()
    }

    private fun openLaneSmash() {
        if (opening) return
        opening = true
        lifecycleScope.launch {
            try {
                // Restore existing history before provisioning a first-install rider.
                appContainer.autoBackupManager.awaitInitialRestore()
                val id = appContainer.profileRepository.ensureLaneSmashProfile(
                    appContainer.activeProfileHolder.activeProfileId.value,
                )
                appContainer.activeProfileHolder.setActiveProfile(id)
                startActivity(GameHostActivity.intent(this@MainActivity))
                finish() // Only this lightweight launcher finishes; never destroy Godot's task.
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                opening = false
                showStatus("Couldn't open your saved rides. Please try again.", retry = true)
            }
        }
    }

    private fun showStatus(message: String, retry: Boolean = false) {
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xff090f18.toInt())
            addView(TextView(this@MainActivity).apply {
                text = "Lane Smash"; textSize = 32f; setTextColor(0xfff0f4ff.toInt())
            })
            addView(TextView(this@MainActivity).apply {
                text = message; textSize = 18f; setTextColor(0xffb8c6e0.toInt())
                setPadding(24, 24, 24, 24)
            })
            if (retry) addView(Button(this@MainActivity).apply {
                text = "Try again"
                setOnClickListener { showStatus("Loading Lane Smash…"); openLaneSmash() }
            })
        })
    }
}
