struct ProfileRepositoryImpl: ProfileRepository {
    let dataSource: LocalDataSource

    func getProfile() -> UserProfile { dataSource.loadProfile() }
    func saveProfile(_ profile: UserProfile) { dataSource.saveProfile(profile) }
}
