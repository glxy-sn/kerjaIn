struct CVRepositoryImpl: CVRepository {
    let dataSource: LocalDataSource

    func getCVData() -> CVData { dataSource.loadCVData() }
    func saveCVData(_ cv: CVData) { dataSource.saveCVData(cv) }
    func getGeneratedCVs() -> [GeneratedCV] { dataSource.getGeneratedCVs() }
    func saveGeneratedCV(_ cv: GeneratedCV) { dataSource.saveGeneratedCV(cv) }
    func deleteGeneratedCV(id: String) { dataSource.deleteGeneratedCV(id: id) }
}
