protocol CVRepository {
    func getCVData() -> CVData
    func saveCVData(_ cv: CVData)
    func getGeneratedCVs() -> [GeneratedCV]
    func saveGeneratedCV(_ cv: GeneratedCV)
    func deleteGeneratedCV(id: String)
}
