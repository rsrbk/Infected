//
//  NumbersProvider.swift
//  Infected
//
//  Created by marko on 10/25/20.
//

import Foundation
import Combine
import WidgetKit

final class NumbersProvider: ObservableObject {

    private var cancellables = Set<AnyCancellable>()

    @Published var nationalSummary: Summary?
    @Published var provincialSummaries: GroupedSummaries?
    @Published var securityRegionsSummaries: GroupedSummaries?
    @Published var municipalSummaries: GroupedSummaries?

    let infectedAPI: InfectedAPI
    let widgetCenter: WidgetCenter

    init(infectedAPI: InfectedAPI = InfectedAPI(),
         widgetCenter: WidgetCenter = .shared) {
        self.infectedAPI = infectedAPI
        self.widgetCenter = widgetCenter
    }

    func reloadAllRegions() {
        reloadNational()
        reloadProvincial()
        reloadSecurityRegions()
        reloadMunicipal()
    }

    func reloadNational() {
        infectedAPI.national()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] summary in
                self?.nationalSummary = summary
            })
            .store(in: &cancellables)
    }

    func reloadProvincial() {
        infectedAPI.provincialGroupedSummaries()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] groupedSummaries in
                self?.provincialSummaries = groupedSummaries
            })
            .store(in: &cancellables)
    }

    func reloadSecurityRegions() {
        infectedAPI.securityRegionsGroupedSummaries()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] groupedSummaries in
                self?.securityRegionsSummaries = groupedSummaries
            })
            .store(in: &cancellables)
    }

    func reloadMunicipal() {
        infectedAPI.municipalGroupedSummaries()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] groupedSummaries in
                self?.municipalSummaries = groupedSummaries
            })
            .store(in: &cancellables)
    }

}

private extension NumbersProvider {

    func mergeLatestAndPreviousProvincialDTOs(latest: [NumbersDTO], previous: [NumbersDTO]) -> [ProvinceNumbers] {
        var provincialNumbers = [ProvinceNumbers]()

        for provinceCode in Province.allProvinceCodes {
            guard
                let latestNumbers = latest.provinceNumbers(forProvinceCode: provinceCode),
                let previousNumbers = previous.provinceNumbers(forProvinceCode: provinceCode)
            else {
                continue
            }

            let numbers = ProvinceNumbers(
                provinceCode: provinceCode,
                provinceName: latestNumbers.provinceName,
                latest: latestNumbers.daily,
                previous: previousNumbers.daily,
                total: latestNumbers.total
            )

            provincialNumbers.append(numbers)
        }

        return provincialNumbers
    }

    func mergeLatestAndPreviousMunicipalDTOs(latest: [NumbersDTO], previous: [NumbersDTO]) -> [MunicipalityNumbers] {
        var municipalNumbers = [MunicipalityNumbers]()

        for municipalityCode in Municipality.allMunicipalityCodes {
            guard
                let latestNumbers = latest.municipalityNumbers(forMunicipalityCode: municipalityCode),
                let previousNumbers = previous.municipalityNumbers(forMunicipalityCode: municipalityCode)
            else {
                continue
            }

            let numbers = MunicipalityNumbers(
                municipalityCode: municipalityCode,
                municipalityName: latestNumbers.municipalityName,
                provinceCode: -999, // not important at the moment
                provinceName: latestNumbers.provinceName,
                latest: latestNumbers.daily,
                previous: previousNumbers.daily,
                total: latestNumbers.total
            )

            municipalNumbers.append(numbers)
        }

        return municipalNumbers
    }

}

private extension Publisher where Output == [NumbersDTO] {

    func mappedToPreviousDayDate() -> AnyPublisher<Date, Self.Failure> {
        map(\.[0].date)
            .map { Calendar.current.date(byAdding: .day, value: -1, to: $0)! }
            .eraseToAnyPublisher()
    }

}

private extension Array where Element == NumbersDTO {

    func nationalDailyNumbers() -> Numbers {
        Numbers(
            date: self[0].date,
            cases: first(where: { $0.category == .cases })?.count,
            hospitalizations: first(where: { $0.category == .hospitalizations })?.count,
            deaths: first(where: { $0.category == .deaths })?.count
        )
    }

    func nationalTotalNumbers() -> Numbers {
        Numbers(
            date: self[0].date,
            cases: first(where: { $0.category == .cases })?.totalCount,
            hospitalizations: first(where: { $0.category == .hospitalizations })?.totalCount,
            deaths: first(where: { $0.category == .deaths })?.totalCount
        )
    }

    func provinceNumbers(forProvinceCode code: Int) -> (provinceName: String?, daily: Numbers, total: Numbers)? {
        let entries = filter { $0.provinceCode == code }
        guard entries.isEmpty == false else {
            return nil
        }

        let provinceName = entries.first?.provinceName

        let daily = Numbers(
            date: entries[0].date,
            cases: entries.first(where: { $0.category == .cases })?.count,
            hospitalizations: entries.first(where: { $0.category == .hospitalizations })?.count,
            deaths: entries.first(where: { $0.category == .deaths })?.count
        )

        let total = Numbers(
            date: entries[0].date,
            cases: entries.first(where: { $0.category == .cases })?.totalCount,
            hospitalizations: entries.first(where: { $0.category == .hospitalizations })?.totalCount,
            deaths: entries.first(where: { $0.category == .deaths })?.totalCount
        )

        return (provinceName, daily, total)
    }

    func municipalityNumbers(forMunicipalityCode code: Int) -> (municipalityName: String?, provinceName: String?, daily: Numbers, total: Numbers)? {
        let entries = filter { $0.municipalityCode == code }
        guard entries.isEmpty == false else {
            return nil
        }

        let municipalityName = entries.first?.municipalityName
        let provinceName = entries.first?.provinceName

        let daily = Numbers(
            date: entries[0].date,
            cases: entries.first(where: { $0.category == .cases })?.count,
            hospitalizations: entries.first(where: { $0.category == .hospitalizations })?.count,
            deaths: entries.first(where: { $0.category == .deaths })?.count
        )

        let total = Numbers(
            date: entries[0].date,
            cases: entries.first(where: { $0.category == .cases })?.totalCount,
            hospitalizations: entries.first(where: { $0.category == .hospitalizations })?.totalCount,
            deaths: entries.first(where: { $0.category == .deaths })?.totalCount
        )

        return (municipalityName, provinceName, daily, total)
    }

}
