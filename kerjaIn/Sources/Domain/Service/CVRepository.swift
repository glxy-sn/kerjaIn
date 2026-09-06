protocol CVRepository {
    func getCVData() -> CVData
    func saveCVData(_ cv: CVData)
}
