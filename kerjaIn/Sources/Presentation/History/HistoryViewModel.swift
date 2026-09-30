import Foundation
import Observation

@Observable
final class HistoryViewModel {
    var generatedCVs: [GeneratedCV] = []

    private let cvRepository: any CVRepository

    init(cvRepository: any CVRepository) {
        self.cvRepository = cvRepository
    }

    func load() {
        generatedCVs = cvRepository.getGeneratedCVs()
    }

    func delete(id: String) {
        cvRepository.deleteGeneratedCV(id: id)
        generatedCVs.removeAll { $0.id == id }
    }
}
