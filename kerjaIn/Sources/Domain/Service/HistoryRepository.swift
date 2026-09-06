protocol HistoryRepository {
    func getAll() -> [JobHistory]
    func add(_ entry: JobHistory)
    func update(_ entry: JobHistory)
    func delete(id: String)
}
