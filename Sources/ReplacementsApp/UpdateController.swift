import AppKit
import Combine
import Observation
import Sparkle

@MainActor @Observable final class UpdateController: NSObject, SPUUpdaterDelegate {
    private(set) var canCheck = false
    private(set) var automaticChecks = false
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations = Set<AnyCancellable>()
    @ObservationIgnored private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        super.init()
        // Demo and command-line builds never poll or install updates.
        guard !CommandLine.arguments.contains("--demo"), Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheck = $0 }.store(in: &observations)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.automaticChecks = $0 }.store(in: &observations)
        controller.startUpdater()
    }

    var available: Bool { controller != nil }
    var ready: Bool { canCheck && model?.updateMustWait == false }
    func check() { if ready { controller?.checkForUpdates(nil) } }
    func setAutomaticChecks(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard model?.updateMustWait == true else { return }
        throw NSError(domain: "Replacements.Updates", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Finish or cancel your changes before checking for updates."])
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock install: @escaping () -> Void) -> Bool {
        deferInstallationIfNeeded(install)
    }

    func deferInstallationIfNeeded(_ install: @escaping () -> Void) -> Bool {
        guard model?.updateMustWait == true else { return false }
        Task { @MainActor [weak self] in
            while self?.model?.updateMustWait == true { try? await Task.sleep(for: .milliseconds(250)) }
            install()
        }
        return true
    }
}
