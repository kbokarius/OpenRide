package dev.digitalducktape.openride.core.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ProfileRepository(private val profileDao: ProfileDao) {
    private val startupMutex = Mutex()

    /** Reuse the active rider/history; create a local default only on an empty installation. */
    suspend fun ensureLaneSmashProfile(preferredId: Long?): Long = startupMutex.withLock {
        val profiles = observeProfiles().first()
        profiles.firstOrNull { it.id == preferredId }?.id ?: profiles.firstOrNull()?.id
            ?: createProfile(Profile(name = "Rider", avatarEmoji = "", avatarColor = 0xff79b8d5.toInt(), weightKg = null, ftp = null))
    }

    fun observeProfiles(): Flow<List<Profile>> = profileDao.observeAll()

    suspend fun getProfile(id: Long): Profile? = profileDao.getById(id)

    /** Returns the id of the created profile. */
    suspend fun createProfile(profile: Profile): Long = profileDao.insert(profile)

    suspend fun updateProfile(profile: Profile) = profileDao.update(profile)

    suspend fun deleteProfile(profile: Profile) = profileDao.delete(profile)
}
