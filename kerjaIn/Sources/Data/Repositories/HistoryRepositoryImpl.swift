struct HistoryRepositoryImpl: HistoryRepository {
    let dataSource: LocalDataSource

    func getAll() -> [JobHistory] { dataSource.loadHistory() }

    func add(_ entry: JobHistory) {
        var list = dataSource.loadHistory()
        list.append(entry)
        dataSource.saveHistory(list)
    }

    func update(_ entry: JobHistory) {
        var list = dataSource.loadHistory()
        if let index = list.firstIndex(where: { $0.id == entry.id }) {
            list[index] = entry
        }
        dataSource.saveHistory(list)
    }

    func delete(id: String) {
        var list = dataSource.loadHistory()
        list.removeAll { $0.id == id }
        dataSource.saveHistory(list)
    }
}
