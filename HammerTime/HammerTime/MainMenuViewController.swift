import UIKit

/// Main entry point allowing users to choose which diagnostic or sample flow to launch.
/// - Note: This view controller is available in all build configurations.
final class MainMenuViewController: UITableViewController {

    private enum Row: Int, CaseIterable {
        case standardFlow
        case focusStressHeavy
        case focusStressLight

        var title: String {
            switch self {
            case .standardFlow:        return "Standard App Flow"
            case .focusStressHeavy:    return "Focus Stress (Heavy)"
            case .focusStressLight:    return "Focus Stress (Light)"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HammerTime Diagnostics"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let row = Row(rawValue: indexPath.row) {
            cell.textLabel?.text = row.title
            cell.accessibilityIdentifier = row.title.replacingOccurrences(of: " ", with: "-")
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = Row(rawValue: indexPath.row) else { return }
        switch row {
        case .standardFlow:
            let vc = ViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .focusStressHeavy:
            launchFocusStress(mode: "heavy")
        case .focusStressLight:
            launchFocusStress(mode: "light")
        }
    }

    private func launchFocusStress(mode: String) {
        // Inject launch argument into ProcessInfo for the duration of this session.
        // Note: We can't mutate ProcessInfo.arguments directly, so we configure the VC manually.
        let vc = FocusStressViewController()
        if mode == "light" {
            // Write to UserDefaults so FocusStressViewController can read.
            UserDefaults.standard.setValue("light", forKey: "FocusStressMode")
        } else {
            UserDefaults.standard.removeObject(forKey: "FocusStressMode")
        }
        navigationController?.pushViewController(vc, animated: true)
    }
} 