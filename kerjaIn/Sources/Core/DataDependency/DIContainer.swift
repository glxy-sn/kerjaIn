import SwiftUI

final class DIContainer {
    private let localDataSource = LocalDataSource()

    private lazy var _homeViewModel = HomeViewModel(
        profileRepository: ProfileRepositoryImpl(dataSource: localDataSource),
        historyRepository: HistoryRepositoryImpl(dataSource: localDataSource)
    )
    private lazy var _cvViewModel = CVGeneratorViewModel(
        cvRepository: CVRepositoryImpl(dataSource: localDataSource),
        profileRepository: ProfileRepositoryImpl(dataSource: localDataSource)
    )
    private lazy var _historyViewModel = HistoryViewModel(
        repository: HistoryRepositoryImpl(dataSource: localDataSource)
    )
    private lazy var _profileViewModel = ProfileViewModel(
        profileRepository: ProfileRepositoryImpl(dataSource: localDataSource),
        cvRepository: CVRepositoryImpl(dataSource: localDataSource)
    )

    func makeHomeView() -> HomeView { HomeView(viewModel: _homeViewModel) }
    func makeCVGeneratorView() -> CVGeneratorView { CVGeneratorView(viewModel: _cvViewModel) }
    func makeHistoryView() -> HistoryView { HistoryView(viewModel: _historyViewModel) }
    func makeProfileView() -> ProfileView { ProfileView(viewModel: _profileViewModel) }
}
