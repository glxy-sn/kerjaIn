protocol ProfileRepository {
    func getProfile() -> UserProfile
    func saveProfile(_ profile: UserProfile)
}
