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
            // Launch with the "heavy" preset configuration.
            let config = FocusStressConfiguration.from(preset: .heavyReproduction)
            let vc = FocusStressViewController(configuration: config)
            navigationController?.pushViewController(vc, animated: true)
        case .focusStressLight:
            // Launch with the "light" preset configuration.
            let config = FocusStressConfiguration.from(preset: .lightExploration)
            let vc = FocusStressViewController(configuration: config)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
} 