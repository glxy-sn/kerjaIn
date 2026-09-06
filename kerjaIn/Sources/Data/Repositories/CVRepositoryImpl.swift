struct CVRepositoryImpl: CVRepository {
    let dataSource: LocalDataSource

    func getCVData() -> CVData { dataSource.loadCVData() }
    func saveCVData(_ cv: CVData) { dataSource.saveCVData(cv) }
}
